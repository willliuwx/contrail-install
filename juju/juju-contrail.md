# Deploy Contrail Networking by Juju

This guidance shows how to deploy Contrail networking and OpenStack by Juju charms.


## 1 Juju deployment environment

The setup consists of the following servers. The host OS of all servers is Ubuntu 14.04.2 LTS (GNU/Linux 3.16.0-30-generic x86_64) OpenSSH server.

* 1 Juju server runs Juju client and bootstrap.
* 3 Controllers run 3 instances of all OpenStack and Contrail services, except for computing services (Nova compute and Contrail vrouter), to provide HA.
* 1 Compute Node runs Nova compute and Contrail vrouter.


### 1.1 Juju server

* Install Juju packages.
```
$ sudo apt-get install software-properties-common
$ sudo add-apt-repository ppa:juju/stable
$ sudo apt-get install juju-core
```

* Upgrade Juju to 1.24.
```
$ sudo apt-get upgrade juju-core
```

* Configure Juju to manual mode.
Normally, Juju deployment is based on MAAS. For this setup, all machines are manually provisioned.
```
$ juju generate-config
$ juju switch manual
```

* Update `bootstrap-host` in section `manual` in ~/.juju/environments.yaml. In this case, it's the server IP address where bootstrap runs.

Note, multi-interface is not supported by Juju. It can't be configured to use specific interface for deployment. Ensure single interface up before starting bootstrap of Juju server. Other interfaces can be re-enabled after bootstrap.

* Launch bootstrap on bootstrap host.
```
$ juju bootstrap
```


### 1.2 Contrail repository
Note, this is only required for the deployment with Juniper Contrail package. In case of using Launchpad PPA, this is not needed.

* Install required packages.
```
$ sudo apt-get install dpkg-dev
$ sudo apt-get install dpkg-sig
$ sudo apt-get install rng-tools
```

* Get Contrail installation package, install it and build a repository.
```
$ sudo dpkg -i contrail-install-packages_2.20-64~ubuntu-14-04icehouse_all.deb
$ cd /opt/contrail
$ mkdir repo
$ tar -C repo -xzf contrail_packages/contrail_debs.tgz
```

* Generate GPG key.
```
$ sudo rngd -r /dev/urandom
$ sudo cat /proc/sys/kernel/random/entropy_avail
$ gpg --gen-key
  4           # RSA (sign only)
  4096        # 4096 bit
  0           # key does not expire
  y           # yes
  contrail    # Real name
  Enter       # Email address
  Enter       # Comment
  o           # OK
  Enter       # passphrase
  Enter       # confirm passphrase
$ gpg --list-keys
```

* Export key into repo, sign packages, generate index and release files.
```
$ cd repo
$ dpkg-sig --sign builder *.deb

$ apt-ftparchive packages . > Packages
$ sed -i 's/Filename: .\//Filename: /g' Packages 
$ gzip -c Packages > Packages.gz

$ apt-ftparchive release . > Release
$ gpg --clearsign -o InRelease Release
$ gpg -abs -o Release.gpg Release

$ gpg --output key --armor --export <key ID>
```

* Install HTTP server.
```
$ sudo apt-get install mini-httpd
```
Update /etc/default/mini-httpd to enable the start.
Update /etc/mini-httpd.conf to set host and root directory.

* Set apt source.
The following steps are done by charm, no need to do them manually. Here just shows how source and key are used. On target machine, download GPG key and update apt source list.
```
$ wget http://<server IP>/contrail/repo/key
$ apt-key add key
# Update /etc/apt/sources.list.
# deb http://<host IP>/contrail/repo /
```

* config.yaml
Installation source and key have to be configured in configuration file. Here is an example.
```
  install-sources:
    type: string
    default: |
      - "deb http://10.84.29.100/contrail/repo /"
    description: Package sources for install
  install-keys:
    type: string
    default: |
      - "http://10.84.29.100/contrail/repo/key"
    description: GPG key for install
```


### 1.3 Target machine
The following steps are for preparing servers. In case of using MAAS, these are not required.

Ensure networking, NTP and resolvable hostname are all set.

In manual mode, some additional steps are required on target machine.

* Install additional packages.
```
$ sudo apt-get install software-properties-common python-yaml
```

