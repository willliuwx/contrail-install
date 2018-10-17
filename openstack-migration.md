
# 1 Overview

Existing OpenStack Ocata (not deployed by Kolla) on CentOS 7.5 with tenant workload, like virturl networks and VMs. Networking backend is OVS.

Install Contrail 5.0.1 to replace OVS and migrate all workloads.

VM has to be stopped and restarted after migration.


# 2 Workflow

* Save networking configurations.
* Stop VM.
* Install Contrail controller.
* Install Neutron Contrail plugin.
* Remove OVS.
* Install Contrail vrouter.
* Install vrouter VIF driver.
* Rebuild networking configurations.
* Start VM.


## 2.1 Save networking configurations

Save network, subnet and port.


## 2.2 Stop VMs.

Stop VM.
```
openstack server stop vm1-red
```

It invokes libvirt to `destroy` the instance. Tap interface is removed, but still plugged (VIF unplug was not invoked.).

Detach all interfaces.
```
nova interface-list vm1-red
nova interface-detach vm1-red <port ID)
```


## 2.3 Install Contrail controller

Run playbook to configure hosts and install Contrail.
```
cd contrail-ansible-deployer; \
  ansible-playbook -i inventory -e orchestrator=openstack \
  playbooks/configure_instances.yml

cd contrail-ansible-deployer; \
  ansible-playbook -i inventory/ -e orchestrator=openstack \
  playbooks/install_contrail.yml
```

Here is an example of instances.yaml.
```
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    ntpserver: 10.84.5.100
    domainsuffix: local
instances:
  contrail:
    provider: bms
    ip: 10.87.68.168
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
global_configuration:
  CONTAINER_REGISTRY: ci-repo.englab.juniper.net:5010
  REGISTRY_PRIVATE_INSECURE: True
contrail_configuration:
  CONTRAIL_CONTAINER_TAG: ocata-5.0-278
  CLOUD_ORCHESTRATOR: openstack
  CONFIG_DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: 20
  DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: 20
  WEBUI_INSECURE_ACCESS: true
kolla_config:
  kolla_globals:
    kolla_internal_vip_address: 10.87.68.166
  kolla_passwords:
    keystone_admin_password: aa0928d857884e92
```


## 2.4 Install Neutron Contrail plugin

On Contrail controller, pull `contrail-openstack-neutron-init` image.
```
docker pull ci-repo.englab.juniper.net:5010/contrail-openstack-neutron-init:ocata-5.0-278
```

Get image ID.
```
docker images | grep neutron-init
```

Make a directory.
```
mkdir /root/neutron-plugin
```

Run `contrail-openstack-neutron-init`.
```
docker run -v /root/neutron-plugin:/opt/plugin/site-packages <image ID>
```

Pack packages and copy to OpenStack controller.
```
tar -czf neutron-plugin.tgz neutron-plugin
scp neutron-plugin.tgz 10.87.68.166:.
```

On OpenStack controller, unpack the packages.
```
tar -xzf neutron-plugin.tgz
cp -r neutron-plugin/* /usr/lib/python2.7/site-packages/
rm -fr neutron-plugin
rm -f neutron-plugin.tgz
```

Update the following settings in `/etc/neutron/neutron.conf`.
```
[DEFAULT]
core_plugin = neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2
service_plugins = neutron_plugin_contrail.plugins.opencontrail.loadbalancer.v2.plugin.LoadBalancerPluginV2
api_extensions_path = /usr/lib/python2.7/site-packages/neutron_plugin_contrail/extensions:/usr/lib/python2.7/site-packages/neutron_lbaas/extensions

[quotas]
quota_network = -1
quota_subnet = -1
quota_port = -1
quota_driver = neutron_plugin_contrail.plugins.opencontrail.quota.driver.QuotaDriver
```

Create directory for plugin configuration file.
```
mkdir /etc/neutron/plugins/opencontrail
```

Create file `/etc/neutron/plugins/opencontrail/ContrailPlugin.ini`.
```
[APISERVER]
api_server_ip = 10.87.68.168
api_server_port = 8082
multi_tenancy = True
contrail_extensions = ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None

[COLLECTOR]
analytics_api_ip = 10.87.68.168
analytics_api_port = 8081

[keystone_authtoken]
auth_host = 10.87.68.166
auth_port = 5000
auth_protocol = http
admin_user = admin
admin_password = aa0928d857884e92
admin_tenant_name = admin
insecure = True
region_name = RegionOne
```

