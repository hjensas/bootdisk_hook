##
# Assumes foreman user is set up for passwordless ssh access to libvirt
#   using ssh-key based authentication.
#
function connect_bootdisk_libvirt() {
  local event=$1
  local cr_id=$2
  local cr_url=$3
  case "$event" in
    create|after_build)
      log_info "Connect foreman bootdisk to Libvirt VM: ."
      # TODO
      #virsh -c ${cr_url} list
    ;;
    before_provision)
      log_info "Disconnect foreman bootdisk from Libvirt VM: ."
      # TODO
    ;;
    update)
      # NOOP
    ;;
    destroy)
      # TODO
    ;;
    *)
      log_err "Unknown hook event $event"
      exit 1
    ;;
  esac
  return 0
}
