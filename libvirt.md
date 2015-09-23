# OpenContrail connects VMs

After [installation](install.md), the following steps show how to connect VMs (launched by libvirt) with OpenContrail.

### Workflow

* Create a tap interface for VM.
* Create a port on a virtual network, and plug the tap interface into the port.
* Launch VM on the tap interface.

### Install packages
```
$ sudo apt-get kvm libvirt-bin
```

### Download utilities
```
$
```

