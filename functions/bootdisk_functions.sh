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
function resolve_provider() {
  local cr_id=$(hook_data host.compute_resource_id)
  local cr_info
  local query_sql
  local opts_sql
  if [ "$cr_id" == "null" ]; then
    log_info "This is a baremetel host"
    # TODO - Figure out what baremetal hardware is used etc.
    #      - Use ipmitool, requires BMC info to be defined?
    CR_PROVIDER="idrac" # defalt to Dell idrac for now...
  else
    cr_info=$(hammer --output json compute-resource info --id ${cr_id})
    CR_PROVIDER=$(echo ${cr_info} | jgrep -s Provider)
    CR_URL=$(echo ${cr_info} | jgrep -s Url)
    CR_USER=$(echo ${cr_info} | jgrep -s User)
    query_sql="SELECT password FROM compute_resources WHERE id = ${cr_id}"
    opts_sql="-A --tuples-only --dbname=foreman --command="
    CR_PASSWD=$(psql ${opts_sql}"${query_sql}")
  fi
  log_debug "Compute resource provider is: ${CR_PROVIDER}"
}


# Make foreman bootdisk available to the provider.
#   Upload bootdisk to:
#    * RHEV ISO domain
#    * vmware datastore
#    * NFS/CIFS/SCP for others?
#
function enable_provider() {
    case "$CR_PROVIDER" in
      Libvirt)
        # libvirt_enable
        exit 1
      ;;
      Vmware)
        #vmware_iso_datastore $HOOK_EVENT $CR_ID $CR_URL $CR_USER $CR_PASSWD
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      RHEV)
        iso_domain_upload $HOOK_OBJECT
      ;;
      Ovirt)
        #ovirt_iso_domain
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      idrac)
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      *)
        log_err "Unknown compute resource provider $CR_PROVIDER"
        exit 1
      ;;
    esac
}

# Remove foreman bootdisk available from the provider.
#   Delete bootdisk in:
#    * RHEV ISO domain
#    * vmware datastore
#    * NFS/CIFS/SCP for others?
#
function disable_provider() {
      case "$CR_PROVIDER" in
      Libvirt)
        # libvirt_enable
        exit 1
      ;;
      Vmware)
        #vmware_iso_datastore $HOOK_EVENT $CR_ID $CR_URL $CR_USER $CR_PASSWD
        log_err "Compute resorce provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      RHEV)
        iso_domain_delete $HOOK_OBJECT
      ;;
      Ovirt)
        #ovirt_iso_domain
        log_err "Compute resorce provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      idrac)
        log_err "Compute resorce provider $CR_PROVIDER not implemented"
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
function bootdisk_provision() {
    case "$CR_PROVIDER" in
      Libvirt)
        libvirt_provision
      ;;
      Vmware)
        #vmware_provision
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      RHEV)
        rhev_boot_once $HOOK_OBJECT $HOOK_EVENT $CR_URL $CR_USER $CR_PASSWD
      ;;
      Ovirt)
        #ovirt_provision
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
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
function bootdisk_post_provision() {
    case "$CR_PROVIDER" in
      Libvirt)
        libvirt_provision
      ;;
      Vmware)
        #vmware_provision
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
      ;;
      RHEV)
        rhev_post_provision $HOOK_EVENT $CR_URL $CR_USER $CR_PASSWD
      ;;
      Ovirt)
        #ovirt_provision
        log_err "Compute provider $CR_PROVIDER not implemented"
        exit 1
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

