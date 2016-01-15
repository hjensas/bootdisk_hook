# bootdisk_hook
Hook scripts for Foreman/Red Hat Satellite to provision hosts using the foreman bootdisk host image.

## Backround
When DHCP servers are not available in all subnets the foreman bootdisk ISO
imaga can be used to bootstrap a systems and start a kickstart installation.

To make the process of provisioning systems automatic these hooks will
automate the following tasks:

### When a host is created, or placed in build mode the hook will:
1. Download the bootdisk ISO from satellite
2. For compute resources, upload the ISO to: RHEV ISO Domain, VMWare datastore etc.
3. Connect the bootdisk ISO image to the host.
4. Configure the host to boot from CD-Rom.

### When the kicstart reports to foreman that the host is built
1. Wait for the VM to shutdown. (Kickstart need to be configured to do a poweroff, not a reboot)
2. Remove/Disconnect/Unmount the ISO image from the host.
3. Reconfigure the host to boot from hard drive.
4. Start the host.

## Barematal

The scripts in this repo does not contain any baremetal support, but adding such support using
hardware vendor remote management (BMC) is possible. 

## RHEV

TODO

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