* Install LXC.
As stated in Co-location Support in [Provider Colocation Support](https://wiki.ubuntu.com/ServerTeam/OpenStackCharms/ProviderColocationSupport), it's a general rule to deploy charms in separate containers/machines.
```
$ sudo apt-get install lxc
```
Note, LXC is not required on compute node.

* Configure LXC bridge.
Update `/etc/network/interfaces`. Here is an example.
```
auto p1p1
iface p1p1 inet manual

auto lxcbr0
iface lxcbr0 inet static
    address 10.84.14.47
    netmask 255.255.255.0
    gateway 10.84.14.254
    dns-nameservers 10.84.5.100
    dns-search juniper.net
    bridge_ports p1p1
```


### 1.4 Add target machine
* Add machines.
```
$ juju add-machine ssh:10.84.14.47
$ juju add-machine ssh:10.84.14.48
```


### 1.5 Juju GUI
* Add Juju GUI onto Juju server.
```
$ juju deploy juju-gui --to 0
$ juju expose juju-gui
```
Wait a few minutes until the GUI server is up. User name and password are in ~/.juju/environments/manual.jenv ('username' and 'password').


## 2 Deploy OpenStack and OpenContrail

### 2.1 Fetch charms
* Download required Juju charms on Juju server.
```
$ sudo apt-get install bzr
$ mkdir -p charms/trusty
$ bzr branch lp:~sdn-charmers/charms/trusty/contrail-analytics/trunk charms/trusty/contrail-analytics
$ bzr branch lp:~sdn-charmers/charms/trusty/contrail-configuration/trunk charms/trusty/contrail-configuration
$ bzr branch lp:~sdn-charmers/charms/trusty/contrail-control/trunk charms/trusty/contrail-control
$ bzr branch lp:~sdn-charmers/charms/trusty/contrail-webui/trunk charms/trusty/contrail-webui
$ bzr branch lp:~sdn-charmers/charms/trusty/neutron-contrail/trunk charms/trusty/neutron-contrail
$ bzr branch lp:~sdn-charmers/charms/trusty/neutron-api-contrail/trunk charms/trusty/neutron-api-contrail
$ export JUJU_REPOSITORY=charms
```

* Update install-resources for each charm.
Update install-sources in config.yaml of each charm to use Contrail 2.20 PPA.
```
  install-sources:
    type: string
    default: |
      - "ppa:opencontrail/ppa"
      - "ppa:opencontrail/r2.20"
    description: Package sources for install
```

* Update install-keys for each charm.
Install-keys is for using Contrail repository only. Note, the number of instal-keys has to be the same as the number of instal-resources.
```
  install-sources:
    type: string
    default: |
      - "deb http://10.84.29.100/contrail/repo /"
    description: Package sources for install
  install-keys:
    type: string
    default: |
      - "http://10.84.29.100/contrail/repo/key"
    description: GPG key for install
```

* Create config.yaml.
[config.yaml](config.yaml)


### 2.2 Install services

#### 2.2.1 OpenStack version
OpenStack Icehouse is provided as the default OpenStack release on Ubuntu 14.04 so no additional configuration is required in 14.04 deployments.

OpenStack Juno is provided as the default OpenStack release on Ubuntu 14.10 so no additional configuration is required in 14.10 deployments.

To deploy OpenStack Juno on Ubuntu 14.04, use the 'openstack-origin' configuration option, for example:
```
nova-cloud-controller:
  openstack-origin: cloud:trusty-juno
```


#### 2.2.2 Resolvable hostname
Some services, like RabbitMQ, Cassandra, Contrail analytics (collector) and Contrail control require resolvable hostname, but charm doesn't configure it in the container. Here are the steps to deploy those services, 1) create container, 2) wait till container is up and update /etc/hosts in it, 3) deploy service in that container.


#### 2.2.3 Install services
All OpenStack services are deployed by charms from Charms Store as is. Four Contrail service charms to deploy Contrail configuration, analytics, control and Web UI. Two subordinate charms (neutron-api-contrail and neutron-contrail) are for making Contrail specific changes to Neutron API and Nova Compute services.


### 2.3 Connect services


### 2.4 Contrail Configuration

* Add link local service for metadata.
```
# config add global-vrouter --linklocal name=metadata,linklocal-address=169.254.169.254:80,fabric-address=<Nova controller>:8775
```

* Add vrouter configuration.
```
# config add vrouter <hostname> --address <IP address>
```

* Add BGP router configuration.
```
# config add bgp-router <hostname> --vendor Juniper --asn 64512 --address <IP address> --control
```

