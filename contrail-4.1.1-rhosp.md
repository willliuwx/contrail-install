
# 1 Overview

This guide is to build a cluster of RHOSP 10 and Contrail 4.1.1 on 7 physical servers.


# 2 Plan

## 2.1 Physical server

* 3 controller hypervisors for hosting undercloud VM and overcloud controller VMs.
* 4 compute nodes, 2 with kernel based Contrail vrouter and 2 with DPDK based.


## 2.2 VM

The undercloud VM is on the first controller hypervisor.

On each controller hypervisor, there are 4 overcloud controller VMs.
* openstack-controller
* contrail-controller
* contrail-analytics
* contrail-analytics-db

Here is the VM spec for poc/lab purpose. For production, the best practise has to be followed.
```
openstack-controller    48GB   6    120GB
contrail-controller     48GB   6    120GB
contrail-analytics      48GB   6    120GB
contrail-analytics-db   48GB   4    120GB
appformix-controller    32GB   4    120GB
----------------------------------------------------
                       224GB  24   600GB
```
Note, AppFormix controller VM will be built separately.


## 2.3 Network

Network space is determined by deployment size. Given 12 VMs and 4 BMs, the minimum space of each network is 64, prefix length is 26.

* external-api

  This is for accessing the server for management, troubeshoot, web UI, etc.

* provisioning

  This is for supporting PXE boot. Due to some L2 services (DHCP, TFTP, etc.), this network has to be on native untagged VLAN.

* internal-api

  This is for all API traffic.

* tenant

  This is for tunnel, XMPP and BGP traffic. L2 and L3 gateway has to be reachable from this network.

* storage

  This is used by storage service, like Swift, which provides backend to Glance.

* storage-management

  This is used by storage service, like Swift, which provides backend to Glance.

* management

  This is usually not required.


## 2.4 Network configuration

### 2.4.1 Production

For bandwidth isolation in production, on compute node, it's recommended to have separated interfaces (bond is prefered) for internal-api, tenant and storage. All other networks can be on the same interface. Here is an example.

Controller hypervisor
```
br0 on eno1  -> provisiong
vlan10@br0   -> internal-api
vlan20@br0   -> external-api
vlan30@br0   -> storage-management
br1 on bond1 -> tenant
br2 on bond2 -> storage
```

Overcloud VM
```
eth0        -> privisioning
vlan10@eth0 -> internal-api
vlan20@eth0 -> external-api
vlan30@eth0 -> storage-management
eth1        -> tenant
eth2        -> storage
```

Compute node
```
eno1        -> provisiong
vlan10@eno1 -> internal-api
vlan20@eno1 -> external-api
vlan30@eno1 -> storage-management
bond0       -> tenant
bond1       -> storage
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
Copy and update undercloud.conf.
```
cp /usr/share/instack-undercloud/undercloud.conf.sample ~/undercloud.conf
```
```
[DEFAULT]
local_ip = 172.16.0.10/24
network_gateway = 172.16.0.254
undercloud_admin_vip = 172.16.0.251
local_interface = eth1
network_cidr = 172.16.0.0/24
masquerade_network = 172.16.0.0/24
dhcp_start = 172.16.0.20
dhcp_end = 172.16.0.50
inspection_iprange = 172.16.0.100,172.16.0.150
```

#### Install undercloud
```
openstack undercloud install
```
In case that undercloud.conf is updated after undercloud installation, has to rerun installation to apply the updates.


#### Install and upload images.
```
sudo yum install -y rhosp-director-images rhosp-director-images-ipa
for i in \
    /usr/share/rhosp-director-images/overcloud-full-latest-10.0.tar \
    /usr/share/rhosp-director-images/ironic-python-agent-latest-10.0.tar; \
    do tar -C images -xvf $i; done
source stackrc
openstack overcloud image upload --image-path /home/stack/images/
```

#### Set DNS server.

Set DNS server for provisioning network.
```
openstack subnet list
openstack subnet set \
    --dns-nameserver <nameserver1-ip> \
    --dns-nameserver <nameserver2-ip> \
    <subnet-uuid>
