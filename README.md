# bootdisk_hook
Hook scripts for Foreman/Red Hat Satellite to provision hosts using the foreman bootdisk host image.

The hook will check if there is DHCP enabled on the subnet and just exit if this is the case, this allows the hook to be used in a mixed environment where DHCP is enabled for some subnets.

Because the hook needs to be started at create event, the hook has to fork a background process that will wait for the host object to be available in foreman and then continue the provisioning operation. Unless we do this, the host is not available when the hook tries to download the bootdisk image. (Using the after_create event was attempted, but the host object is not in foreman even after the after_create event)

# Table of Contents
* [Background](#background)
* [Setup](#setup)
  * [Create user in Foreman/Satellite 6](#foreman-user)
  * [Configure hammer to use our user without prompting for password](#hammer-passwd)
  * [Configure sudo](#sudo)
  * [.cache directory in foreman users $HOME](#.cache_dir)
  * [oVirt/RHEV](#ovirt)
  * [Configuration file](#config-file)
  * [Set up the hook directory structure](#hook-struct)
  * [Create symlinks to the hook for each event](#hook-symlinks)
  * [Change templates to not requre DHCP](#no_dhcp_templates)
* [SELinux](#selinux)
* [Baremetal](#baremetal)


## <a id="background"></a>Backround
When DHCP servers are not available in all subnets the foreman bootdisk ISO
imaga can be used to bootstrap a systems and start a kickstart installation.

To make the process of provisioning systems automatic these hooks will
automate the following tasks:

#### When a host is created, or placed in build mode the hook will:
1. Download the bootdisk ISO from satellite
2. For compute resources, upload the ISO to: RHEV ISO Domain, VMWare datastore etc.
3. Connect the bootdisk ISO image to the host.
4. Configure the host to boot from CD-Rom.

#### When the kicstart reports to foreman that the host is built
1. Wait for the VM to shutdown. (Kickstart need to be configured to do a poweroff, not a reboot)
2. Remove/Disconnect/Unmount the ISO image from the host.
3. Reconfigure the host to boot from hard drive.
4. Start the host.

## <a id="setup"></a>Setup

### <a id="foreman-user"></a>Create user in Foreman/Satellite 6

The hooks use hammer and the Foreman/Satellite 6 REST API, create a user for the hook and 
add the just the required roles instead of using the admin account.

#### Create the user
```
hammer user create \
  --firstname Boot \
  --lastname Disk \
  --login bootdisk \
  --mail "admin@example.com" \
  --organizations "Example ORG" \
  --locations example_loc \
  --auth-source-id 1 \
  --password 85fb46a73ce646e48af68a4f3dead702
```

#### Add roles to the user

```
hammer user add-role --login bootdisk2 --role "Viewer"
hammer user add-role --login bootdisk2 --role "View hosts"
hammer user add-role --login bootdisk2 --role "Boot disk access"
```

### <a id="hammer-passwd"></a>Configure hammer to use our user without prompting for password

The hook is running as user foreman, we need to setup hammer cli_config for this user to use the bootdisk user, and not prompt for a password.

```
mkdir -p /usr/share/foreman/.hammer/cli_config.yml
```

```
cat << EOF > /usr/share/foreman/.hammer/cli_config.yml
:ui:
  :interactive: false

:foreman:
    :enable_module: true
    :host: 'https://sat61.lnx.example.com/'
    :username: 'bootdisk'
    :password: '85fb46a73ce646e48af68a4f3dead702'
EOF
```

```
chown -R foreman:foreman /usr/share/foreman/.hammer
```

```
chmod 0600 /usr/share/foreman/.hammer/cli_config.yml
```

### <a id="sudo"></a>Configure sudo

Sudo must be configured to allow the foreman user to run /usr/bin/logger.

```
cat << EOF > /etc/sudoers.d/foreman-hooks 
#
# The requiretty default is a non-sensible default.
#   it does not add any benefits, but it breaks valid sudo usage.
#
#  See https://bugzilla.redhat.com/show_bug.cgi?id=1020147 for details.
#
# The default on RHEL is to require a tty.
# To allow the bootdisk hook to use sudo, we are disabling requiretty for the
# foreman user.
#
Defaults:foreman !requiretty

#
foreman ALL=(ALL) NOPASSWD:/usr/bin/logger
EOF
```

### <a id=".cache_dir"></a>.cache directory in foreman useds $HOME

hammer might need a .cache directory in $HOME/.cache for bootdisk downloads to
work.

```
mkdir /usr/share/foreman/.cache
chown foreman:foreman /usr/share/foreman/.cache
```

## <a id="no_dhcp_templates"></a>Change templates to not requre DHCP

By default the provisioning templates will create a bootdisk that require a DHCP
server. To generate bootdisk images that does not require a DHCP server the iPXE
and/or PXELINUX templates must be modified to pass network configuration to
Anaconda by appending the configuration on kernel command line.

Lukas Zapletal wrote this excellent blog article which explain how to modify the
templates:

  https://lukas.zapletalovi.com/2015/10/foreman-and-pxe-less-environments.html

## <a id="ovirt"></a>oVirt/RHEV

### RHEV/Ovirt Specific sudo rules and users

For RHEV/Ovirt we also need to run cp and rm as the vdsm user to upload the bootdisk ISO file to the ISO Domain. This is needed to set the correct user/group on the file when copying it to the ISO Domain.

#### Create RHEV/Ovirt specific users/groups

```
groupadd -g 36 kvm
useradd --system -u 36 -g 36 --no-create-home --shell /bin/nologin vdsm
```

#### Add RHEV/Ovirt spcific sudorules
```
echo "foreman ALL=(vdsm) NOPASSWD:/bin/cp" >> /etc/sudoers.d/foreman-hooks
echo "foreman ALL=(vdsm) NOPASSWD:/bin/rm" >> /etc/sudoers.d/foreman-hooks
```

### Mount the RHEV/Ovirt ISO Domain to the Foreman/Satellite 6 server

```
echo "rhevm.lnx.example.com:/var/lib/exports/iso /iso_domain   nfs _netdev,defaults 0 0" >> /etc/fstab

mount -a
```

## <a id="config-file"></a>Configuration file

The bootdisk_hook scripts expects to find its configuration file in
/etc/foreman/hooks/foreman_bootdisk.conf. The configurationf file is
a shellvar file that is sourced by the hook scripts. The parameters are
specified below.

The directory /etc/foreman/hooks does not exist by default, this should be
creted.

```
mkdir -p /etc/foreman/hooks
```

Since the configuration file contains password for the foreman/satellite 6
user it makes sense to limit the permissions...

```
chown foreman:foreman /etc/foreman/hooks/foreman_bootdisk.conf
chmod 0600 /etc/foreman/hooks/foreman_bootdisk.conf
```

### HOOK_DIR

The directory where the hook scripts live.

### LOG_LEVEL

Log levels debug, info or error is supported.

### MAX_RETRY_ATTEMPTS

Controls how many times we try to perform tasks/checks that might
not complete. Such as waiting for the foreman host object to be 
completely created.

### BASE_RETRY_INTERVAL

Time in seconds to wait before retrying a task/check. This number is multiplied
with for each attempt to increase the wait time for each iteration.

### USE_FULL_HOST_IMAGE

Wheater to use the full foreman bootdisk, if false the iPXE image will be used.

### BOOT_DISK_STORE

The local directory where bootdisk ISO's are stored.

### FOREMAN_HOST

The FQDN of the foreman/satellite 6 server.

### FOREMAN_USER

Foreman user username

### FOREMAN_PASSWD

Foreman user password

### OVIRT_ISO_DOMAIN_PATH

The oVirt/RHEV iso domain needs to be mounted on the foreman/satellite
server. The OVIRT_ISO_DOMAIN_PATH points the full path to the directory 
on the NFS server where ISO files is stores.

e.g:  /nfs_mnt/<uuid>/images/<111...>

## <a id="selinux"></a>SELinux

TODO 

## <a id="hook-struct"></a>Set up the hook directory structure

Foreman hooks are stored under /usr/share/foreman/config/hooks, dirctories for
objects and subdirectories for events. In this case we need to create the following structure.

```
└── host
    └── managed
        ├── after_build
        ├── after_provision
        └── create
```

## <a id="hook-symlinks"></a>Create symlinks to the hook for each event.

```
ln -s /usr/share/foreman/config/bootdisk_hook/bootdisk_hook host/managed/create/20_bootdisk_hook
ln -s /usr/share/foreman/config/bootdisk_hook/bootdisk_hook host/managed/after_provision/20_bootdisk_hook
ln -s /usr/share/foreman/config/bootdisk_hook/bootdisk_hook host/managed/after_build/20_bootdisk_hook

```

## <a id="baremetal"></a>Barematal

The scripts in this repo does not contain any baremetal support, but adding such support using
hardware vendor remote management controller with support for virtual media is possible. 


## VMWare

TODO

### Example log output, when bootdisk_hook provisions VMWare vm using the foreman bootdisk
```
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11027]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - Subnet ID: 2, DHCP disabled
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11029]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - DHCP is disabled, running bootdisk hook
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11031]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/foreman_object_wait after_build vmware01.prod.example.com /tmp/foreman_hooks.h5MGaCne3Q
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11033]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/bootdisk_get after_build vmware01.prod.example.com /tmp/foreman_hooks.h5MGaCne3Q
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11035]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/bootdisk_provision after_build vmware01.prod.example.com /tmp/foreman_hooks.h5MGaCne3Q
Dec 31 17:22:15 sat61.lnx.example.com bootdisk_hook[11037]: 20_bootdisk_hook DEBUG - after_build vmware01.prod.example.com - Command: rm -f /tmp/foreman_hooks.h5MGaCne3Q
Dec 31 17:22:19 sat61.lnx.example.com bootdisk_hook[11054]: bootdisk_get INFO - after_build vmware01.prod.example.com - Succesfully downloaded foreman bootdisk
Dec 31 17:22:21 sat61.lnx.example.com bootdisk_hook[11079]: bootdisk_provision DEBUG - after_build vmware01.prod.example.com - Compute resource provider is: VMWare
Dec 31 17:22:22 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Decrypted compute resource password
Dec 31 17:22:22 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Begin after_build
Dec 31 17:22:22 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Action stop vm: vmware01.prod.example.com
Dec 31 17:22:22 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Action stop vm: vmware01.prod.example.com completed succesfylly
Dec 31 17:22:23 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Uplaoding ISO to dataststore: vmware01.prod.example.com/vmware01.prod.example.com.iso
Dec 31 17:22:28 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Re-config vm: vmware01.prod.example.comadd cdrom, set bootdev: cd
Dec 31 17:22:28 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Re-config vm: vmware01.prod.example.comtask complete
Dec 31 17:22:28 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Action start vm: vmware01.prod.example.com
Dec 31 17:22:29 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[11092]: INFO: Action start vm: vmware01.prod.example.com completed successfylly


Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2709]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - Subnet ID: 2, DHCP disabled
Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2712]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - DHCP is disabled, running bootdisk hook
Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2714]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/foreman_object_wait after_provision vmware01.prod.example.com /tmp/foreman_hooks.YgHdrcRBYa
Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2716]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/bootdisk_get after_provision vmware01.prod.example.com /tmp/foreman_hooks.YgHdrcRBYa
Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2718]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - Command: /usr/share/foreman/config/bootdisk_hook/bootdisk_provision after_provision vmware01.prod.example.com /tmp/foreman_hooks.YgHdrcRBYa
Jan 02 22:47:33 sat61.lnx.example.com bootdisk_hook[2721]: 20_bootdisk_hook DEBUG - after_provision vmware01.prod.example.com - Command: rm -f /tmp/foreman_hooks.YgHdrcRBYa
Jan 02 22:47:35 sat61.lnx.example.com bootdisk_hook[2745]: bootdisk_provision DEBUG - after_provision vmware01.prod.example.com - Compute resource provider is: VMWare
Jan 02 22:47:36 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: Decrypted compute resource password
Jan 02 22:47:36 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: Begin after_provision
Jan 02 22:47:36 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: Waiting for vm vmware01.prod.example.com current state: poweredOn tochange...
Jan 02 22:47:38 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: Waiting for vm vmware01.prod.example.com current state: poweredOn tochange...
Jan 02 22:47:42 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: Waiting for vm vmware01.prod.example.com current state: poweredOn tochange...
Jan 02 22:47:48 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: Waiting for vm vmware01.prod.example.com current state: poweredOn tochange...
Jan 02 22:47:56 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: Waiting for vm vmware01.prod.example.com current state: poweredOn tochange...
Jan 02 22:48:06 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: Re-config vm: vmware01.prod.example.com remove cdrom, set bootdev: hd
Jan 02 22:48:07 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: Re-config vm task success for: vmware01.prod.example.com
Jan 02 22:48:07 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: Action start vm: vmware01.prod.example.com completed successfylly
Jan 02 22:48:07 sat61.lnx.example.com /usr/share/foreman/config/bootdisk_hook/providers/vmware.rb[2758]: INFO: ISO image: [DS01] vmware01.prod.example.com/vmware01.prod.example.com.iso succesfully deleted
Jan 02 22:48:07 sat61.lnx.example.com bootdisk_hook[2781]: bootdisk_get INFO - after_provision vmware01.prod.example.com - Succesfully deleted foreman bootdisk from bootdisk store

```

