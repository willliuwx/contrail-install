
# 1 Overview

This guide is to build a cluster of RHOSP 10 and Contrail 4.1.1 on 7 physical servers.


# 2 Plan

## 2.1 Physical server

* 3 controller hypervisors for hosting undercloud VM and overcloud controller VMs.
* 4 compute nodes, 2 with kernel based Contrail vrouter and 2 with DPDP based.


## 2.2 VM

The undercloud VM is on the first controller hypervisor.

On each controller hypervisor, there are 4 overcloud controller VMs.
* openstack-controller
* contrail-controller
* contrail-analytics
* contrail-analytics-database

Here is the VM spec for poc/lab purpose. For production, the best practise has to be followed.
```
openstack-controller          64GB   6    100GB
contrail-controller           48GB   6    100GB
contrail-analytics            48GB   6    100GB
contrail-analytics-database   48GB   4    100GB
appformix-controller          32GB   4    100GB
----------------------------------------------------
                             240GB  24   500GB
```
Note, AppFormix controller VM will be built separately.


## 2.3 Network

* external-api

  This is for accessing the server for management, troubeshoot, web UI, etc.

* provisioning

  This is for supporting PXE boot. Due to some L2 services (DHCP, TFTP, etc.), this network has to be on native untagged VLAN.

* internal-api

  This is for all API traffic.

* tenant

  This is for tunnel, XMPP and BGP traffic. L2 and L3 gateway has to be reachable from this network.

* storage

* storage-management

* management

  This is usually not required.


## 2.4 Network configuration

### 2.4.1 Production

For bandwidth isolation in production, it's recommended to have 3 separated interfaces (bond is prefered) for internal-api, tenant and storage. All other networks can be on the same interface. Here is an example.

Controller hypervisor
```
br0 on eno1  -> provisiong
vlan10@br0   -> external-api
vlan20@br0   -> storage-management
br1 on bond0 -> internal-api
br2 on bond1 -> tenant
br3 on bond2 -> storage
```

Overcloud VM
```
eth0        -> privisioning
vlan10@eth0 -> external-api
vlan20@eth0 -> storage-management
eth1        -> internal-api
eth2        -> tenant
eth3        -> storage
```

Compute node
```
eno1        -> provisiong
vlan10@eno1 -> external-api
vlan20@eno1 -> storage-management
bond0       -> internal-api
bond1       -> tenant
bond2       -> storage
```


### 2.4.2 PoC/Lab

As the mininum requirement, one interface will work. Normally, for PoC/Lab deployment, it would be good to have 2 interfaces. Each interface can be either physical NIC or bond interface. Here is an example.

Controller hypervisor
```
br0 on eno1  -> provisiong
vlan10@br0   -> external-api
br1 on bond0 -> internal-api
vlan20@br1   -> tenant
vlan30@br1   -> storage
vlan40@br1   -> storage-management
```

Overcloud VM
```
eth0        -> privisioning
vlan10@eth0 -> external-api
eth1        -> internal-api
vlan20@eth1 -> tenant
vlan30@eth1 -> storage
vlan40@eth1 -> storage-management
```
`eth0` and `eth1` are on bridge `br0` and `br1` respectively.

Compute node
```
eno1         -> provisiong
vlan10@eno1  -> external-api
bond0        -> internal-api
vlan20@bond0 -> tenant (vhost0)
vlan30@bond0 -> storage
vlan40@bond0 -> storage-management
```

Undercloud VM
```
eth0        -> privisioning
vlan10@eth0 -> external-api
```
`eth0` is on bridge `br0`.


# 3 Build undercloud

Reference: [INSTALLING THE UNDERCLOUD](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/9/html/director_installation_and_usage/chap-installing_the_undercloud)

#### Prepare for undercloud installation.
```
useradd stack
passwd stack
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
su - stack
mkdir ~/images
mkdir ~/templates
# check hostname and /etc/hosts.
sudo subscription-manager register
sudo subscription-manager list --available --all --matches="*OpenStack*"
sudo subscription-manager attach --pool=<pool ID>
sudo subscription-manager repos --disable=*
sudo subscription-manager repos \
    --enable=rhel-7-server-rpms \
    --enable=rhel-7-server-extras-rpms \
    --enable=rhel-7-server-rh-common-rpms \
    --enable=rhel-ha-for-rhel-7-server-rpms \
    --enable=rhel-7-server-openstack-10-rpms
sudo yum update -y
sudo reboot
```

#### Install packages.
```
sudo yum install -y python-tripleoclient
```

#### Configure undercloud.
```
cp /usr/share/instack-undercloud/undercloud.conf.sample ~/undercloud.conf
```

```
openstack undercloud install
```
In case of configuration update in undercloud.conf, has to rerun install.


#### Install images.
```
sudo yum install -y rhosp-director-images rhosp-director-images-ipa
for i in \
    /usr/share/rhosp-director-images/overcloud-full-latest-10.0.tar \
    /usr/share/rhosp-director-images/ironic-python-agent-latest-10.0.tar; \
    do tar -C images -xvf $i; done
openstack overcloud image upload --image-path /home/stack/images/
```

