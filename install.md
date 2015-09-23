# Install OpenContrail

### Server

Build 2 servers as controller and vrouter (hypervisor). In this example, they are Ubuntu 14.04.2. If servers are VMs, ensure nested virtualization is enabled on the host and kernel version is later than 3.16.0.

Installation source is Launchpad PPA.

Prerequisites to install OpenContrail:
* Networking is configured.
* Hostname is resolvable.
* NTP is installed and configured.

### Controller

* Install Git and download opencontrail-install.
```
$ sudo apt-get install git
$ git clone 
$ cd opencontrail-install
```

* Update parameters in contrail.conf. Here is an example.
```
controller_ip=10.84.29.96
vrouter_ip=10.84.29.97
prefix_len=24
gateway=10.84.29.254
nic=eth1
```

* Install packages and configure services.
```
$ sudo ./install controller
$ sudo ./configure controller
```

* Initialize controller.
Once installation is done. Check service status with `contrail-status`. It takes
couple minutes for services to be active. Then initialize the controller.
```
$ suod ./init controller
```

* Web UI
Now, Web UI (http://<controller IP>:8080, username `admin`, password `password`) should be up and show 1 control node, 1 analytics node and 1 config node.


### Vrouter

* Install Git and download opencontrail-install.
```
$ sudo apt-get install git
$ git clone 
$ cd opencontrail-install
```

* Update contrail.conf if it's required.

* Install packages and configure services.
```
$ sudo ./install vrouter
$ sudo ./configure vrouter
```

* Update `/etc/network/interfaces` to set NIC manual and add `vhost0` interface. Here is an example.
```
auto eth1
iface eth1 inet manual

auto vhost0
iface vhost0 inet static
    pre-up /etc/contrail/if-vhost0
    address 10.84.29.97
    netmask 255.255.255.0
    gateway 10.84.29.254
    dns-nameservers 10.84.5.100
    dns-search juniper.net
```

* Restart interfaces and vrouter service.
```
$ sudo ifdown eth1 && ifup eth1 vhost0 && service supervisor-vrouter restart
```
Now, vrouter should be up.

* Initialize vrouter.
```
$ sudo ./init vrouter
```
Now, Web UI should show 1 vrouter.


