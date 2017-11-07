# 1 Overview

This guide is for deploying Contrail 4.0 networking without any integrations.

## 1.1 Version

CentOS 7.2 needs the following updates.
  * Upgrade kernel and install kernel-devel and kernel-headers on compute node.
  * Use xfs as the back of overlay or upgrade kernel to support ext4 as the back of overlay. This is required by Docker.

CentOS 7.3 doesn't need any updates.

The kernel used by this guide is 3.10.0-514.21.1.el7.x86_64.

Here is the Docker used by this guide.
```
Client:
 Version:         1.12.6
 API version:     1.24
 Package version: docker-1.12.6-28.git1398f24.el7.centos.x86_64
 Go version:      go1.7.4
 Git commit:      1398f24/1.12.6
 Built:           Fri May 26 17:28:18 2017
 OS/Arch:         linux/amd64

Server:
 Version:         1.12.6
 API version:     1.24
 Package version: docker-1.12.6-28.git1398f24.el7.centos.x86_64
 Go version:      go1.7.4
 Git commit:      1398f24/1.12.6
 Built:           Fri May 26 17:28:18 2017
 OS/Arch:         linux/amd64
```

## 1.2 Private Repository

In case the environment doesn't have access to public repo, a private repo needs to be built to serve the deployment.

Check [Appendix A Repository](#appendix-a-repository).


# 2 Pre-deployment

## 2.1 Image servers

Image builder, controller(s) and compute node(s) with CentOS 7.2 or CentOS 7.3.

## 2.2 Private repo on the builder

Setup private repo on the builder if it's required.
Check [Appendix A Repository](#appendix-a-repository).

## 2.3 Ansible

Install Ansible on the builder. With private repo, epel-release package is not required.
```
yum install epel-release
yum install ansible
```

Here is the Ansible used by this guide.
```
ansible 2.3.0.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = Default w/o overrides
  python version = 2.7.5 (default, Nov 20 2015, 02:00:19) [GCC 4.8.5 20150623 (Red Hat 4.8.5-4)]
```

## 2.4 SSH key

Place SSH private key on the builder and add public key to all servers.

## 2.5 Playbook

Install playbook from package contrail-ansible-4.0.0.0-20.tar.gz.
```
mkdir contrail-4.0-20
cd contrail-4.0-20
tar -xzf contrail-ansible-4.0.0.0-20.tar.gz
```

## 2.6 Host inventory

Create new inventory for the deployment and update the followings in hosts.
```
[contrail-controllers]
[contrail-analyticsdb]
[contrail-analytics]
[contrail-kubernetes]
[contrail-compute]
```

## 2.7 Private repo

If private is required, update URL in priv-repo.yml and run playbook to configure it on all hosts.
```
ansible-playbook -i inventory/b7s8 priv-repo.yml
```

## 2.8 Upgrade kernel on compute node

In case of CentOS 7.2, kernel needs to be upgraded on all compute nodes.
```
ansible-playbook -i inventory/b7s8 kernel-upgrade.yml
```


# 3 Deploy Contrail networking for Kubernets

Assume Kubernetes is already deployed. This section deploys the followings.
* Control node
  * Contrail controller container
  * Contrail analytics container
  * Contrail analytics DB container
  * Contrail Kubernetes manager container
* Compute node
  * Contrail vrouter agent container
  * Contrail vrouter kernel module
  * Contrail CNI plugin

Place the following container images to playbook/container_images.
```
contrail-agent-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analytics-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-controller-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-kube-manager-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-lb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-vrouter-compiler-centos7-4.0.0.0-20.tar.gz
```

Update playbooks/inventory/b7s8/group_vars/all.yml.
```
--- inventory/my-inventory/group_vars/all.yml
+++ inventory/b7s8/group_vars/all.yml
@@ -2,8 +2,8 @@
 # Docker configurations
 ##
 # docker registry
-docker_registry: 10.84.34.155:5000
-docker_registry_insecure: True
+#docker_registry: 10.84.34.155:5000
+#docker_registry_insecure: True
 
 # install docker from package rather than installer from get.docker.com which is default method
 docker_install_method: package
@@ -24,12 +24,13 @@
 # contrail_compute_mode - the values are bare_metal to have bare_metal agent setup and "container" for agent container
 # default is bare_metal
 # contrail_compute_mode: bare_metal
+contrail_compute_mode: container
 
 # os_release - operating system release - ubuntu 14.04 - ubuntu14.04, ubuntu 16.04 - ubuntu16.04, centos 7.1 - centos7.1, centos 7.2 - centos7.2
 os_release: ubuntu14.04
 
 # contrail version
-contrail_version: 4.0.0.0-3016
+contrail_version: 4.0.0.0-20
 
 # cloud_orchestrator - cloud orchestrators to be setup
 # Valid cloud orchestrators:
@@ -64,7 +65,7 @@
 # global_config:
 
 # To configure custom webui http port
-# webui_config: {http_listen_port: 8085}
+webui_config: {http_listen_port: 8085}
 
 ###################################################
 # Openstack specific configuration
```

Run playbook.
```
ansible-playbook -i inventory/b7s8 site.yml
```


# 4 Deploy Contrail networking for OpenStack

Assume OpenStack is already deployed. This section deploys the followings.
* Control node
  * Contrail controller container
  * Contrail analytics container
  * Contrail analytics DB container
* Compute node
  * Contrail vrouter agent package
  * Contrail vrouter kernel module
* OpenStack Neutron server
  * Neutron Contrail plugin

Contrail vrouter packages are required to install vrouter on compute node. They can be provided by private repo or local repo.

## 4.1 Controller node

Place the following container images to playbook/container_images.
```
contrail-analyticsdb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analytics-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-controller-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-lb-ubuntu14.04-4.0.0.0-20.tar.gz
```

Update playbooks/inventory/b7s8/hosts. Comment out all other groups.
```
[contrail-controllers]
[contrail-analyticsdb]
[contrail-analytics]
```

Update playbooks/inventory/b7s8/group_vars/all.yml.
```
--- inventory/my-inventory/group_vars/all.yml   2017-06-08 16:21:59.892660425 -0700
+++ inventory/b7s8/group_vars/all.yml   2017-06-09 15:44:55.324539217 -0700
@@ -2,8 +2,8 @@
 # Docker configurations
 ##
 # docker registry
-docker_registry: 10.84.34.155:5000
-docker_registry_insecure: True
+#docker_registry: 10.84.34.155:5000
+#docker_registry_insecure: True
 
 # install docker from package rather than installer from get.docker.com which is default method
 docker_install_method: package
@@ -23,18 +23,18 @@
 
 # contrail_compute_mode - the values are bare_metal to have bare_metal agent setup and "container" for agent container
 # default is bare_metal
-# contrail_compute_mode: bare_metal
+contrail_compute_mode: bare_metal
 
 # os_release - operating system release - ubuntu 14.04 - ubuntu14.04, ubuntu 16.04 - ubuntu16.04, centos 7.1 - centos7.1, centos 7.2 - centos7.2
 os_release: ubuntu14.04
 
 # contrail version
-contrail_version: 4.0.0.0-3016
+contrail_version: 4.0.0.0-20
 
 # cloud_orchestrator - cloud orchestrators to be setup
 # Valid cloud orchestrators:
 # kubernetes, mesos, openstack, openshift
-cloud_orchestrator: kubernetes
+cloud_orchestrator: openstack
 
 # vrouter physical interface
 vrouter_physical_interface: eth0
@@ -70,7 +70,7 @@
 # Openstack specific configuration
 ##
 # contrail_install_packages_url: "http://10.84.5.120/github-build/mainline/3023/ubuntu-14-04/mitaka/contrail-install-packages_4.0.0.0-3023~mitaka_all.deb"
-# keystone_config: {ip: 192.168.0.23, admin_password: contrail123, auth_protocol: http}
+keystone_config: {ip: 10.87.68.167, admin_password: contrail123, auth_protocol: http}
 
 ###################################################
 # SSL Cert Configuration (Path to copy SSL certs to containers/bare metal)
```
[GLOBAL]
compute_nodes = 
enable_webui_service = True
sandesh_ssl_enable = False
cloud_orchestrator = openstack
enable_config_service = True
config_nodes = 10.84.29.99
config_ip = 10.84.29.99
analyticsdb_nodes = 10.84.29.99
enable_control_service = True
introspect_ssl_enable = False
controller_nodes = 10.84.29.99
analytics_nodes = 10.84.29.99
ceph_controller_nodes = 
analytics_ip = 10.84.29.99
controller_ip = 10.84.29.99
[WEBUI]
webui_storage_enable = False
[KEYSTONE]
auth_protocol = http
ip = 10.87.68.167
admin_password = contrail123

Run playbook.
```
ansible-playbook -i inventory/b7s8 site.yml
```

## 4.2 Compute node


## 4.3 Neutron Server



# 2 Controller

Install Docker to run Contrail containers.
```
yum install epel-release
yum install docker
service docker start
```

# 3 Compute

Packages kernel-devel and kernel-headers are required to compile vrouter kernel module. On CentOS 7.2, kernel also needs to be updated.
```
yum update kernel
reboot
yum install kernel-devel kernel-headers
```

# 4 Builder

The builder is for running playbooks. It can be on one of the target machines, or a separate machine.

## 4.1 Install Ansible

```
yum install epel-release
yum install ansible
```

Here is the Ansible used by this guide.
```
ansible 2.3.0.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = Default w/o overrides
  python version = 2.7.5 (default, Nov 20 2015, 02:00:19) [GCC 4.8.5 20150623 (Red Hat 4.8.5-4)]
```

## 4.2 Install Playbook

The playbook is in package contrail-ansible-4.0.0.0-20.tar.gz.
```
mkdir contrail-4.0-20
cd contrail-4.0-20
tar -xzf contrail-ansible-4.0.0.0-20.tar.gz
```

## 4.3 Container Images
With Contrail 4.0, Ubuntu container is deployed on CentOS controller.

Get the following images and place them to playbooks/container_images directory.
```
contrail-agent-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analytics-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-controller-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-lb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-vrouter-compiler-centos7-4.0.0.0-20.tar.gz
```

## 4.4 Inventory

Create new inventory for the deployment.

Update the followings in hosts.
```
[contrail-controllers]
[contrail-analyticsdb]
[contrail-analytics]
[contrail-kubernetes]
[contrail-compute]
```

Update the followings in group_vars/all.yml.
```
#docker_registry: 10.84.34.155:5000
#docker_registry_insecure: True

contrail_compute_mode: container

contrail_version: 4.0.0.0-20

webui_config: {http_listen_port: 8085}

```

## 4.5 Add SSH Key
Create SSH key pair or use existing SSH key pair for builder to access all hosts.
Update /etc/ssh/ssh_config.
```
StrictHostKeyChecking no
```




contrail-ansible-4.0.0.0-20.tar.gz
contrail-docker-images_4.0.0.0-20.tgz
contrail-kube-manager-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-networking-dependents_4.0.0.0-20.tgz
contrail-networking-docker_4.0.0.0-20_trusty.tgz
contrail-networking-openstack-extra_4.0.0.0-20.tgz
contrail-networking-thirdparty_4.0.0.0-20.tgz
contrail-networking-tools_4.0.0.0-20.tgz
contrail-neutron-plugin-packages_4.0.0.0-20.tgz
contrail-vrouter-compiler-centos7-4.0.0.0-20.tar.gz
contrail-vrouter-packages_4.0.0.0-20.tgz


contrail-kubernetes-docker_4.0.0.0-20_trusty.tgz
  * contrail-networking-tools_4.0.0.0-20.tgz
    * contrail-ansible-4.0.0.0-20.tar.gz
    * contrail-docker-tools_4.0.0.0-20_all.deb
  * contrail-kubernetes-docker-images_4.0.0.0-20.tgz
    * contrail-analytics-ubuntu14.04-4.0.0.0-20.tar.gz
    * contrail-lb-ubuntu14.04-4.0.0.0-20.tar.gz
    * contrail-controller-ubuntu14.04-4.0.0.0-20.tar.gz
    * contrail-vrouter-compiler-centos7-4.0.0.0-20.tar.gz
    * contrail-kube-manager-ubuntu14.04-4.0.0.0-20.tar.gz
    * contrail-agent-ubuntu14.04-4.0.0.0-20.tar.gz
    * contrail-analyticsdb-ubuntu14.04-4.0.0.0-20.tar.gz
  * contrail-networking-thirdparty_4.0.0.0-20.tgz
    * docker-engine_1.13.0-0~ubuntu-trusty_amd64.deb
    * ansible_2.2.0.0-1ppa~trusty_all.deb
    * ......
  * contrail-networking-dependents_4.0.0.0-20.tgz

# Appendix A Repository

## A.1 Build repository

Enable yum cache in /etc/yum.conf.
```
keepcache=1
```

Install packages from public repo.

Collect packages from yum cache directory (defined in yum.conf).

Install package createrepo.
```
yum install createrepo
```

Build repo.
```
createrepo /path/to/repo
```

## A.3 Local repository

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

# Appendix B Playbook

## B.1 priv-repo.yml
```
---
- name: Add private repo
  hosts: all

  tasks:
    - name: Add private repo
      yum_repository:
        name: private
        description: private
        baseurl: http://10.84.29.96/private
        enabled: yes
        gpgcheck: no
        priority: 99
```

## B.2 kernel-upgrade.yml
```
---
- name: Upgrade kernel on compute
  hosts: contrail-compute

  tasks:
    - name: Upgrade kernel
      yum:
        name: kernel
        state: latest

    - name: Reboot node after kernel upgrade
      shell: sleep 5 && /sbin/shutdown -r now
      async: 1
      poll: 0
      sudo: true
      ignore_errors: true

    - name: Waiting for server to come back
      local_action: >
        wait_for
        port=22
        host={{ inventory_hostname }}
        state=started
        delay=30
        timeout=600
      sudo: false
```

