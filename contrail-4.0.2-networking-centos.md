
* 1 Overview
* 2 Builder
* 3 No Orchestration
* 4 OpenStack
* 5 Kubernetes
* 6 vCenter Only


# 1 Overview

This guide is for integrating Contrail networking with existing orchestration on CentOS host.

## 1.1 CentOS

Both CentOS 7.2 and CentOS 7.3 are supported.

For controller, CentOS 7.2/7.3 with original kernel is good.

For vrouter/Compute node, CentOS 7.2 kernel (3.10.0-327.el7.x86_64) has to be upgraded. In this guide, the kernel is upgraded to 3.10.0-514.21.1.el7. CentOS 7.3 doesn't need upgrade. Package kernel-devel and kernel-headers have to be installed on either CentOS release for building vrouter kernel module.

Upgrade kernel for CentOS 7.2.
```
yum install kernel-3.10.0-514.21.1.el7
reboot
```

Install kernel package for CentOS 7.2/7.3.
```
yum install \
    kernel-devel-3.10.0-514.21.1.el7 \
    kernel-headers-3.10.0-514.21.1.el7
```

#### Note
The current latest kernel is 3.10.0-693.5.2.el7. Compiling vrouter kernel module doesn't work with this version. It complains the missing declaration of __ethtool_get_settings() in /usr/src/kernels/<version>/include/linux/ethtool.h. It's caused by this patch (https://patchwork.ozlabs.org/patch/554762/). In the future, vrouter has to be fixed to work with newer kernel.


## 1.2 Contrail

Contrail 4.0.2.0-35 with Ubuntu 14.04 based contailer is used in this guide.

Contrail Packages
```
contrail-server-manager-installer_4.0.2.0-35~mitaka_all.deb
    registry.tar.gz
contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz
contrail-networking-docker_4.0.2.0-35_trusty.tgz
    contrail-networking-thirdparty_4.0.2.0-35.tgz
    contrail-networking-tools_4.0.2.0-35.tgz
        contrail-ansible-4.0.2.0-35.tar.gz
        contrail-docker-tools_4.0.2.0-35_all.deb
    contrail-networking-dependents_4.0.2.0-35.tgz
    contrail-docker-images_4.0.2.0-35.tgz
        contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-lb-ubuntu14.04-4.0.2.0-35.tar.gz
    contrail-networking-openstack-extra_4.0.2.0-35.tgz
    contrail-neutron-plugin-packages_4.0.2.0-35.tgz
    contrail-vrouter-packages_4.0.2.0-35.tgz
contrail-kubernetes-docker_4.0.2.0-35_trusty.tgz
    contrail-networking-thirdparty_4.0.2.0-35.tgz
    contrail-networking-tools_4.0.2.0-35.tgz
    contrail-kubernetes-dependents_4.0.2.0-35.tgz
    contrail-kubernetes-docker-images_4.0.2.0-35.tgz
        contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-kube-manager-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-kubernetes-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-lb-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-vcenter-docker_4.0.2.0-35_trusty.tgz
    contrail-networking-thirdparty_4.0.2.0-35.tgz
    contrail-networking-tools_4.0.2.0-35.tgz
    contrail-vcenter-dependents_4.0.2.0-35.tgz
    contrail-vcenter-docker-images_4.0.2.0-35.tgz
        contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-lb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-vcenter-plugin-ubuntu14.04-4.0.2.0-35.tar.gz
    contrail-vcenter-vrouter-packages_4.0.2.0-35.tgz
```

#### Note
On exiting compute node where nova-compute in container and Docker 1.12.5 are installed, when tried with Contrail vrouter agent in Ubuntu 16.04 based container, it doesn't seem working well with Docker 1.12.5 on CentOS 7.2 with kernel 3.10.0-514.21.1.el7. Vrouter agent was not configured by internal playbook, so it failed to start and caused container keep restarting. When looking into this issue, CentOS crash was observed. It may be caused by such combination. When tried with upgrading to Docker CE 17.09.0-ce, nova-controller can't schedule task on the compute node. Not sure about the root cause. Hence Ubuntu 14.04 based container is used.

#### Note
On Contrail controller node, Ubuntu 14.04 based containers don't start with Docker CE or Docker Engine 1.13.1 (tested with docker-engine-1.13.1.cs1-1.el7.centos.x86_64 and cs8). They work fine with 1.12.6.cs13-1.el7.centos.x86_64. Ubuntu 16.04 based containers work fine with Docker CE 17.09.0.ce.1.el7.centos.

#### Note
In case upgrade or downgrade Docker, existing Docker has to be erased and /var/lib/docker has to be removed. Otherwise, leftovers in /var/lib/docker (probably metadata) will cause issues.


## 1.3 Load Balance

LB to Contrail is not required by Contrail services. It's required by whoever needs to access Contrail service (API). Hence LB is not part of Contrail production solution.

* Integration with OpenStack, OpenStack LB will be updated to access Contrail configuration and analytics API. Internally, the LB is used by Neutron Contrail plugin.

* Integration with Kubernetes, Contrail CNI connects to local vrouter agent to get required configuration to plugin container. So LB is not required.

* Integration with vCenter (vcenter-only), LB is not required.


# 2 Builder

The builder holds container image registry and run Ansible playbook to deploy Contrail. It's recommended to use Server Manager for deployment. With Contrail 4.0.2, CentOS is not supported to install Server Manager. The builder has to be manually built.

Disable firewall.
```
systemctl stop firewalld
systemctl disable firewalld
```


## 2.1 Private Repository

This repository is local repo for the builder. In case the environment doesn't have public access, this repo contains all required packages to setup the builder. It's private repo for all other nodes.

Copy repo files.
```
mkdir -p /opt/private-repo
cd opt
tar xzf /path/to/private-repo.tgz
```

Create /etc/yum.repos.d/private.repo for the local repo.
```
[private]
name=private
baseurl=file:///opt/private-repo
enabled=1
gpgcheck=0
priority=99
```

Install httpd.
```
yum install httpd
systemctl enable httpd
systemctl start httpd
```

Link to private repo.
```
ln -sf /opt/private-repo /var/www/html/private-repo
```

In case any additional packages are required to serve the deployment, copy them into /opt/private-repo directory and re-create the repo.
```
createrepo /opt/private-repo
```


## 2.2 Ansible

Install Ansible.
```
yum install epel-release
yum install ansible
```

Anisble version.
```
ansible 2.4.0.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/root/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.5 (default, Nov 20 2015, 02:00:19) [GCC 4.8.5 20150623 (Red Hat 4.8.5-4)]
```


## 2.3 Docker

Docker on the builder is for creating registry container to hold all Contrail containers. The builder doesn't have dependency to specific Docker version.

Docker engine ends on release 1.13.1 (2017-02-08). For later Docker release, it's CE or EE. Installing Docker Engine will result in the installation of Docker CE.
```
yum install yum-utils
yum-config-manager --add-repo \
    https://packages.docker.com/1.13/yum/repo/main/centos/7
yum install docker-engine
Package docker-engine is obsoleted by docker-ce, trying to install docker-ce-17.09.0.ce-1.el7.centos.x86_64 instead
```

Install Docker CE.
```
yum install yum-utils lvm2
yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce
systemctl enable docker
systemctl start docker
```

Docker version.
```
Client:
 Version:      17.09.0-ce
 API version:  1.32
 Go version:   go1.8.3
 Git commit:   afdb6d4
 Built:        Tue Sep 26 22:41:23 2017
 OS/Arch:      linux/amd64

Server:
 Version:      17.09.0-ce
 API version:  1.32 (minimum version 1.12)
 Go version:   go1.8.3
 Git commit:   afdb6d4
 Built:        Tue Sep 26 22:42:49 2017
 OS/Arch:      linux/amd64
 Experimental: false
```

Check Backing Filesystem and Cgroup Driver in Docker system info.
```
docker system info
```


## 2.4 Private Docker Registry

Load registry image.
```
docker load < registry.tar.gz
```

Start registry container.
```
docker run -d --env REGISTRY_HTTP_ADDR=0.0.0.0:5100 \
    --restart always --net host --name registry registry:2
```

Push images to registry.

Images to integrate with OpenStack.
```
contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz
```

Images to integrate with Kubernetes.
```
contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz
contrail-kube-manager-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-kubernetes-agent-ubuntu14.04-4.0.2.0-35.tar.gz
```

Images to integrate with vCenter.
```
contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
contrail-vcenter-plugin-ubuntu14.04-4.0.2.0-35.tar.gz
```

List images in registry.
```
curl -s http://localhost:5100/v2/_catalog | python -m json.tool
```

Show image tag in registry.
```
curl -s http://localhost:5100/v2/<image name>/tags/list | python -m json.tool
```


## 2.5 Playbook

```
mkdir ansible
cd ansible
tar xzf /path/to/contrail-ansible-4.0.2.0-35.tar.gz
```


## 2.6 SSH Key

Create SSH key or use existing key. Add public key to /root/.ssh/authorized_keys on all nodes.


# 3 No Orchestration

This section is to install Contrail networking only, no integration with any orchestrations.



# 4 OpenStack

This section is to integrate Contrail with existing OpenStack.


## 4.1 Contrail Node

### 4.1.1 Controller Node

Three containers will be deployed on each controller node. They can be deployed on the existing OpenStack controller, or on separated node.
* controller
* analytics
* analyticsdb


## 4.1.2 Compute/Vrouter Node

On each compute node, OVS kernel module and all related services have to be removed. The data network interface can't be on any bridge. It can be bonding interface, physical interface or logical/VLAN interface.

Playbook will deploy vrouter-agent in container and vrouter kernel module on each compute node.


## 4.2 Inventory

Build inventory file [openstack.ini](#b-1-openstack-single-interface).


## 4.3 Pre-Deployment

### 4.3.1 Prepare Controller Node

Do the followings to get controller node ready for deployment.
* Enable private repository.
* Install Docker 1.12.6.
* Add insecure-registries.
* Install and configure NTP.
* Due to a binding of /etc/timezone between Ubuntu based container (file) and CentOS based Host (directory), fix the mismatch.

Run playbook [controller-pre-deploy.yml](#c-1-controller-pre-deploy-yml).
```
ansible-playbook -i inventory/openstack controller-pre-deploy.yml
```


### 4.3.2 Prepare Compute Node

The existing compute node has services deployed in Kolla containers on CentOS 7.2 host. Docker version is 1.12.5.

Do the followings to get compute node ready for deployment.
* Enable private repository.
* Upgrade kernel to kernel-3.10.0-514.21.1.el7.
* Install kernel-devel and kernel-headers.
* Upgrade python-docker-py.
* Install and configure NTP.
* Install vrouter-port-control.
* Fix /etc/timezone for Ubuntu based container.
* Add insecure-registries.
* Remove OVS.

Run playbook [compute-pre-deploy](#c-2-compute-pre-deploy-yml).
```
ansible-playbook -i inventory/openstack.ini compute-pre-deploy.yml
```


### 4.3.3 Patch Playbook

In container image contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz, /usr/bin/make is missing. Patch playbooks/roles/node/tasks/agent.yml to copy /usr/bin/make from host to container.

[Appendix D Patch](#appendix-d-patch).


## 4.4 Deploy

### 4.4.1 Deploy Controller Node

Run playbook to deploy controller nodes.
```
ansible-playbook -i inventory/openstack.ini controller.yml 
```


### 4.4.2 Neutron Contrail Plugin

Disable or remove OpenStack Neutron networking node and all Neutron agents, because they are not going to be used.
Delete Neutron agent containers.
```
docker rm -f neutron_metadata_agent
docker rm -f neutron_l3_agent
docker rm -f neutron_dhcp_agent
```

Enter Neutron server container.
```
nsenter --target $(docker inspect --format "{{ .State.Pid }}" neutron_server) \
  --mount --uts --ipc --net --pid
```

In the container, add private repo /etc/yum.repos.d/private.repo.
```
[private]
baseurl = http://192.168.183.245/private
enabled = 1
gpgcheck = 0
name = private
priority = 99
```

In the container, install the plugin and API packages.
```
yum install neutron-plugin-contrail python-contrail
```

In the container, update /usr/local/bin/kolla_neutron_extend_start.
```
    neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/opencontrail/ContrailPlugin.ini upgrade head
```

Exit the container.
```
exit
```

Update /etc/kolla/neutron-server/config.json to add plugin configuration file.
```
@@ -1,5 +1,5 @@
 {
-    "command": "neutron-server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini",
+    "command": "neutron-server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/opencontrail/ContrailPlugin.ini",
     "config_files": [
         {
             "source": "/var/lib/kolla/config_files/neutron.conf",
@@ -7,11 +7,12 @@
             "owner": "neutron",
             "perm": "0600"
          },
-        {
-            "source": "/var/lib/kolla/config_files/ml2_conf.ini",
-            "dest": "/etc/neutron/plugins/ml2/ml2_conf.ini",
-            "owner": "neutron",
-            "perm": "0600"
+         {
+             "source": "/var/lib/kolla/config_files/ContrailPlugin.ini",
+             "dest": "/etc/neutron/plugins/opencontrail/ContrailPlugin.ini",
+             "owner": "neutron",
+             "perm": "0600"
+
         }
     ]
 }
```

Add /etc/kolla/neutron-server/ContrailPlugin.ini. Contrail plugin takes authentication info from neutron.conf.
```
[APISERVER]
api_server_ip = <Contrail VIP>
api_server_port = 8082
contrail_extensions = ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None

aaa_mode = cloud-admin

[COLLECTOR]
analytics_api_ip = <Contrail VIP>
analytics_api_port = 8081

[KEYSTONE]
```

Update /etc/kolla/neutron-server/neutron-server.conf. LBaaS Neutron support is not installed (No module named neutron_lbaas.extensions).
```
@@ -9,8 +9,9 @@
 metadata_proxy_socket = /var/lib/neutron/kolla/metadata_proxy
 interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
 allow_overlapping_ips = true
-core_plugin = ml2
-service_plugins = router
+core_plugin = neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2
+#api_extensions_path = extensions:/usr/lib/python2.7/dist-packages/neutron_plugin_contrail/extensions:/usr/lib/python2.7/dist-packages/neutron_lbaas/extensions
+#service_plugins = neutron_plugin_contrail.plugins.opencontrail.loadbalancer.v2.plugin.LoadBalancerPluginV2
 
 [nova]
 auth_url = http://192.168.189.151:35357
@@ -51,7 +52,21 @@
 memcache_security_strategy = ENCRYPT
 memcache_secret_key = azulNh3bSNDRpK7n22vpEpVgRR5ID9bjNgPg6Tm4
 memcached_servers = 192.168.189.142:11211,192.168.189.140:11211,192.168.189.138:11211
+auth_host = 192.168.189.151
+auth_protocol = http
+admin_tenant_name = service
+admin_user = neutron
+admin_password = pRK1ps3KHtQTOkCKH7Z80YENFX9AyR9KeSTMtXNE
 
 [oslo_messaging_notifications]
 driver = noop
 
+[quotas]
+quota_driver = neutron_plugin_contrail.plugins.opencontrail.quota.driver.QuotaDriver
+quota_network = -1
+quota_subnet = -1
+quota_port = -1
+
+#[service_providers]
+#service_provider = LOADBALANCER:Opencontrail:neutron_plugin_contrail.plugins.opencontrail.loadbalancer.driver.OpencontrailLoadbalancerDriver:default
+
```

Restart container.
```
docker restart neutron_server
```


### 4.4.3 Add Compute Node

Comment out old existing compute nodes and add new compute nodes into openstack.ini. Run playbook to add compute nodes.
```
ansible-playbook -i inventory/openstack.ini compute-add.yml 
```

No need to update nova.conf for nova-compute. Contrail VIF is already supported by OpenStack. Only need to copy vrouter-port-control to nova-compute container, which is done as part of pre-deployment.

#### Note
/usr/bin/make is missing in contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz container. To work around it, playbooks/roles/node/tasks/agent.yml is patched to copy /usr/bin/make from host into the container. https://bugs.launchpad.net/opencontrail/+bug/1736193


# 5 Kubernetes

## 5.1 Contrail Node

### 5.1.1 Controller Node

Four containers will be deployed on each controller node. They can be deployed on the existing Kubernetes master node, or on separated node.
* controller
* analytics
* analyticsdb
* kube-manager


## 5.1.2 Slave/Vrouter Node

On each slave node, flannel networking has to be removed. The data network interface can't be on any bridge. It can be bonding interface, physical interface or logical/VLAN interface.

Playbook will deploy vrouter-agent in container and vrouter kernel module on each compute node.


## 5.2 Inventory

Build inventory file [kubernetes.ini](#b-2-kubernetes).


## 5.3 Pre-Deployment

### 5.3.1 Prepare Controller Node

Do the followings to get controller node ready for deployment.
* Enable private repository.
* Install Docker 1.12.6.
* Add insecure-registries.
* Install and configure NTP.
* Due to a binding of /etc/timezone between Ubuntu based container (file) and CentOS based Host (directory), fix the mismatch.

Run playbook [controller-pre-deploy.yml](#c-1-controller-pre-deploy-yml).
```
ansible-playbook -i inventory/openstack.ini controller-pre-deploy.yml
```


### 5.3.2 Prepare Slave Node

The existing slave node has services deployed in Kolla containers on CentOS 7.2 host. Docker version is 1.12.5.

Do the followings to get compute node ready for deployment.
* Enable private repository.
* Upgrade kernel to kernel-3.10.0-514.21.1.el7.
* Install kernel-devel and kernel-headers.
* Upgrade python-docker-py.
* Install and configure NTP.
* Fix /etc/timezone for Ubuntu based container.
* Add insecure-registries.
* Remove flannel.
* Install CNI.
* Update kubelet configuration.


Run playbook [slave-pre-deploy](#c-6-slave-pre-deploy-yml).
```
ansible-playbook -i inventory/kubernetes.ini slave-pre-deploy.yml
```

#### Note
The flannel0 interface doesn't have a link address.
```
6: flannel0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1472 qdisc pfifo_fast state UNKNOWN mode DEFAULT qlen 500
    link/none 
```

It causes problem when hitting this line in /usr/lib/python2.7/dist-packages/contrail_vrouter_provisioning/network.py in vrouter agent container. It only happens when vhost0 interface is already created.
```
            dev_mac = netifaces.ifaddresses(i)[netifaces.AF_LINK][0]['addr']
```

Check Docker cgroup driver "docker info | grep cGroup". If it's cgroupfs (existing Docker), no update required. If it's systemd (upgraded Docker), "--cgroup-driver=systemd" has to be added into command line in /usr/lib/systemd/system/kubelet.service.

Update /etc/kubenetes/kubelet. Contrail needs to know the compute node hostname to locate vrouter and link container (VM object) to that vrouter. So control node can push configuration to that vrouter.
```
#NODE_HOSTNAME="--hostname-override=192.168.189.136"
```


## 5.4 Deploy

### 5.4.1 Deploy Controller Node

Run playbook to deploy controller nodes.
```
ansible-playbook -i inventory/kubernetes.ini controller.yml 
```

#### Note
There is a bug in kube-manager Ubuntu 14.04 based container. The internal-playbook doesn't build supervisor files for kube-manager. Because kube-manager didn't start, the container keeps restarting. Need to manually copy supervisord_kubernetes.conf and supervisord_kubernetes_files into container /etc/contrail directory to make it work.
https://bugs.launchpad.net/opencontrail/+bug/1736065


### 5.4.2 Add Slave Node

Comment out old existing compute nodes and add new compute nodes into openstack.ini. Run playbook to add compute nodes.
```
ansible-playbook -i inventory/kubernetes.ini compute-add.yml 
```


# Appendix A Repository

## A.1 Build repository

Enable yum cache in /etc/yum.conf.
```
keepcache=1
```

Install packages from public repo.

Install package createrepo.
```
yum install createrepo
```

Collect packages from yum cache directory (defined in yum.conf).

Build repo.
```
createrepo /path/to/repo
```

## A.2 Local repository

Place repo on the server and create /etc/yum.repos.d/local.repo.
```
[local]
name=local
baseurl=file:///opt/local
enabled=1
gpgcheck=0
priority=99
```

## A.3 Private repository

To build private repo on the build to serve the deployment, place repo on the builder and make it local repo.

Install HTTP server from local repo on the builder and start the service.
```
yum install httpd
service httpd start
```

Create link to repo.
```
ln /opt/private /var/www/html/private
```


# Appendix B Inventory

## B.1 OpenStack single interface
openstack.ini
```
[all:children]
contrail-controllers
contrail-analytics
contrail-analyticsdb
contrail-compute

[contrail-analyticsdb]
192.168.183.239
192.168.183.240
192.168.183.241

[contrail-controllers]
192.168.183.239
192.168.183.240
192.168.183.241

[contrail-analytics]
192.168.183.239
192.168.183.240
192.168.183.241

[contrail-compute]
192.168.183.203
192.168.183.204
192.168.183.205

[all:vars]
ansible_srvr_ip=192.168.183.245
ansible_srvr_port=9003
ansible_user=root
ansible_password=p@ssw0rd

docker_registry=192.168.183.245:5100
contrail_version=4.0.2.0-35

controller_image=192.168.183.245:5100/contrail-controller-ubuntu14.04:4.0.2.0-35
analytics_image=192.168.183.245:5100/contrail-analytics-ubuntu14.04:4.0.2.0-35
analyticsdb_image=192.168.183.245:5100/contrail-analyticsdb-ubuntu14.04:4.0.2.0-35
agent_image=192.168.183.245:5100/contrail-agent-ubuntu14.04:4.0.2.0-35

cloud_orchestrator=openstack

docker_network_bridge=False
contrail_compute_mode=container

openstack_config={'management_ip': '192.168.183.217', 'ctrl_data_ip': '192.168.183.217'}
keystone_config={'ip': '192.168.183.217', 'version': 'v3', 'admin_user': 'admin', 'admin_password': 'p@ssw0rd'}
global_config={'analytics_ip': '192.168.183.217', 'controller_ip': '192.168.183.217', 'config_ip': '192.168.183.217'}
analytics_api_config={'aaa_mode': 'no-auth'}

ha={'contrail_external_vip': '192.168.183.217'}
enable_lbaas=True
enable_openstack_compute=False
vrouter_physical_interface = eth0
```


## B.2 Kubernetes
kubernetes.ini
```
[all:children]
contrail-controllers
contrail-analytics
contrail-analyticsdb
contrail-compute

[contrail-analyticsdb]
192.168.183.242
192.168.183.243
192.168.183.244

[contrail-controllers]
192.168.183.242
192.168.183.243
192.168.183.244

[contrail-analytics]
192.168.183.242
192.168.183.243
192.168.183.244

[contrail-kubernetes]
192.168.183.242
192.168.183.243
192.168.183.244

[contrail-compute]
192.168.183.206
192.168.183.207
192.168.183.208

[all:vars]
ansible_srvr_ip=192.168.183.245
ansible_srvr_port=9003
ansible_user=root
ansible_password=p@ssw0rd

docker_registry=192.168.183.245:5100
contrail_version=4.0.2.0-35

cloud_orchestrator=kubernetes

controller_image=192.168.183.245:5100/contrail-controller-ubuntu14.04:4.0.2.0-35
analytics_image=192.168.183.245:5100/contrail-analytics-ubuntu14.04:4.0.2.0-35
analyticsdb_image=192.168.183.245:5100/contrail-analyticsdb-ubuntu14.04:4.0.2.0-35
agent_image=192.168.183.245:5100/contrail-agent-ubuntu14.04:4.0.2.0-35

docker_network_bridge=False
contrail_compute_mode=container

global_config={'analytics_ip': '192.168.183.218', 'controller_ip': '192.168.183.218', 'config_ip': '192.168.183.218'}
analytics_api_config={'aaa_mode': 'no-auth'}

ha={'contrail_external_vip': '192.168.183.218'}
```


# Appendix C Playbook

## C.1 common-pre-deploy.yml
```
---
- name: Add private repo
  yum_repository:
    name: private
    description: private
    baseurl: http://{{ ansible_srvr_ip }}/private
    enabled: yes
    gpgcheck: no
    priority: 99

- name: Install NTP
  yum:
    name: ntp
    state: latest

- name: Configure local NTP
  copy:
    src: ntp.conf
    dest: /etc/ntp.conf
    force: yes

- name: Restart NTP
  systemd:
    name: ntpd
    state: restarted

- name: Remove /etc/timezone directory
  file:
    path: /etc/timezone
    state: absent

- name: Copy /etc/timezone file
  vars:
    timezone: "America/Los_Angeles"
  copy: dest=/etc/timezone content="{{ timezone }}"
```

ntp.conf
```
server 127.127.1.0
fudge 127.127.1.0 stratum 8
```


## C.2 controller-pre-deploy.yml
```
---
- name: Contrail controller node pre-deployment
  hosts:
    - contrail-controllers
    - contrail-analytics
    - contrail-analyticsdb
  tasks:
    - import_tasks: common-pre-deploy.yml

    - name: Install Docker
      yum:
        name: docker
        state: latest

    - name: Create /etc/docker directory
      file: dest=/etc/docker state=directory

    - name: Add Docker registry
      template:
        src: daemon.json.js2
        dest: /etc/docker/daemon.json

    - name: Enable and start docker
      systemd:
        name: docker
        enabled: yes
        state: restarted
```

daemon.json.js2
```
{ "insecure-registries": ["192.168.189.143:44380", "{{ docker_registry }}"]}
```


## C.3 compute-pre-deploy.yml
```
---
- name: OpenStack compute node pre-deployment
  hosts: contrail-compute
  tasks:
    - import_tasks: common-pre-deploy.yml

    - name: Upgrade kernel
      yum:
        name: kernel-3.10.0-514.21.1.el7

    - name: Stop container neutron_openvswitch_agent
      command: docker stop neutron_openvswitch_agent
      ignore_errors: yes

    - name: Stop container openvswitch_vswitchd
      command: docker stop openvswitch_vswitchd
      ignore_errors: yes

    - name: Stop container openvswitch_db
      command: docker stop openvswitch_db
      ignore_errors: yes

    - name: Delete container neutron_openvswitch_agent
      command: docker rm neutron_openvswitch_agent
      ignore_errors: yes

    - name: Delete container openvswitch_vswitchd
      command: docker rm openvswitch_vswitchd
      ignore_errors: yes

    - name: Delete container openvswitch_db
      command: docker rm openvswitch_db
      ignore_errors: yes

    - name: Reboot node after kernel upgrade
      shell: sleep 5 && /sbin/shutdown -r now
      async: 1
      poll: 0
      ignore_errors: true

    - name: Waiting for server to come back
      local_action: >
        wait_for
        port=22
        host={{ inventory_hostname }}
        state=started
        delay=30
        timeout=600

    - name: Install kernel-devel and kernel-headers
      yum: pkg={{item}}
      with_items:
        - kernel-devel-3.10.0-514.21.1.el7
        - kernel-headers-3.10.0-514.21.1.el7

    - name: Upgrade python-docker-py
      yum:
        name: python-docker-py
        state: latest

    - name: Add Docker registry
      template:
        src: daemon.json.js2
        dest: /etc/docker/daemon.json

    - name: Restart docker
      systemd:
        name: docker
        state: restarted

    - name: Copy to /tmp/vrouter-port-control
      copy:
        src: vrouter-port-control
        dest: /tmp
        mode: +rwx
        force: yes

    - name: Copy to agent container
      command: docker cp /tmp/vrouter-port-control nova_compute:/usr/bin/

    - name: Delete /tmp/vrouter-port-control
      file:
        name: /tmp/vrouter-port-control
        state: absent
```


## C.4 controller.yml
```
---
- name: Common system settings on base hosts
  hosts: all
  pre_tasks:
    - name: Set flag to decide if docker is required
      set_fact:
        docker_required: true
        provision_type: "{{ provision_type | default('') }}"

- name: Common system settings on base hosts
  hosts: all
  roles:
    - name: Run common code
      role: common
    - name: Upgrade kernel to the version supplied with this image
      role: contrail/upgrade_kernel
      tags: [contrail.upgrade_kernel]
      when: kernel_upgrade and ansible_os_family == 'Debian'
    - name: Setup the containers
      role: node
      tags: [node]

- name: Setup compute node
  hosts: contrail-compute
  roles:
    - name: Run common code
      role: common
    - name: Setup openstack compute in case of openstack
      role: openstack/compute
      tags: [openstack.compute]
      when: cloud_orchestrator == "openstack" and enable_openstack_compute and compute_not_on_esxi
    - name: Setup baremetal agent
      role: contrail/bare_metal_agent
      tags: [contrail.bare_metal_agent]
      when:
        - contrail_compute_mode == 'bare_metal'
        - provision_type != 'contrail_cloud'

- name: Register roles with controller API
  hosts: contrail-controllers
  roles:
    - name: Run common code
      role: common
    - name: Register analytics, analyticsdb and agent with controller API
      role: contrail/register
      tags: [contrail.register]
      when: cloud_orchestrator == 'openstack' or cloud_orchestrator == 'vcenter'
```


## C.5 compute-add.yml
```
---
- name: Common system settings on base hosts
  hosts: all
  pre_tasks:
    - name: Set flag to decide if docker is required
      set_fact:
        docker_required: true
        provision_type: "{{ provision_type | default('') }}"

- name: Common system settings on base hosts
  hosts: all
  roles:
    - name: Run common code
      role: common

- name: Setup compute node
  hosts: contrail-compute
  roles:
    - name: Run common code
      role: common
    - name: Setup the containers
      role: node
    - name: Setup openstack compute in case of openstack
      role: openstack/compute
      tags: [openstack.compute]
      when: cloud_orchestrator == "openstack" and enable_openstack_compute and compute_not_on_esxi
    - name: Setup baremetal agent
      role: contrail/bare_metal_agent
      tags: [contrail.bare_metal_agent]
      when:
        - contrail_compute_mode == 'bare_metal'
        - provision_type != 'contrail_cloud'

- name: Register roles with controller API
  hosts: contrail-controllers
  roles:
    - name: Run common code
      role: common
    - name: Register analytics, analyticsdb and agent with controller API
      role: contrail/register
      tags: [contrail.register]
      when: cloud_orchestrator == 'openstack' or cloud_orchestrator == 'vcenter'

- name: Reboot compute nodes
  hosts: contrail-compute
  post_tasks:

    - name: Reboot node
      shell: sleep 15 && /etc/contrail/contrail_reboot
      async: 20
      poll: 0
      sudo: true
      ignore_errors: true
      when:
        - (contrail_compute_mode == 'bare_metal')
        - (provision_type == '')

    - name: Reboot node having container
      shell: sleep 15 && docker exec -i agent /etc/contrail/contrail_reboot
      async: 20
      poll: 0
      sudo: true
      ignore_errors: true
      when:
        - (contrail_compute_mode == 'container')
        - (provision_type == '')

    # Skip this task from being run on the SM Lite node itself to avoid timing issues with Reboot
    - name: Waiting for server to come back
      local_action: wait_for port=22 host={{ inventory_hostname }} state=started delay=30 timeout=600
      sudo: false
      when:
        - (contrail_compute_mode == 'bare_metal' or contrail_compute_mode == 'container')
        - (provision_type == '')
```


## C.6 slave-pre-deploy.yml
```
---
- name: Kubernetes slave node pre-deployment
  hosts: contrail-compute
  tasks:
    - import_tasks: common-pre-deploy.yml

    - name: Upgrade kernel
      yum:
        name: kernel-3.10.0-514.21.1.el7

    - name: Reboot node after kernel upgrade
      shell: sleep 5 && /sbin/shutdown -r now
      async: 1
      poll: 0
      ignore_errors: true

    - name: Waiting for server to come back
      local_action: >
        wait_for
        port=22
        host={{ inventory_hostname }}
        state=started
        delay=30
        timeout=600

    - name: Install kernel-devel and kernel-headers
      yum: pkg={{item}}
      with_items:
        - kernel-devel-3.10.0-514.21.1.el7
        - kernel-headers-3.10.0-514.21.1.el7

    - name: Upgrade python-docker-py
      yum:
        name: python-docker-py
        state: latest

    - name: Stop and disable flannel
      systemd:
        name: flannel
        enabled: no
        state: stopped

    - name: Update docker.service to remove flannel
      copy:
        src: docker.service
        dest: /usr/lib/systemd/system/docker.service
        force: yes

    - name: Add Docker registry
      template:
        src: daemon.json.js2
        dest: /etc/docker/daemon.json

    - name: Reload service
      systemd:
        daemon_reload: yes

    - name: Restart docker
      systemd:
        name: docker
        state: restarted

    - name: Install CNI
      yum:
        name: contrail-kube-cni
        state: latest

    - name: Update /etc/kubernetes/kubelet
      command: sed -i -e 's/NODE_HOSTNAME/#NODE_HOSTNAME/' /etc/kubernetes/kubelet

    - name: Update /usr/lib/systemd/system/kublet
      copy:
        src: kubelet.service
        dest: /usr/lib/systemd/system/kubelet.service
        force: yes

    - name: Update /etc/kubernetes/kubelet
      template:
        src: kubelet.js2
        dest: /etc/kubernetes/kubelet

    - name: Reload service
      systemd:
        daemon_reload: yes

    - name: Restart kubelet
      systemd:
        name: kubelet
        state: restarted
```

docker.service
```
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target
Requires=

[Service]
Type=notify
EnvironmentFile=-/etc/kubernetes/docker
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/dockerd $DOCKER_OPT_BIP $DOCKER_OPT_MTU $DOCKER_OPTS
LimitNOFILE=1048576
LimitNPROC=1048576

[Install]
WantedBy=multi-user.target
```

kubelet.js2 
```
# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=false"

#  --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"
KUBELET_LOG_DIR="--log-dir=/var/log/kubernetes/"

# --address=0.0.0.0: The IP address for the Kubelet to serve on (set to 0.0.0.0 for all interfaces)
NODE_ADDRESS="--address={{ inventory_hostname }}"

# --port=10250: The port for the Kubelet to serve on. Note that "kubectl logs" will not work if you set this flag.
NODE_PORT="--port=10250"

# --hostname-override="": If non-empty, will use this string as identification instead of the actual hostname.
#NODE_HOSTNAME="--hostname-override={{ inventory_hostname }}"

# --api-servers=[]: List of Kubernetes API servers for publishing events,
# and reading pods and services. (ip:port), comma separated.
KUBELET_API_SERVER="--api-servers=192.168.183.217:18080"

# --allow-privileged=false: If true, allow containers to request privileged mode. [default=false]
KUBE_ALLOW_PRIV="--allow-privileged=false"

# DNS info
KUBELET__DNS_IP="--cluster-dns=192.168.3.100"
KUBELET_DNS_DOMAIN="--cluster-domain=cluster.local"

# Add your own!
KUBELET_ARGS="--image-gc-low-threshold=5"
KUBELET_CNI="--network-plugin=cni"
KUBELET_CNI_CONF="--cni-conf-dir=/etc/cni/net.d"
KUBELET_CNI_BIN="--cni-bin-dir=/opt/cni/bin"

KUBELET_INFRA="--pod-infra-container-image=192.168.189.143:44380/gcr.io/google_containers/pause-amd64:3.0"
```

kubelet.service 
```
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/bin/kubelet    ${KUBE_LOGTOSTDERR}     \
                    ${KUBE_LOG_LEVEL}       \
                    ${NODE_ADDRESS}         \
                    ${NODE_PORT}            \
                    ${NODE_HOSTNAME}        \
                    ${KUBELET_API_SERVER}   \
                    ${KUBE_ALLOW_PRIV}      \
                    ${KUBELET__DNS_IP}      \
                    ${KUBELET_DNS_DOMAIN}      \
                    ${KUBELET_LOG_DIR}          \
                    ${KUBELET_ARGS} \
    ${KUBELET_CNI} \
    ${KUBELET_CNI_CONF} \
    ${KUBELET_CNI_BIN} \
                    --cadvisor-port 4194    \
                    ${KUBELET_INFRA}
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
```


# Appendix D Patch

## D.1 playbooks/roles/common/tasks/facts.yml
```
@@ -77,7 +78,8 @@
     analytics_hostname_list_tmp: "{{ analytics_hostname_list_tmp | default([]) }} + \
                           [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ analytics_group }}"
-  when: ctrl_data_network is defined and analytics_list is not defined
+  when: ctrl_data_network is defined
 
 - name: Create analytics_list - step 3 (with ctrl_data_ip if defined)
   set_fact:
@@ -86,13 +88,14 @@
     analytics_hostname_list_tmp: "{{ analytics_hostname_list_tmp | default([]) }} + \
                           [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ analytics_group }}"
-  when: ctrl_data_network is not defined and analytics_list is not defined
+  when: ctrl_data_network is not defined
 
 - name: Create analytics_list - step 4 (Assign from tmp if not defined)
   set_fact:
       analytics_list: "{{ analytics_list_tmp | default([]) }}"
       analytics_hostname_list: "{{ analytics_hostname_list_tmp | default([]) }}"
-  when: analytics_list is not defined
+  when: analytics_list is not defined or analytics_hostname_list is not defined
 
 # Create analyticsdb_list - start
 - name: Create analyticsdb_list - step 1 (analyticsdb_dict)
@@ -113,7 +116,8 @@
     analyticsdb_hostname_list_tmp: "{{ analyticsdb_hostname_list_tmp | default([]) }} + \
                           [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ analyticsdb_group }}"
-  when: ctrl_data_network is not defined and analyticsdb_list is not defined
+  when: ctrl_data_network is not defined
 
 - name: Create analyticsdb_list - step 3 (with ctrl_data_ip if defined)
   set_fact:
@@ -123,14 +127,14 @@
     analyticsdb_hostname_list_tmp: "{{ analyticsdb_hostname_list_tmp | default([]) }} + \
                           [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ analyticsdb_group }}"
-  when: ctrl_data_network is defined and analyticsdb_list is not defined
+  when: ctrl_data_network is defined
 
 - name: Create analyticsdb_list - step 4 (Assign from tmp if not defined)
   set_fact:
       analyticsdb_list: "{{ analyticsdb_list_tmp | default([]) }}"
       analyticsdb_hostname_list: "{{ analyticsdb_hostname_list_tmp | default([]) }}"
-  when: analyticsdb_list is not defined
+  when: analyticsdb_list is not defined or analyticsdb_hostname_list is not defined
 
 # Create controller_list
 - name: Create controller_list - step 1 (controller_dict)
@@ -152,7 +156,8 @@
                       default([]) }} + \
                       [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ controller_group }}"
-  when: ctrl_data_network is not defined and controller_list is not defined
+  when: ctrl_data_network is not defined
 
 - name: Create controller_list - step 3 (with ctrl_data_ip if defined)
   set_fact:
@@ -163,13 +168,14 @@
                           default([]) }} + \
                           [ '{{ hostvars[item]['ansible_hostname'] }}' ]"
   with_items: "{{ controller_group }}"
-  when: ctrl_data_network is defined and controller_list is not defined
+  when: ctrl_data_network is defined
 
 - name: Create controller_list - step 4 (Assign from tmp if not defined)
   set_fact:
       controller_list: "{{ controller_list_tmp | default([]) }}"
       controller_hostname_list: "{{ controller_hostname_list_tmp|default([]) }}"
-  when: controller_list is not defined
+  when: controller_list is not defined or controller_hostname_list is not defined
 
 - debug :
     msg:
```

## D.2 playbooks/roles/node/tasks/agent.yml
```
@@ -38,23 +38,30 @@
     - docker_registry is not defined or load_vrouter_module_compiler_centos7_image is defined
     - external_vrouter_compile and ansible_os_family == 'RedHat'
 
-- name: "Compile vrouter module"
-  docker_container:
-    name: vrouter-compiler
-    image: "{{ vrouter_compiler_image_centos7 }}"
-    privileged: true
-    state: started
-    tty: true
-    pull: "{{ always_pull_image }}"
-    detach: true
-    cleanup: true
-    capabilities:
-      - AUDIT_WRITE
-    env:
-      INSTALL_VROUTER_MODULE: true
-    volumes:
-      - "/lib/modules:/lib/modules"
-      - "/usr/src/kernels:/usr/src/kernels"
+- block:
+  - name: "Compile vrouter module"
+    docker_container:
+      name: vrouter-compiler
+      image: "{{ vrouter_compiler_image_centos7 }}"
+      privileged: true
+      state: started
+      tty: true
+      pull: "{{ always_pull_image }}"
+      detach: true
+      cleanup: true
+      capabilities:
+        - AUDIT_WRITE
+      env:
+        INSTALL_VROUTER_MODULE: true
+      volumes:
+        - "/lib/modules:/lib/modules"
+        - "/usr/src/kernels:/usr/src/kernels"
+  - name: "Stop container"
+    command: docker stop vrouter-compiler
+  - name: "Copy /usr/bin/make to container"
+    command: docker cp /usr/bin/make vrouter-compiler:/usr/bin
+  - name: "Start container"
+    command: docker start vrouter-compiler
   when: external_vrouter_compile and ansible_os_family == 'RedHat'
 
 - name: "Fail if external_vrouter_compile is true and unsupported OS family"
```


push-images
```
#!/bin/bash

push_images()
{
    image_list="
        contrail-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analyticsdb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-analytics-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-controller-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-kube-manager-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-kubernetes-agent-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-lb-ubuntu14.04-4.0.2.0-35.tar.gz
        contrail-vrouter-compiler-centos7-4.0.2.0-35.tar.gz"

    for image in $image_list;
    do
        len=${#image}
        name=${image:0:(len - 18)}
        tag=${image:(len - 17):10}

        echo "Load $image"
        docker load < $image

        echo "Tag $image"
        docker tag $name:$tag localhost.localdomain:5100/$name:$tag

        echo "Push $image"
        docker push localhost.localdomain:5100/$name:$tag

        echo "Delete $image"
        docker rmi $name:$tag
        docker rmi localhost.localdomain:5100/$name:$tag

    done
}

push_images
```

