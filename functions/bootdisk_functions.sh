#
# Check if build mode is enabled for the host
#
function is_build_enabled() {
  if [ "$(hook_data host.build)" == "true" ]; then
    return 0
  fi
  return 1
}

#
# Check if DHCP is enabled for subnet
#
function is_dhcp_enabled() {
  local subnet_id=$(hook_data host.subnet_id)
  local cmd_hammer="hammer --output json subnet info --id"
  $cmd_hammer ${subnet_id} | jgrep -s DHCP > /dev/null 2>&1 &&
    { log_debug "Subnet ID: ${subnet_id}, DHCP enabled"; return 0; } ||
    { log_debug "Subnet ID: ${subnet_id}, DHCP disabled"; return 1; }
}

#
# Figure out what is the provider behind the host. 
#   If it is a compute resource, and if not proble the BMC for info.
#
function provider_resolve() {
  CR_ID=$(hook_data host.compute_resource_id)
  local cr_info
  local query_sql
  local opts_sql
  if [ "$CR_ID" == "null" ]; then
    log_info "This is a baremetel host"
    # TODO - Figure out what baremetal hardware is used etc.
    #      - Use ipmitool, requires BMC info to be defined?
    CR_PROVIDER="idrac" # defalt to Dell idrac for now...
  else
    cr_info=$(hammer --output json compute-resource info --id ${CR_ID})
    CR_PROVIDER=$(echo ${cr_info} | jgrep -s Provider)
    CR_URL=$(echo ${cr_info} | jgrep -s Url)
    CR_USER=$(echo ${cr_info} | jgrep -s User)
    query_sql="SELECT password FROM compute_resources WHERE id = ${CR_ID}"
    opts_sql="-A --tuples-only --dbname=foreman --command="
    CR_PASSWD=$(psql ${opts_sql}"${query_sql}")
  fi
  log_debug "Compute resource provider is: ${CR_PROVIDER}"
}


#
#
#
function provider_provision() {
    case "$CR_PROVIDER" in
      Libvirt)
        libvirt_provision
      ;;
      VMWare)
        ${HOOK_DIR}/providers/vmware.rb \
          --event $HOOK_EVENT \
          --crid $CR_ID \
          --crpassword $CR_PASSWD \
          --vmuuid $(hook_data host.uuid) \
          --isopath ${BOOT_DISK_STORE}/${HOOK_OBJECT}.iso \
          --foremanhost $FOREMAN_HOST \
          --foremanuser $FOREMAN_USER \
          --foremanpasswd $FOREMAN_PASSWD \
          && { exit 0; } || { exit 1; }
      ;;
      Ovirt|RHEV)
        iso_domain_upload $HOOK_OBJECT
        ovirt_boot_once $HOOK_OBJECT $HOOK_EVENT $CR_URL $CR_USER $CR_PASSWD
      ;;
      iDRAC)
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      *)
        log_err "Unknown compute resource provider $CR_PROVIDER"
        exit 1
      ;;
    esac
}

#
#
#
function provider_post_provision() {
    case "$CR_PROVIDER" in
      Libvirt)
        libvirt_provision
      ;;
      VMWare)
        ${HOOK_DIR}/providers/vmware.rb \
          --event $HOOK_EVENT \
          --crid $CR_ID \
          --crpassword $CR_PASSWD \
          --vmuuid $(hook_data host.uuid) \
          --isopath ${BOOT_DISK_STORE}/${HOOK_OBJECT}.iso \
          --foremanhost $FOREMAN_HOST \
          --foremanuser $FOREMAN_USER \
          --foremanpasswd $FOREMAN_PASSWD \
          && { exit 0; } || { exit 1; }
      ;;
      Ovirt|RHEV)
        ovirt_post_provision $HOOK_OBJECT $HOOK_EVENT $CR_URL $CR_USER $CR_PASSWD
        iso_domain_delete $HOOK_OBJECT
      ;;
      iDRAC)
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      *)
        log_err "Unknown compute resource provider $CR_PROVIDER"
        exit 1
      ;;
    esac
}