#### Set DNS server.
```
openstack subnet list
openstack subnet set \
    --dns-nameserver <nameserver1-ip> \
    --dns-nameserver <nameserver2-ip> \
    <subnet-uuid>
```


# 4 Build overcloud nodes

## 4.1 Define VM

Run `virt-install` on each controller host to define VM. See script [create-overcloud-vm](rhosp/create-overcloud-vm) and [vm](rhosp/vm).


## 4.2 Import nodes

Import all defined VMs and compute nodes into ironic service.

See script [create-node-json](rhosp/create-node-json) and [node](rhosp/node).


# 5 Install packages

#### Create Contrail local repo with package `contrail-install-packages_4.1.1.0-12-newton_redhat7.tgz`.
```
sudo mkdir /var/www/html/contrail
sudo tar xzf contrail-install-packages_4.1.1.0-12-newton_redhat7.tgz \
    -C /var/www/html/contrail
```

#### Install Puppet modules.
```
sudo yum localinstall -y \
    /var/www/html/contrail/contrail-tripleo-puppet-4.1.1.0-12.el7.noarch.rpm \
    /var/www/html/contrail/puppet-contrail-4.1.1.0-12.el7.noarch.rpm
mkdir -p usr/share/openstack-puppet/modules/contrail  
mkdir -p usr/share/openstack-puppet/modules/tripleo
cp -r /usr/share/openstack-puppet/modules/contrail/* \
    usr/share/openstack-puppet/modules/contrail/
cp -r /usr/share/contrail-tripleo-puppet/* \
    usr/share/openstack-puppet/modules/tripleo/
```

#### Install Heat templates.
```
cp -r /usr/share/openstack-tripleo-heat-templates tripleo-heat-templates
sudo yum localinstall -y \
    /var/www/html/contrail/contrail-tripleo-heat-templates-4.1.1.0-12.el7.noarch.rpm
cp -r /usr/share/contrail-tripleo-heat-templates/environments/contrail \
    tripleo-heat-templates/environments
cp -r /usr/share/contrail-tripleo-heat-templates/puppet/services/network/* \
    tripleo-heat-templates/puppet/services/network
```


# 6 Customize environments

## 6.1 Node placement

Reference: [Controlling Node Placement and IP Assignment](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/node_placement.html)

* Update `contrail-services.yaml`, set flavor to `baremetal` for all roles.
* Set property for each node when creating the node JSON file. See [create-node-json](rhosp/create-node-json).
* Configure the mapping in scheduler-hints.yaml and add it into deploy command.


## 6.2 Neutron address

For instances, Neutron port is created and address is allocated from specified allocation pool. In case of dynamical address, the Neutron address is provided to instance by DHCP.

Update `tripleo-heat-templates/environments/contrail/contrail-net.yaml` to define each network CIDR and allocation pool. This will override the default in `tripleo-heat-templates/network/<network>.yaml`.

* Space 1 - 10 is reserved for bridge on controller hypervisor.
* Space 11 - 200 is the allocation pool for dynamical allocation.
* Space 201 - 250 is reserved for VIP address.

```
external:           10.84.29.0/24
internal-api:       172.16.10.0/24  172.16.10.11 - 172.16.10.200
tenant:             172.16.12.0/24  172.16.12.11 - 172.16.12.200
storage:            172.16.14.0/24  172.16.14.11 - 172.16.14.200
storage-management: 172.16.16.0/24  172.16.16.11 - 172.16.16.200
```


## 6.3 Static address

In case of static address, Neutron port and address won't be allocated, instead, the static address will be configured into instance. Static address is defined in `tripleo-heat-templates/environments/contrail/ips-from-pool-all.yaml`.

Static control plane address is not currently supported. Here is the [blueprint](https://blueprints.launchpad.net/tripleo/+spec/tripleo-predictable-ctlplane-ips).


## 6.4 Redis VIP

Redis VIP can't be the same as the InternalApiVirtualFixedIPs. If it's not specified, it will be allocated from allocation pool. That may cause address collision with static address, in case static address and allocation pool are in the same space. To avoid conflict, two options here, 1) specify it in `ips-from-pool-all.yaml`, 2) isolate static address space and allocation pool. Here is a bug for this. [https://bugzilla.redhat.com/show_bug.cgi?id=1329756](https://bugzilla.redhat.com/show_bug.cgi?id=1329756).


# 7 Deploy overcloud

```
openstack overcloud deploy \
  --templates $templates \
  --roles-file $templates/environments/contrail/roles_data.yaml \
  -e $templates/environments/puppet-pacemaker.yaml \
  -e $templates/environments/contrail/contrail-services.yaml \
  -e $templates/environments/contrail/hostname-map.yaml \
  -e $templates/environments/contrail/scheduler-hints.yaml \
  -e $templates/environments/contrail/network-isolation.yaml \
  -e $templates/environments/contrail/contrail-net.yaml \
  -e $templates/environments/contrail/ips-from-pool-all.yaml \
  -e $templates/extraconfig/pre_deploy/rhel-registration/environment-rhel-registration.yaml \
  -e $templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml
```

# 8 Troubleshoot

List stack failures and details.
```
openstack stack failures list overcloud
```