```


# 4 Install packages

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


# 5 Build overcloud nodes

## 5.1 Define VM

Run `virt-install` on each controller host to define VM. See script [overcloud-vm](rhosp/overcloud-vm) and [vm](rhosp/vm).

Note, update script to make sure VM interface is on the right bridge.


## 5.2 Import nodes

Import all defined VMs and compute nodes into ironic service.

See script [create-node-json](rhosp/create-node-json) and [node](rhosp/node).

Note, update script to make sure the right bridge is specified to get MAC address, and the private key is correct.


# 6 Customize environments

## 6.1 Node placement

The following roles are defined in `tripleo-heat-templates/environments/contrail/roles_data.yaml`.
```
Controller
Compute
BlockStorage
ObjectStorage
CephStorage
ContrailController
ContrailAnalytics
ContrailAnalyticsDatabase
ContrailTsn
ContrailDpdk
```

When deploy a role, Nova looks for the flavor for that role, which is defined in `tripleo-heat-templates/environments/contrail/contrail-services.yaml`.
```
OvercloudControlFlavor
OvercloudComputeFlavor
OvercloudContrailControllerFlavor
OvercloudContrailAnalyticsFlavor
OvercloudContrailAnalyticsDatabaseFlavor
OvercloudContrailTsnFlavor
OvercloudContrailDpdkFlavor
```

For profile based node placement, a flavor is created for each role, and a profile is tagged to the role and the set of nodes for this role. When deploy a role, Nova gets the flavor, finds the profile tag, matches the set of nodes by profile tag, and selects a node for the role.

For specific node placement, flavor `baremetal` is used for all roles. A `node:<node name>` is tagged on each node. Scheduler hint for each role is defined in `scheduler-hints.yaml`. When deploy a role, Nova takes flavor `baremetal`, checks sceduler hints, gets the exact node by index.

Reference: [Controlling Node Placement and IP Assignment](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/node_placement.html)

* Update `contrail-services.yaml`, set flavor to `baremetal` for all roles.
* Set property for each node when creating the node JSON file. See [create-node-json](rhosp/create-node-json).
* Configure the mapping in scheduler-hints.yaml and add it into deploy command.


## 6.2 Hostname

By default, the hostname (instance name) is `%stackname%-{{role.name.lower()}}-%index%`. Create `HostnameMap` to customize hostname.

Note, script in `install_vrouter_kmod.yaml` checks hostname map to find out the role and assumes compute role is `NovaCompute`. If no hostname map for compute node, the script extracts role name from hostname. Need to fix it.
```
@@ -315,7 +315,7 @@
                 reboot
               fi
             fi
