#!/usr/bin/ruby193-ruby
#
# TODO

require 'syslog'
require 'optparse'
require 'json'
require 'rest-client'
require 'rbvmomi'
require 'rubygems'
require 'active_support'
require 'pp'

load '/etc/foreman/encryption_key.rb'


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: vmware.rb [options]"

  opts.on('--event EVENT',
          'Hook event: create, after_build, after_provision') do |v|
    options[:event] = v
  end
  opts.on('--crid URI',
          'Compute Resource URL') do |v|
    options[:cr_id] = v
  end
  opts.on('--crpassword PASSWORD',
          'Compute Resource password') do |v|
    options[:cr_passwd] = v
  end
  opts.on('--vmuuid UUID',
          'UUID of the VM') do |v|
    options[:vm_uuid] = v
  end
  opts.on('--isopath PATH',
          'Path to ISO file') do |v|
    options[:iso_path] = v
  end
  opts.on('--foremanhost FOREMAN_HOST',
          'Foreman host fqdn') do |v|
    options[:foreman_host] = v
  end
  opts.on('--foremanuser FOREMAN_USER',
          'Foreman API user username') do |v|
    options[:foreman_user] = v
  end
  opts.on('--foremanpasswd FOREMAN_PASSWORD',
          'Foreman API user password') do |v|
    options[:foreman_passwd] = v
  end

end.parse!


#
# CONSTANTS
#
ENCRYPTION_PREFIX = "encrypted-"
MAX_RETRY_ATTEMPTS = 10 # Number of time to retry
RETRY_INTERVAL = 5 # Retry interval in seconds,
                   # used as base and multiplied with retry attempts to
                   # exponantially wait longer.

def loginfo(message)
  #$0 is the current script name
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info message }
end

def logerr(message)
  #$0 is the current script name
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.err message }
end

#
# These functions for encryption was copied 
#   from theforeman, app/models/concerns/encryptable.rb
#
def encryption_key
  #return ENV['ENCRYPTION_KEY'] if ENV['ENCRYPTION_KEY'].present?
  return EncryptionKey::ENCRYPTION_KEY if defined? EncryptionKey::ENCRYPTION_KEY
  nil
end

def matches_prefix?(str)
  ENCRYPTION_PREFIX == str.to_s[0..(ENCRYPTION_PREFIX.length - 1)]
end

def is_decryptable?(str)
  if !matches_prefix?(str)
    loginfo("String does not start with the prefix '#{ENCRYPTION_PREFIX}', "\
            "so was not decrypted")
    false
  else
    true
  end
end

def decrypt_field(str)
  return str unless is_decryptable?(str)
  encryptor = ActiveSupport::MessageEncryptor.new(encryption_key)
  begin
    # remove prefix before decrypting string
    str_no_prefix = str.gsub(/^#{ENCRYPTION_PREFIX}/, "")
    str_decrypted = encryptor.decrypt_and_verify(str_no_prefix)
    str = str_decrypted
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    logerr("ERROR: Decryption failed for string. "\
           "Please check that the ENCRYPTION_KEY has not changed.")
  end
  loginfo("INFO: Decrypted compute resource password")
  return str
end

def connect_foreman(foreman_host, foreman_user, foreman_passwd)
  begin
    foreman_uri = 'https://' + foreman_host + '/api/v2/'
    resource = RestClient::Resource.new(foreman_uri, foreman_user,
                                        foreman_passwd)
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed to setup rest client resource'
  end
  return resource
end

def get_compute_resource_obj(rest_resource, cr_id)
  begin
    cr = rest_resource['/compute_resources/' + cr_id].get \
           accept_type: 'application/json'
  rescue Exception => e
    logerr("ERROR: Failed get compute resource object")
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed to get compute resource object'
  end
  return JSON.parse(cr)
end

def connect_vsphere(host, user, password, insecure)
  begin
    connection = RbVmomi::VIM.connect host: host, user: user,
                                      password: decrypt_field(password),
                                      insecure: insecure
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed to set up vCenter connection'
  end
  return connection
end

def get_vm_config_path(vm_mob_ref)
  begin
    # Get the vmConfig path on the datastore.
    #
    # vmPathName return:
    # [<DataStore-Name>] folder/<vmx-file-name>.vmx
    path = vm_mob_ref.config.files.vmPathName.split.pop
    config_path = File.dirname(path)
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Unable to get vm config path'
  end
  return config_path
end

def upload_iso(vm_mob_ref, local_iso_path, remote_iso_filename)
  begin
    # Get the first datastore used by the VM
    ds_mob_ref = vm_mob_ref.datastore.first

    # Get the vm config path, e.g folder on the datastore
    config_path = get_vm_config_path(vm_mob_ref)

    # Upload file to datastore
    ds_mob_ref.upload(config_path + '/' + remote_iso_filename,
                             local_iso_path)
    loginfo('INFO: ISO successfylly uploaded to dataststore: ' \
             + config_path + '/' + remote_iso_filename)
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)    
    raise 'Failed to upload ISO file to datastore'
  end
