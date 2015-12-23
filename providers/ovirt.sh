e
# Requires sudorule:
#  foreman ALL=(vdsm) NOPASSWD:/bin/cp
#
#
function iso_domain_upload() {
  local hook_object=$1
  # By setting up sudorules and ssh keys it is also possible to use the rhev-iso-upload tool on
  #  a remote machine.
  #
  # Mount the ISO domain to the satellite to transfer the iso file.
  # Create user vdsm and group kvm
  #  $ groupadd -g 36 kvm
  #  $ useradd --system -u 36 -g 36 --no-create-home --shell /bin/nologin vdsm
  # Add sudorule to allow foreman user to run /bin/cp as vdsm user
  #  $ echo "foreman ALL=(vdsm) NOPASSWD:/bin/cp" >> /etc/sudoers.d/foreman-hooks 
  #
  # Based on this solution article: https://access.redhat.com/solutions/46518
  #
  log_info "Copying ISO to ISO_DOMAIN..."
  local iso_file=${BOOT_DISK_STORE}/${hook_object}.iso
  sudo -u vdsm cp -v ${iso_file} ${RHEV_ISO_DOMAIN_PATH} > /tmp/${hook_object}-iso_upload.log 2>&1 &&
      { log_info "Foreman bootdisk copy to ISO domain done"; } ||
      { log_err "Foreman bootdisk copy to ISO domain failed"; exit 1; }

  #local ssh_opts="-i ${RHEV_ISO_DOMAIN_KEY}"
  #local iso_file="${BOOT_DISK_STORE}/${hook_object}.iso"
  #local iso_domain_uri="${RHEV_ISO_DOMAIN_USER}@${RHEV_ISO_DOMAIN_HOST}:${RHEV_ISO_DOMAIN_TMP_DIR}/"

  #scp ${ssh_opts} ${iso_file} ${iso_domain_uri} &&
  #  { log_info "Foreman bootdisk copy to ISO domain done"; } ||
  #  { log_err "Foreman bootdisk copy to ISO domain failed"; exit 1; }

  #ssh_opts="-t ${ssh_opts} -l ${RHEV_ISO_DOMAIN_USER}"
  #remote_cmd="sudo /usr/bin/rhevm-iso-uploader -i ${RHEV_ISO_DOMAIN_NAME} -f upload ${RHEV_ISO_DOMAIN_TMP_DIR}/${hook_object}.iso"
  #ssh ${ssh_opts} ${RHEV_ISO_DOMAIN_HOST} $remote_cmd
}

#
# Requires sudorule:
#  foreman ALL=(vdsm) NOPASSWD:/bin/rm
#
function iso_domain_delete() {
  local hook_object=$1
  # The wildcards mask UUID folders..., lets hope the structure does'nt change?
  if test -f ${RHEV_ISO_DOMAIN_PATH}/${hook_object}.iso; then
    sudo -u vdsm rm -f ${RHEV_ISO_DOMAIN_PATH}/${hook_object}.iso &&
      { log_info "Delete ${hook_object}.iso from ISO Domain done"; } ||
      { log_err "Delete ${hook_object}.iso from ISO Domain failed"; exit 1; }
  fi
}

#
#
#
function rhev_boot_once() {
  local hook_object=$1
  local event=$2
  local cr_url=$3
  local cr_user=$4
  local cr_passwd=$5

  local vm_uuid=$(hook_data host.uuid)
  # Setting options for ruby rest scripts
  local opts=""
  opts="${opts} --event ${event}"
  opts="${opts} --crurl ${cr_url}"
  opts="${opts} --cruser ${cr_user}"
  opts="${opts} --crpassword ${cr_passwd}"
  opts="${opts} --vmuuid ${vm_uuid}"
  opts="${opts} --isofile ${hook_object}.iso"

  log_info "Configuring boot once and starting vm: ${vm_uuid}"
  log_debug "${HOOK_DIR}/scripts/rhev-rest-client.rb ${opts}"
  ${HOOK_DIR}/scripts/rhev-rest-client.rb ${opts} &&
    { log_info "Boot once vm: $vm_uuid success"; } ||
    { log_err "Boot once vm: $vm_uuid failed"; exit 1; }
}

#
# Post provisioning tasks
#
function rhev_post_provision() {
  local hook_object=$1
  local event=$2
  local cr_url=$3
  local cr_user=$4
  local cr_passwd=$5

  local vm_uuid=$(hook_data host.uuid)
  # Setting options for ruby rest scripts
  local opts=""
  opts="${opts} --event ${event}"
  opts="${opts} --crurl ${cr_url}"
  opts="${opts} --cruser ${cr_user}"
  opts="${opts} --crpassword ${cr_passwd}"
  opts="${opts} --vmuuid ${vm_uuid}"
  opts="${opts} --isofile ${hook_object}.iso"

  log_info "Running post provisioning tasks for vm: ${vm_uuid}"
  ${HOOK_DIR}/scripts/rhev-rest-client.rb ${opts} &&
    { log_info "Post-provsioning vm: ${vm_uuid} success"; } ||
    { log_err "Post-Provisioning vm: ${vm_uuid} failed"; exit 1; }
}

