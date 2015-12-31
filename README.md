# bootdisk_hook
Hook scripts for Foreman/Red Hat Satellite to provision hosts using the foreman bootdisk host image.


## VMWare

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
```