Update `/usr/lib/systemd/system/neutron-server.service` to replace `--config-file /etc/neutron/plugin.ini` by `--config-file /etc/neutron/plugins/opencontrail/ContrailPlugin.ini`, and reload service configuration.
```
systemctl daemon-reload
```

Restart Neutron server and check the status.
```
systemctl restart neutron-server
systemctl status neutron-server
```

Now, Contrail is the backend of Neutron.
```
# openstack network list          
+--------------------------------------+-------------------------+---------+
| ID                                   | Name                    | Subnets |
+--------------------------------------+-------------------------+---------+
| 0b7c5598-f180-4d8a-99df-cf273b5c5276 | __link_local__          |         |
| 11ce20b5-f178-416a-8f93-97d30d916e44 | default-virtual-network |         |
| aa3283b3-2955-41e7-a1d4-3db101abbaeb | ip-fabric               |         |
+--------------------------------------+-------------------------+---------+
```

## 2.5 Remove OVS.

Stop and disable OVS service on compute node.
```
systemctl stop openvswitch
systemctl disable openvswitch
```

List OVS datapath and delete it.
```
ovs-dpctl dump-dps
ovs-dpctl del-dp <datapath>
```

Remove OVS kernel module.
```
rmmod openvswitch
```

List and delete all OVS interfaces.
```
ip link | grep qbr
ip link | grep qvo
ip link delete <interface>
```

Remove OVS package.
```
yum erase openvswitch
```


## 2.6 Install Contrail vrouter.

Add compute nodes to `instances.yaml` and comment out controllers.
```
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    ntpserver: 10.84.5.100
    domainsuffix: local
instances:
#  contrail:
#    provider: bms
#    ip: 10.87.68.168
#    roles:
#      config_database:
#      config:
#      control:
#      analytics_database:
#      analytics:
#      webui:
  compute:
    provider: bms
    ip: 10.87.68.167
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: ci-repo.englab.juniper.net:5010
  REGISTRY_PRIVATE_INSECURE: True
contrail_configuration:
  CONTRAIL_CONTAINER_TAG: ocata-5.0-278
  CLOUD_ORCHESTRATOR: openstack
  VROUTER_GATEWAY: 10.87.68.254
  CONFIG_DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: 20
  DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: 20
  WEBUI_INSECURE_ACCESS: true
kolla_config:
  kolla_globals:
    kolla_internal_vip_address: 10.6.11.1
  kolla_passwords:
    keystone_admin_password: aa0928d857884e92
```

Run playbook `configure_instances.yml`.
```
ansible-playbook -i inventory -e orchestrator=openstack \
  playbooks/configure_instances.yml
```

Enable controllers in `instances.yaml`.

Run install_contrail.yml with tag `vrouter`.
```
ansible-playbook -i inventory -e orchestrator=openstack -t vrouter \
  playbooks/install_contrail.yml
```

After playbook is completed successfully, vrouter is installed on the compute node.


## 2.7 Install vrouter VIF driver

On Contrail controller, pull `contrail-openstack-compute-init` image.
```
docker pull ci-repo.englab.juniper.net:5010/contrail-openstack-compute-init:ocata-5.0-278
```

Get image ID.
```
docker images | grep compute-init
```

Make a directory.
```
mkdir /root/compute-plugin
```

Run `contrail-openstack-compute-init`.
```
docker run -v /root/compute-plugin:/opt/plugin <image ID>
```

Pack packages and copy to compute node.
```
tar -czf compute-plugin.tgz compute-plugin
scp compute-plugin.tgz 10.87.68.167:.
```

On compute node, unpack the packages.
```
tar -xzf compute-plugin.tgz
cp -r compute-plugin/site-packages/* /usr/lib/python2.7/site-packages/
cp compute-plugin/bin/vrouter-port-control /usr/bin/

rm -fr compute-plugin
rm -f compute-plugin.tgz
```


## 2.8 Rebuild networking configurations

Create network and subnet with the same settings.


## 2.9 Start VM

Create port with the same IP and MAC.
```
openstack port create \
  --network bc45fd03-bba1-4014-93d5-4ceea7c34af6 \
  --fixed-ip subnet=a337a076-e081-4195-ac4e-4c5da488b416,ip-address=192.168.10.7 \
  --mac-address fa:16:3e:53:6a:52 \
  --project 1b9f2b5d0eb44e9ea7be48e81ee033fb \
  port
```

Attach port to VM.
```
nova interface attach vm1-red --port-id <port ID>
```

Start VM.
```
openstack server start vm1-red
```

It does hard-reboot, rebuilds network, rebuilds libvirt instance definition, invokes VIF driver who creates tap interface and plug it into vrouter.



