
# 1 Overview

This guide is to build integration of RHOSP 13 (OpenStack Queens) and Contrail 5.0.1.


# 2 Plan

## 2.1 Physical server

* 3 controller hypervisors for hosting undercloud VM and overcloud controller VMs.
* 4 compute nodes, 2 with kernel based Contrail vrouter and 2 with DPDK based.


## 2.2 VM

The undercloud VM is on the first controller hypervisor.

On each controller hypervisor, there are 2 overcloud controller VMs.
* openstack-controller
* contrail-controller

Here is the VM spec for poc/lab purpose. For production, the best practise has to be followed.
```
openstack-controller    64GB   8    150GB
contrail-controller     64GB   8    300GB
appformix-controller    32GB   4    150GB
----------------------------------------------------
                       160GB  20   600GB
```
Note, AppFormix controller VM will be built separately.


## 2.3 Network

Here is the list of all networks.

* external

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

Network space is determined by deployment size.
* 3 bridge addresses, one on the bridge of each controller hypervisor. Bridge doesn't require an address to function. This is for the convience to test underlay connectivity.
* n overcloud node (both VM controller and physical compute) addresses, used by Ironic for inspection.
* n overcloud node addresses, used as static address.
* 3 addresses for AppFormix.
* network address and broadcast address.

In case of 6 VMs and 4 compute nodes, the minimum space of each network is 32, prefix length is 27. In this guide, prefix length 24 is used.


## 2.4 Network configuration

### 2.4.1 Production

For bandwidth isolation in production, on compute node, it's recommended to have separated interfaces (bond is prefered) for internal-api, tenant and storage. All other networks can be on the same interface. Here is an example.

Controller hypervisor
```
br0 on eno1   -> provisiong
vlan10@br0    -> internal-api
vlan20@br0    -> external
vlan30@br0    -> storage-management
br1 on ens2f0 -> tenant
br2 on ens2f1 -> storage
```

Overcloud VM
```
eth0        -> privisioning
vlan10@eth0 -> internal-api
vlan20@eth0 -> external
vlan30@eth0 -> storage-management
eth1        -> tenant
eth2        -> storage
```

Compute node
```
eno1        -> provisiong
vlan10@eno1 -> internal-api
vlan20@eno1 -> external
vlan30@eno1 -> storage-management
bond0       -> tenant
bond1       -> storage
```


### 2.4.2 PoC/Lab

As the mininum requirement, one interface will work. Normally, for PoC/Lab deployment, it would be good to have 2 interfaces. Each interface can be either physical NIC or bond interface. Here is an example.

Controller hypervisor
```
br0 on eno1   -> provisiong
vlan10@br0    -> internal-api
vlan20@br0    -> tenant
vlan30@br0    -> storage
vlan40@br0    -> storage-management
br1 on ens2f0 -> external
```

Overcloud VM
```
eth0        -> privisioning
vlan10@eth0 -> internal-api
vlan20@eth0 -> tenant
vlan30@eth0 -> storage
vlan40@eth0 -> storage-management
eth1        -> external
```
`eth0` and `eth1` are on bridge `br0` and `br1` respectively.

Compute node
```
eno1          -> external
ens2f0        -> provisioning
vlan10@ens2f0 -> internal-api
vlan20@ens2f0 -> tenant (vhost0)
vlan30@ens2f0 -> storage
vlan40@ens2f0 -> storage-management
```

Undercloud VM
```
eth0 -> privisioning
eth1 -> external
```
`eth0` and `eth1` are on bridge `br0` and `br1` respectively.


# 3 Build undercloud

#### Create undercloud VM on the hypervisor.
The VM is based on RHEL cloud image rhel-server-7.5-x86_64-kvm.qcow2.

#### Prepare for undercloud installation.
```
useradd stack
passwd stack
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
su - stack
mkdir images
mkdir templates
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
    --enable=rhel-7-server-openstack-13-rpms
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

Here is an example where the provisioning network is 172.16.0.0/24.
```
[DEFAULT]
local_ip = 172.16.0.8/24
undercloud_nameservers = 10.84.5.101
undercloud_ntp_servers = 10.84.5.100
subnets = ctlplane-subnet
local_subnet = ctlplane-subnet
local_interface = eth0