-            if [[ `echo $role |awk -F"-" '{print $2}'` == "novacompute" || `echo $role |awk -F"-" '{print $2}'` == "contrailtsn" ]]; then
+            if [[ `echo $role |awk -F"-" '{print $2}'` == "compute" || `echo $role |awk -F"-" '{print $2}'` == "contrailtsn" ]]; then
               if [[ `echo $role |awk -F"-" '{print $2}'` == "contrailtsn" ]]; then
                 phy_int=${phy_tsn_int}
                 vlan_parent=${vlan_tsn_parent
```


## 6.3 Static address

For instances, Neutron port is created and address is allocated from specified allocation pool. In case of dynamical address, the address is provided to instance by DHCP.

Update `tripleo-heat-templates/environments/contrail/contrail-net.yaml` to define each network CIDR and allocation pool. This will override the default in `tripleo-heat-templates/network/<network>.yaml`.

* Range 1 - 10 is reserved for bridge on controller hypervisor.
* Range 11 - 200 is the allocation pool for dynamical allocation.
* Range 201 - 250 is reserved for VIP address.

```
external:           10.84.29.0/24
internal-api:       172.16.10.0/24  172.16.10.11 - 172.16.10.200
tenant:             172.16.12.0/24  172.16.12.11 - 172.16.12.200
storage:            172.16.14.0/24  172.16.14.11 - 172.16.14.200
storage-management: 172.16.16.0/24  172.16.16.11 - 172.16.16.200
```

In case of static address, Neutron port and address won't be allocated, instead, the static address will be configured into instance. Static address is defined in `tripleo-heat-templates/environments/contrail/ips-from-pool-all.yaml`.

Static control plane address is not currently supported. Here is the [blueprint](https://blueprints.launchpad.net/tripleo/+spec/tripleo-predictable-ctlplane-ips).


## 6.4 Redis VIP

Redis VIP can't be the same as the InternalApiVirtualFixedIPs. If it's not specified, it will be allocated from allocation pool. That may cause address collision with static address, in case static address and allocation pool are in the same space. To avoid conflict, two options here, 1) specify it in `ips-from-pool-all.yaml`, 2) isolate static address space and allocation pool. Here is a bug for this. [https://bugzilla.redhat.com/show_bug.cgi?id=1329756](https://bugzilla.redhat.com/show_bug.cgi?id=1329756).


## 6.5 Separation of API and data networks

For purposes like security or bandwidth reservation, data traffic (tunnel, BGP, XMPP and DNS) needs to be on separated network than API traffic. In this case, data traffic will be moved onto `tenant` network from `internal-api` network.

Update `tripleo-heat-templates/environments/contrail/contrail-services.yaml` to set the followings.
```
parameter_defaults:
  ServiceNetMap:
    ContrailControlNetwork: tenant
    ContrailVrouterNetwork: tenant
    ContrailDpdkNetwork: tenant
```


## 6.6 Build image for DPDK compute node

When deploy DPDK compute node, vrouter packages have to installed before configure interfaces. But, because the system was not registered at that point, vrouter packages can't be installed during deployment. A customized image based on `overcloud-full.qcow2` with pre-installed vrouter packages is required for DPDK compute node deployment.

#### Copy `overcloud-full.qcow2` to one of controller hypervisors.
```
scp ~/images/overcloud-full.qcow2 root@<hyperviosr>:/var/tmp
```

#### Create `/var/tmp/contrail.repo` on the hypervisor.
```
[Contrail]
name=Contrail Repo
baseurl=http://<undercloud>/contrail
enabled=1
gpgcheck=0
protect=1
metadata_expire=30
```
The undercloud address has to be reachable from the hypervisor.

#### Create `/var/tmp/customize` on the hypervisor.
```
#!/bin/bash

virt-customize \
  -a /var/tmp/overcloud-full-dpdk.qcow2 \
  --sm-credentials $username:password:$password \
  --sm-register \
  --sm-attach auto \
  --run-command 'subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-for-rhel-7-server-rpms --enable=rhel-7-server-openstack-10-rpms --enable=rhel-7-server-openstack-10-devtools-rpms' \
  --upload /var/tmp/contrail.repo:/etc/yum.repos.d \
  --run-command 'yum install -y contrail-vrouter-utils contrail-vrouter-dpdk contrail-vrouter-dpdk-init' \
  --run-command 'rm -fr /var/cache/yum/*' \
  --run-command 'yum clean all' \
  --run-command 'rm -rf /etc/yum.repos.d/contrail.repo' \
  --run-command 'subscription-manager unregister' \
  --selinux-relabel
```

#### Enable execution bit and run it.
```
cd /tmp/customize
chmod +x customize
./customize
```

#### Copy DPDK image back to undercloud.
```
scp root@<hypervisor>:/var/tmp/overcloud-full-dpdk.qcow2 ~/images/
```

#### Add DPDK image to Glance.
```
openstack image create \
  overcloud-full-dpdk \
  --container-format bare \
  --disk-format qcow2 \
  --file /home/stack/images/overcloud-full-dpdk.qcow2

kid=$(openstack image list | awk "/bm-deploy-kernel/"'{print $2}'); \
rid=$(openstack image list | awk "/bm-deploy-ramdisk/"'{print $2}'); \
openstack image set \
  overcloud-full-dpdk \
  --property kernel_id=$kid \
  --property ramdisk_id=$rid
```

#### Update `contrail-services.yaml` to specify the image for DPDK role.
```
  ContrailDpdkImage: overcloud-full-dpdk
```


## 6.7 Disable connectivity check for DPDK

For some reason, `vrouter-dpdk` fails when it was started by the script in `install_vrouter_kmod.yaml`. The error is "PMD: ixgbe_alloc_rx_queue_mbufs(): RX mbuf alloc failed queue_id=2". Restarting `vrouter-dpdk` afterwards will bring it up to work. This issue will cause connectivity check fail. To work around it, need to update `tripleo-heat-templates/environments/contrail/contrail-services.yaml` to disable connectivity check.
```
  OS::TripleO::AllNodes::Validation: ../../ci/common/all-nodes-validation-disabled.yaml
```
This will complete deployment successfully. After that, need to `systemctl restart supervisor-vrouter` on each DPDK compute node.


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

After initial deployment, some services may report alarms, like vrouter interface down, contrail-named failure, vrouter node down, etc. Restarting according service will bring it to good state.


# 8 Troubleshoot

List stack failures and details.
```
openstack stack failures list overcloud
```


