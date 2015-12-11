# Deploy Contrail Networking by Juju

This guidance shows how to deploy a Contrail Cloud (based on OpenStack and OpenContrail) by Juju charms.


## 1 Juju deployment environment

The setup consists of the following 3 servers. The host OS of all servers is Ubuntu 14.04.2 LTS (GNU/Linux 3.16.0-30-generic x86_64) OpenSSH server.

* 10.84.29.100: Juju server
* 10.84.14.47: Controller
* 10.84.14.48: Compute Node


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
```
$ juju generate-config
$ juju switch manual
```

* Update `bootstrap-host` in section `manual` in ~/.juju/environments.yaml. In this case, it's the IP address where bootstrap runs, 10.84.29.100.

* Launch bootstrap on bootstrap host.
Note, multi-interface is not supported by Juju. It can't be configured to use which interface for deployment. Ensure single interface up before bootstrap of Juju server. Other interfaces can be re-opened after bootstrap.
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
On target machine, download GPG key and update apt source list.
```
$ wget http://<server IP>/contrail/repo/key
$ apt-key add key
# Update /etc/apt/sources.list.
# deb http://<host IP>/contrail/repo /
```
These steps are done by charm, no need to do them manually.

* config.yaml
```
Here is an example of source and key configuration in config.yaml.
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
$ bzr branch lp:~sdn-charmers/charms/trusty/quantum-gateway/contrail charms/trusty/quantum-gateway-contrail
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
```
keystone:
  admin-role: admin
  admin-password: contrail123

mysql:
  dataset-size: 15%

nova-cloud-controller:
  network-manager: Neutron

nova-compute:
  manage-neutron-plugin-legacy-mode: False

cassandra:
  allow-single-node: true
```

### 2.2 Install services

#### 2.2.1 OpenStack version
OpenStack Icehouse is provided as the default OpenStack release on Ubuntu 14.04 so no additional configuration is required in 14.04 deployments.

OpenStack Juno is provided as the default OpenStack release on Ubuntu 14.10 so no additional configuration is required in 14.10 deployments.

To deploy OpenStack Juno on Ubuntu 14.04, use the 'openstack-origin' configuration option, for example:
```
cat > config.yaml << EOF
nova-cloud-controller:
  openstack-origin: cloud:trusty-juno
EOF
juju deploy --config config.yaml nova-cloud-controller
```


#### 2.2.2 Resolvable hostname
Some services, like RabbitMQ, Cassandra, Contrail analytics (collector) and Contrail control require resolvable hostname, but charm doesn't configure it in the container. Here are the steps to deploy those services, 1) create container, 2) wait till container is up and update /etc/hosts in it, 3) deploy service in that container.

Here is an example.
```
juju add-machine lxc:1
# Wait till the container is ready (agent-state: started).
juju scp set-hosts.sh 1/lxc/0:
juju run --machine 1/lxc/0 "sudo ./set-hosts.sh"
juju deploy --to 1/lxc/0 trusty/rabbitmq-server
```

set-hosts.sh
```
#!/bin/sh

ip=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d"/" -f1)
hostname=$(hostname)

echo "$ip    $hostname" >> /etc/hosts
```

#### 2.2.3 Install services
All OpenStack services are deployed by charms from Charms Store as is. Four Contrail service charms to deploy Contrail configuration, analytics, control and Web UI. Two subordinate charms (neutron-api-contrail and neutron-contrail) are for making Contrail specific changes to Neutron API and Nova Compute services.

Here is the deploy.sh.
```
#!/bin/bash

container_create()
{
    # $1: machine ID

    cid=$(juju add-machine lxc:1 2>&1 | awk '{print $3}')
    echo "Container $cid is added, waiting for it starts..."
    loop=1
    while [ $loop == "1" ]
    do
        sleep 3
        state=$(juju status | grep -A 1 $cid | grep started | awk '{print $2}')
        if [[ $state == "started" ]]
        then
            loop=0
            echo ""
            echo "Container $cid starts."
        else
            echo -n "*"
        fi
    done
}

export JUJU_REPOSITORY=charms

for service in \
    "trusty/rabbitmq-server" \
    "--config config.yaml trusty/mysql" \
    "--config config.yaml trusty/keystone" \
    "--config config.yaml trusty/nova-cloud-controller" \
    "trusty/glance" \
    "trusty/openstack-dashboard" \
    "trusty/neutron-api" \
    "trusty/zookeeper" \
    "local:trusty/contrail-configuration" \
    "local:trusty/contrail-control" \
    "local:trusty/contrail-analytics" \
    "local:trusty/contrail-webui"
do
    container_create 1
    juju scp host-provision.sh $cid:
    juju run --machine $cid "sudo ./host-provision.sh"
    echo "Deploy service $service..."
    juju deploy --to $cid $service
    echo ""
done

juju deploy --to lxc:1 --config config.yaml precise/cassandra

echo "Deploy compute node..."
juju deploy --to 2 --config config.yaml trusty/nova-compute
juju deploy local:trusty/neutron-api-contrail
juju deploy local:trusty/neutron-contrail
echo "Done."
```


### 2.3 Connect services
Wait till all services are installed.
```
juju add-relation keystone mysql
juju add-relation nova-cloud-controller mysql
juju add-relation nova-cloud-controller rabbitmq-server
juju add-relation nova-cloud-controller glance
juju add-relation nova-cloud-controller keystone
juju add-relation glance mysql
juju add-relation glance keystone
juju add-relation openstack-dashboard keystone
juju add-relation nova-compute:shared-db mysql:shared-db
juju add-relation nova-compute:amqp rabbitmq-server:amqp
juju add-relation nova-compute glance
juju add-relation nova-compute nova-cloud-controller
juju add-relation neutron-api mysql
juju add-relation neutron-api rabbitmq-server
juju add-relation neutron-api nova-cloud-controller
juju add-relation neutron-api:identity-service keystone:identity-service
juju add-relation neutron-api:identity-admin keystone:identity-admin

juju add-relation contrail-configuration:cassandra cassandra:database
juju add-relation contrail-configuration zookeeper
juju add-relation contrail-configuration rabbitmq-server
juju add-relation contrail-configuration keystone

juju add-relation neutron-api contrail-configuration
juju add-relation contrail-control:contrail-discovery contrail-configuration:contrail-discovery
juju add-relation contrail-control:contrail-ifmap contrail-configuration:contrail-ifmap
juju add-relation contrail-analytics:cassandra cassandra:database
juju add-relation contrail-analytics contrail-configuration

juju add-relation nova-compute neutron-contrail
juju add-relation neutron-contrail:contrail-discovery contrail-configuration:contrail-discovery
juju add-relation neutron-contrail:contrail-api contrail-configuration:contrail-api
juju add-relation neutron-contrail keystone

juju add-relation contrail-webui keystone
juju add-relation contrail-webui:contrail_discovery contrail-configuration:contrail-discovery
```

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