end

def reconf_vm_cdrom_add_boot_cd(vm_mob_ref, iso_file)
  begin
    # Get the the IDE controller to connect cdrom too.
    ide_controller_obj = vm_mob_ref.config.hardware.device.find do |hw| 
      hw.class == RbVmomi::VIM::VirtualIDEController
    end
    # Get the first datastore used by the VM
    datastore_mob_ref = vm_mob_ref.datastore.first
    # Get the vm config path, folder on the datastore
    config_path = get_vm_config_path(vm_mob_ref)
    # Virtual Machine config spec to add cdrom, backed by ISO.
    machine_conf_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
      deviceChange: [{
        operation: 'add',
        device: RbVmomi::VIM::VirtualCdrom(
          key: '-2',
          controllerKey: ide_controller_obj.key,
          connectable: RbVmomi::VIM::VirtualDeviceConnectInfo(
            startConnected: 'true',
            connected: 'true',
            allowGuestControl: 'true'
          ),
          backing: RbVmomi::VIM::VirtualCdromIsoBackingInfo(
            fileName: "[#{datastore_mob_ref.name}] #{config_path}/#{iso_file}"
          )
        )
      }],
      extraConfig: [
        RbVmomi::VIM::OptionValue(
          key: 'bios.bootDeviceClasses',
          value: 'allow:cd'
        )
      ]
    )
    loginfo('INFO: Re-config vm: ' + vm_mob_ref.name + ' ' \
            + 'add cdrom, set bootdev: cd')
    vm_mob_ref.ReconfigVM_Task(spec: machine_conf_spec).wait_for_completion
    loginfo('INFO: Re-config vm task success for: ' + vm_mob_ref.name)
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect) 
    raise 'Failed vm reconfigure tast on vm: ' + vm_mob_ref.name
  end
end

def get_cdrom_backed_by_iso(vm_mob_ref, iso_file_name)
  begin
    vm_mob_ref.config.hardware.device.find.each do |hw|
      if hw.class == RbVmomi::VIM::VirtualCdrom then
        if File.basename(hw.backing.fileName) == iso_file_name then
          return hw
        end
      end
    end
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed finding cdrom device backed by iso: ' + iso_file_name
  end
  raise 'Unable to find cdrom device backed by iso: ' + iso_file_name
end

def reconf_vm_cdrom_remove_boot_hd(vm_mob_ref, cdrom_obj)
  begin
    # Virtual Machine config spec to remove cdrom device
    puts cdrom_obj.inspect
    machine_conf_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
      deviceChange: [{
        operation: 'remove',
        device: RbVmomi::VIM::VirtualCdrom(
          key: cdrom_obj.key,
          controllerKey: cdrom_obj.controllerKey,
          unitNumber: cdrom_obj.unitNumber
        )
      }],
      extraConfig: [
        RbVmomi::VIM::OptionValue(
          key: 'bios.bootDeviceClasses',
          value: 'allow:hd'
        )
      ]
    )
    loginfo('INFO: Re-config vm: ' + vm_mob_ref.name + ' ' \
            + 'remove cdrom, set bootdev: hd')
    vm_mob_ref.ReconfigVM_Task(spec: machine_conf_spec).wait_for_completion
    loginfo('INFO: Re-config vm task success for: ' + vm_mob_ref.name)
    
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed remove cdrom device reconfigure task on vm: ' \
           + vm_mob_ref.name
  end
