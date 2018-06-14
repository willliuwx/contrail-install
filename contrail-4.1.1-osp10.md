
# 1 Overview

This guide is to build a cluster of RHOSP 10 and Contrail 4.1.1 on 7 physical servers.


# 2 Plan

## 2.1 Physical server

* 3 controller hosts for hosting undercloud VM and overcloud controller VMs.
* 4 compute nodes, 2 with kernel based Contrail vrouter and 2 with DPDP based.


## 2.2 VM

The undercloud VM is on the first host controller.

On each controller host, there are 4 overcloud controller VMs.
* openstack-controller
* contrail-controller
* contrail-analytics
* contrail-analytics-database

VM spec. This is for poc/lab purpose. For production, have to follow the best practise.
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

* IPMI, management, external-api
* provisioning
* internal-api
* tenant
* storage
* storage-management


## 2.4 Network configuration

### 2.4.1 Controller host

Each controller host has 2 interfaces connecting to underlay network. The interface can be single NIC or bond interface.
```
br1 on eno1  -> provisiong
br1.10       -> management
br1.20       -> external-api
br2 on bond0 -> internal-api
br2.30       -> tenant
br2.40       -> storage
br2.50       -> storage-management
```

### 2.4.2 Compute node

Each compute node has 2 interfaces connecting to underlay network. The interface can be single NIC or bond interface.
```
eno1     -> provisiong
eno1.10  -> management
eno1.20  -> external-api
bond0    -> internal-api
bond0.30 -> tenant (vhost0)
bond0.40 -> storage
bond0.50 -> storage-management
```

### 2.4.3 Undercloud VM

The undercloud VM has one NIC on `br1`.
```
eth0    -> privisioning
eth0.10 -> management
```

### 2.4.4 Overcloud VM

The overcloud VM has two NICs on `br1` and `br2`.
```
eth0    -> privisioning
eth0.10 -> management
eth0.20 -> external-api
eth1    -> internal-api
eth1.30 -> tenant
eth1.40 -> storage
eth1.50 -> storage-management
```

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

#### Upload Puppet modules to Swift.
```
tar czf puppet-modules.tgz usr
upload-swift-artifacts -f puppet-modules.tgz
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


# 6 Update environments



# 7 Deploy overcloud

```
openstack overcloud deploy \
  --templates tripleo-heat-templates \
  --roles-file tripleo-heat-templates/environments/contrail/roles_data.yaml \
  -e tripleo-heat-templates/environments/puppet-pacemaker.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  -e tripleo-heat-templates/environments/contrail/network-isolation.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-net.yaml \
  -e tripleo-heat-templates/environments/contrail/ips-from-pool-all.yaml \
  -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/environment-rhel-registration.yaml \
  -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml
```


