# OpenContrail connects VMs

After [installation](install.md), the following steps show how to connect VMs (launched by libvirt) with OpenContrail.

### Workflow

* Create a tap interface for VM.
* Create a port on a virtual network, and plug the tap interface into the port.
* Launch VM on the tap interface.

### Install packages
```
$ sudo apt-get kvm libvirt-bin virtinst
```

* Enable the following settings in /etc/libvirt/qemu.conf to allow libvirt use tap interface.
```
clear_emulator_capabilities = 0
user = "root"
group = "root"
cgroup_device_acl = [
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
    "/dev/rtc", "/dev/hpet", "/dev/net/tun"
]
```

* Restart libvirt.
```
$ sudo service libvirt-bin restart
```

### Download utilities
```
$ git clone https://github.com/tonyliu0592/opencontrail-config.git
$ git clone https://github.com/tonyliu0592/opencontrail-netns.git
```
Update opencontrail-config/config with proper IP address.

### Create virtual network
```
$ cd opencontrail-config
$ ./config show tenant
$ # If tenant 'admin' doesn't exit, create it.
$ ./config add tenant admin
$ ./config add ipam ipam-default
$ ./config add network red --ipam ipam-default --subnet 192.168.10.0/24
$ # Check virtual network.
$ ./config show network red
```

### Create tap interface
```
$ sudo ip tuntap add tap-10 mode tap
$ sudo ip link set tap-10 up
```

### Plug tap interface
```
$ cd opencontrail-netns/opencontrail_netns
$ python tap.py -s 10.84.29.96 -n red --project default-domain:admin --tap tap-10 --start 10
```
The last argument (10) in the above example is the VM ID.

### Launch VM
* Check port to get MAC address before launching VM.
```
$ cd opencontrail-config
$ # List ports.
$ ./config show port
$ # Port name is <hostname>-<VM ID>.
$ ./config show port <port name>
```

* Get Cirros image.
```
$ wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
```

* Take this [VM configuration example](cirros.xml), update `source file`, `mac address` and `target dev`.

* Launch VM.
```
$ sudo virsh create cirros.xml
```

* Access VM.
Use VNC client connecting to VM.
After login, check the IP address that should be the same as the port.
Now, this VM is connected on virtual network by OpenContrail.

Create two tap interfaces, plug them to two ports on the save virtual network, launch VMs on those two tap interfaces, then two VM should be able to reach each other.

If two VMs are on separate virtual networks, network policy can be created to connect to virtual networks.