end

def wait_for_vm_state(vm_mob_ref, state)
  begin
    retries = 0
    while retries < MAX_RETRY_ATTEMPTS do
      current_state = vm_mob_ref.runtime.powerState
      if current_state != state
        retries += 1
        loginfo('Waiting for vm ' + vm_mob_ref.name + ' current state: ' \
                + current_state  + ' tochange...')
        sleep(2 * retries)
      else
        return state
      end
    end
    raise 'Timeout: MAX_RETRY_ATTAMPTS reached'
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed while waiting for vm status change.'
  end
end

def vm_action_start(vm_mob_ref)
  begin
    state = vm_mob_ref.runtime.powerState
    if state == 'poweredOn'
      loginfo('INFO: vm: ' + vm_mob_ref.name + ' already powered on')
    else
      vm_mob_ref.PowerOnVM_Task.wait_for_completion
      loginfo('INFO: Action start vm: ' + vm_mob_ref.name + ' ' \
              + 'completed successfylly')
    end
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed vm PowerON task..'
  end	
end

def vm_action_stop(vm_mob_ref)
  begin
    state = vm_mob_ref.runtime.powerState
    if state == 'poweredOff'
      loginfo('INFO: vm: ' + vm_mob_ref.name + ' already powered off')
    else
      vm_mob_ref.PowerOffVM_Task.wait_for_completion
      loginfo('INFO: Action stop vm: ' + vm_mob_ref.name + ' ' \
              + 'completed succesfully')
    end
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed vm PowerOFF task..'
  end
end

def delete_iso_from_datastore(vim_connection, datacenter, path)
  begin
    file_manager = vim_connection.serviceContent.fileManager
    file_manager.DeleteDatastoreFile_Task(
      name: path, datacenter: datacenter).wait_for_completion
    loginfo('INFO: ISO image: ' + path + ' succesfully deleted')
  rescue Exception => e
    logerr(e.message)
    logerr(e.backtrace.inspect)
    raise 'Failed delete iso file from datastore..'
  end
end

iso_file_name = File.basename(options[:iso_path])

# Setup rest client connection to foreman
foreman_connection = connect_foreman(options[:foreman_host],
                                     options[:foreman_user],
                                     options[:foreman_passwd])

# Get information about the compute resource from foreman
cr_obj = get_compute_resource_obj(foreman_connection, options[:cr_id])

# Use information about compute resource to create a connection to vCenter
vim_connection = connect_vsphere(cr_obj['url'], cr_obj['user'],
                                 options[:cr_passwd], true)


# Get the datacenter vcenter managed object reference
dc_mob_ref = vim_connection.serviceInstance.find_datacenter(
               cr_obj["datacenter"])

# Use a search fileter to find the vm using instanceUuid
search_filter = { uuid: options[:vm_uuid], vmSearch: true,
                  instanceUuid: true, datacenter: dc_mob_ref }
vm_mob_ref = vim_connection.searchIndex.FindAllByUuid(search_filter).first


## Perform actions based on hook event
begin
  case options[:event]

    when 'create', 'after_build'
      loginfo('INFO: Begin ' + options[:event])
      vm_action_stop(vm_mob_ref)
      upload_iso(vm_mob_ref, options[:iso_path], iso_file_name)
      reconf_vm_cdrom_add_boot_cd(vm_mob_ref, iso_file_name)
      vm_action_start(vm_mob_ref)

    when 'after_provision'
      loginfo('INFO: Begin ' + options[:event])
      cdrom_obj = get_cdrom_backed_by_iso(vm_mob_ref, iso_file_name)
      wait_for_vm_state(vm_mob_ref, 'poweredOff')
      reconf_vm_cdrom_remove_boot_hd(vm_mob_ref, cdrom_obj)
      vm_action_start(vm_mob_ref)
      delete_iso_from_datastore(vim_connection, dc_mob_ref,
                                cdrom_obj.backing.fileName)

    else
      logerr('Event: ' + options[:event] + ' is unknown')
      raise "UNKNOWN_EVENT"

  end
rescue Exception => e
  logerr(e.message)
  logerr(e.backtrace.inspect)
  exit 1
end

exit 0

