#!/usr/bin/ruby193-ruby

require 'syslog'
require 'optparse'
require 'rest-client'
require 'rexml/document'
require 'rubygems'
require 'active_support'

load '/etc/foreman/encryption_key.rb'

ENCRYPTION_PREFIX = "encrypted-"
MAX_RETRY_ATTEMPTS = 10 # 
RETRY_INTERVAL = 5 # Retry interval in seconds, used as base and multiplied with retry attempts to exponantially wait longer.

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-e', '--event EVENT', 'Hook event: [create|after_build] || before_provision') { |v| options[:event] = v }
  opts.on('-h', '--crurl URI', 'Compute Resource URL') { |v| options[:cr_url] = v }
  opts.on('-u', '--cruser NAME', 'Compute Resource username') { |v| options[:cr_user] = v }
  opts.on('-p', '--crpassword PASSWORD', 'Compute Resource password') { |v| options[:cr_passwd] = v }
  opts.on('-i', '--vmuuid UUID', 'UUID of the VM') { |v| options[:vm_uuid] = v }
  opts.on('-f', '--isofile FILENAME', 'Filename of ISO to connect') { |v| options[:iso_file] = v }

end.parse!


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
    loginfo("String does not start with the prefix '#{ENCRYPTION_PREFIX}', so was not decrypted")
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
    logerr("ERROR: Decryption failed for string. Please check that the ENCRYPTION_KEY has not changed.")
  end
  loginfo("INFO: Decrypted compute resource password")
  return str
end

def setup_rest_client(cr_url, cr_user, cr_passwd) # Setup the rest-client resource
  begin
    resource = RestClient::Resource.new(cr_url, cr_user, decrypt_field(cr_passwd))
  rescue Exception => e
    logerr("ERROR: Failed to setup rest client resource.")
    logerr(e.message)
    logerr(e.backtrace.inspect)
  end
  return resource
end

def check_vm_status(rest_resource, vm_uuid)
  begin
    status = rest_resource['/vms/' + vm_uuid].get :accept_type => 'application/json'
    status = REXML::Document.new status
    status = REXML::XPath.match(status, "//vm//status//state//()").join.to_s
    loginfo('INFO: VM ' + vm_uuid + ' status: ' + status)
  rescue Exception => e
    logerr('ERROR: Failed to get status of VM ' + vm_uuid)
    logerr(e.message)
    logerr(e.backtrace.inspect)
  end
  return status
end

def wait_for_vm_status(rest_resource, vm_uuid, status)
  begin
    retries = 0
    while retries < MAX_RETRY_ATTEMPTS do
      if check_vm_status(rest_resource, vm_uuid) != status
        retries += 1
        loginfo('Waiting for VM ' + vm_uuid  + ' status to change...')
        sleep(2 * retries)
      else
        return status
      end
    end
    raise 'Timeout: MAX_RETRY_ATTAMPTS reached'
  rescue Exception => e
    logerr('ERROR: Failed while waiting for vm status change.')
    logerr(e.message)
    logerr(e.backtrace.inspect)
  end
end

def vm_stop(rest_resource, vm_uuid)
  begin
    action = '<action></action>'
    rest_resource['/vms/' + vm_uuid + '/stop'].post action, 
      :content_type => 'application/xml',
      :accept_type  => 'application/xml'
  rescue Exception => e
    logerr('ERROR: Failed performing stop action on vm' + vm_uuid)
    logerr(e.message)
    logerr(e.backtrace.inspect)
  end
end

def vm_boot_once_cdrom(rest_resource, vm_uuid, iso_file)
  begin
    loginfo('INFO: VM action start, ' + vm_uuid + ', with one time boot.dev=cdrom ' + iso_file)
    action = '<action><pause>false</pause><vm><stateless>false</stateless><os><boot dev="cdrom"/></os><cdroms><cdrom><file id="' + iso_file + '"/></cdrom></cdroms></vm></action>'
    rest_resource['/vms/' + vm_uuid + '/start'].post action,
      :content_type => 'application/xml',
      :accept_type  => 'application/xml'
  rescue Exception => e
    logerr('ERROR: VM action start, with boot_once_cdrom failed for vm' + vm_uuid)
    logerr(e.message)
    logerr(e.backtrace.inspect)
  end
end

def vm_start(rest_resource, vm_uuid)
  begin
    loginfo('INFO: VM action start,' + vm_uuid)
    action = '<action></action>'
    rest_resource['/vms/' + vm_uuid + '/start'].post action,
      :content_type => 'application/xml',
      :accept_type  => 'application/xml'
  rescue Exception => e
    logerr('ERROR: Failed performing start action on vm' + vm_uuid)
  end
end

# Setup the rest client resource
begin
  rest_client = setup_rest_client(options[:cr_url],
                                  options[:cr_user],
                                  options[:cr_passwd])
rescue Exception => e
  logerr(e.message)
  logerr(e.backtrace.inspect)
end


# Perform actions based on hook event
begin
  case options[:event]

    when 'create', 'after_build'
      loginfo('INFO: Begin ' + options[:event])
      # Check status of VM, it it is not down stop it..
      if check_vm_status(rest_client, options[:vm_uuid]) != 'down'
        loginfo('INFO: Stopping VM ' + options[:vm_uuid]) 
        vm_stop(rest_client, options[:vm_uuid])  
        wait_for_vm_status(rest_client, options[:vm_uuid], 'down')
        sleep(10) # If we try to start the vm too quickly after stopping it, we might recive 400 Bad Request
      end
      # The VM is down, configure one time boot and start it. 
      vm_boot_once_cdrom(rest_client, options[:vm_uuid], options[:iso_file])

    when 'after_provision'
      loginfo('INFO: Begin ' + options[:event])
      wait_for_vm_status(rest_client, options[:vm_uuid], 'down')
      # The VM is down, configure one time boot and start it. 
      sleep(10) # If we try to start the vm too quickly after stopping it, we might recive 400 Bad Request
      vm_start(rest_client, options[:vm_uuid])
      loginfo('VM: ' + options[:vm_uuid]  + ' before_provision task complete.')

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