[ctlplane-subnet]
cidr = 172.16.0.0/24
dhcp_start = 172.16.0.50
dhcp_end = 172.16.0.99
inspection_iprange = 172.16.0.100,172.16.0.149
gateway = 172.16.0.254
```

#### Install undercloud
```
openstack undercloud install
exec su -l stack
source stackrc
```
In case that undercloud.conf is updated after undercloud installation, has to rerun installation to apply the updates.


#### Install and upload images.
```
sudo yum install -y rhosp-director-images rhosp-director-images-ipa
for i in \
    /usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar \
    /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar; \
    do tar -C images -xvf $i; done
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

Reference: [INSTALLING THE UNDERCLOUD](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html/director_installation_and_usage/installing-the-undercloud)


# 4 Install heat templates and build registry

#### Install Heat templates.
Download "RHEL 7 OOO Heat Templates" from [Juniper download site](https://www.juniper.net/support/downloads/?p=contrail#sw) for version 5.0.1.
```
cp -r /usr/share/openstack-tripleo-heat-templates tripleo-heat-templates
tar xzf contrail-tripleo-heat-templates-5.0.1-0.214.tgz
cp -r contrail-tripleo-heat-templates/* tripleo-heat-templates/
```

#### Start insecure private registry.
```
docker pull registry
docker run -d --env REGISTRY_HTTP_ADDR=0.0.0.0:5100 \
    --restart always --net host --name registry registry
```

#### Upload OpenStack container images.
```
openstack overcloud container image prepare \
  --namespace registry.access.redhat.com/rhosp13 \
  --push-destination 172.16.0.8:5100 \
  --prefix openstack- \
  --tag-from-label {version}-{release} \
  --output-env-file /home/stack/tripleo-heat-templates/overcloud_images.yaml \
  --output-images-file /home/stack/openstack_images.yaml

openstack overcloud container image upload \
  --config-file  /home/stack/openstack_images.yaml \
  --verbose
```
#### Note
`push-destination` is the registry address used by overcloud node to pull image.

Reference: [iCONFIGURING A CONTAINER IMAGE SOURCE](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html/director_installation_and_usage/configuring-a-container-image-source)

#### Upload Contrail container images.
Patch `tripleo-heat-templates/tools/contrail/import_contrail_container.sh` with the correct private registry.
```
@@ -156,12 +156,12 @@
   thtImageName=`echo ${line} |awk -F":" '{print $1}'`
   contrailImageName=`echo ${line} |awk -F":" '{print $2}'`
   echo "- imagename: ${registry}/${contrailImageName}:${tag}" >> ${output_file}
-  echo "  push_destination: 192.168.24.1:8787" >> ${output_file}
+  echo "  push_destination: localhost:5100" >> ${output_file}
 done
 
 #redis special
 echo "- imagename: docker.io/redis" >> ${output_file}
-echo "  push_destination: 192.168.24.1:8787" >> ${output_file}
+echo "  push_destination: localhost:5100" >> ${output_file}
 
 echo "Written ${output_file}"
 echo "Upload with:"
```

Pull container images from hub.juniper.net and push them to private registry.
```
tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
  -f /home/stack/contrail_images.yaml \
  -r hub.juniper.net/contrail \
  -t 5.0.1-0.214-rhel-queens \
  -u <username> \
  -p <password>

openstack overcloud container image upload \
  --config-file /home/stack/contrail_images.yaml \
  --verbose
```


# 5 Build overcloud nodes

## 5.1 Define VM

Run `virt-install` on each controller host to define VM. See script [overcloud-vm](rhosp/rhosp13/overcloud-vm) and [vm](rhosp/rhosp13/vm).

#### Note
Update script to make sure VM interface is on the right bridge.

#### Note
Ironic uses IPMI for both virtual and physical machines. VirtualBMC is required on controller hypervisor to simulate IPMI.


## 5.2 Import nodes

Import all defined VMs and compute nodes into ironic service.

See script [cluster](rhosp/rhosp13/cluster).

#### Note
Update script to make sure the right bridge is specified to get MAC address.


# 6 Customize environments

## 6.1 Node placement

Reference [CONTROLLING NODE PLACEMENT](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html/advanced_overcloud_customization/sect-controlling_node_placement)

The following roles are defined in `tripleo-heat-templates/roles_data_contrail_aio.yaml`.
```
Controller
Compute
ContrailController
ContrailControlOnly
ContrailTsn
ContrailDpdk
ContrailSriov
```

When deploy a role, Nova looks for the flavor for that role, which is defined in `tripleo-heat-templates/environments/contrail/contrail-services.yaml`.
```
OvercloudControllerFlavor
OvercloudContrailControllerFlavor
OvercloudContrailControlOnlyFlavor
OvercloudComputeFlavor
OvercloudContrailDpdkFlavor
OvercloudContrailSriovFlavor
```

For profile based node placement, a flavor is created for each role, and a profile is tagged to the role and the set of nodes for this role. When deploy a role, Nova gets the flavor, finds the profile tag, matches the set of nodes by profile tag, and selects a node for the role.

For specific node placement, flavor `baremetal` is used for all roles. A `node:<node name>` is tagged on each node. Scheduler hint for each role is defined in `scheduler-hints.yaml`. When deploy a role, Nova takes flavor `baremetal`, checks sceduler hints, gets the exact node by index.

* Update `contrail-services.yaml`, set flavor to `baremetal` for all roles.
* Set property for each node when creating the node JSON file. See [create-node-json](rhosp/create-node-json).
* Configure the mapping in scheduler-hints.yaml and add it into deploy command.


## 6.2 Hostname

By default, the hostname (instance name) is `%stackname%-{{role.name.lower()}}-%index%`. Create `tripleo-heat-templates/environments/contrail/hostname-map.yaml` to customize hostname. Add it into deploy command.


## 6.3 Static address

For each instance, Neutron port is created and address is allocated from specified allocation pool. In case of dynamical address, the address is provided to instance by DHCP.

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


## 6.5 contrail-services.yaml

Update `tripleo-heat-templates/environments/contrail/contrail-services.yaml` to set the followings.

#### Separation of API and data networks

For purposes like security or bandwidth reservation, data traffic (tunnel, BGP, XMPP and DNS) needs to be on separated network than API traffic. In this case, data traffic will be moved onto `tenant` network from `internal-api` network.

```
parameter_defaults:
  ServiceNetMap:
    ContrailControlNetwork: tenant
    ContrailVrouterNetwork: tenant
```

#### Role count
```
  ControllerCount: 3
  ContrailControllerCount: 3
  ContrailControlOnlyCount: 0
  ComputeCount: 1
  ContrailDpdkCount: 1
  ContrailSriovCount: 0
```

#### Registry

#### Vrouter, DPDK and SRIOV


## 6.6 contrail-net.yaml

Update `tripleo-heat-templates/environments/contrail/contrail-net.yaml` to set networking.

## 6.7 NIC configuration

Update `tripleo-heat-templates/network/config/contrail/*-nic-config.yaml` for NIC configuration on each role.


# 7 Deploy overcloud

```
templates=/home/stack/tripleo-heat-templates

openstack overcloud deploy \
  --templates $templates \
  -e $templates/overcloud_images.yaml \
  -e $templates/environments/network-isolation.yaml \
  -e $templates/environments/contrail/contrail-plugins.yaml \
  -e $templates/environments/contrail/contrail-services.yaml \
  -e $templates/environments/contrail/contrail-net.yaml \
  -e $templates/environments/contrail/scheduler-hints.yaml \
  -e $templates/environments/contrail/hostname-map.yaml \
  -e $templates/environments/contrail/ips-from-pool-all.yaml \
  --roles-file $templates/roles_data_contrail_aio.yaml
```

To redeploy the overcloud after templates update,
```
openstack stack delete overcloud
```
wait till the stack is deleted, then run `openstack deploy` command.

After initial deployment, some services may report alarms, like vrouter interface down, contrail-named failure, vrouter node down, etc. Restarting according service will bring it to good state.


# 8 Troubleshoot

List stack failures and details.
```
openstack stack failures list overcloud
```


