
# 1 Overview

This guide is to install AppFormix to RHOSP 10 cluster.


# 2 Controller VM

AppFormix controller is installed on the VM on one of controller hosts. The VM is based on cloud image rhel-server-7.5-x86_64-kvm.qcow2.

Here is VM spec.
* 8 vCPU
* 32 GB memory
* 100 GB disk

The controller has the same networking configuration as other overcloud controllers.


# 3 Install

#### Register and enable repos.
```
subscription-manager register
subscription-manager list --available --all --matches="*OpenStack*"
subscription-manager attach --pool=<pool ID>
subscription-manager repos --disable=*
subscription-manager repos \
    --enable=rhel-7-server-rpms \
    --enable=rhel-7-server-extras-rpms \
    --enable=rhel-7-server-rh-common-rpms \
    --enable=rhel-ha-for-rhel-7-server-rpms
yum repolist
```

#### Install Ansible
The Ansible version has to be 2.3. `python-pip` is required to install Ansible.

Enable EPEL to install python-pip.
```
yum install -y python-devel
yum install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum repolist
yum install -y python-pip
yum groupinstall 'Development Tools'
pip install ansible==2.3
```

#### Prepare compute node
Give the RHOSP 10 cluster, on compute node, EPEL repo is already enabled and python-pip is already installed. Only need to install `virtualenv` package.
```
pip install virtualenv
```

#### AppFormix license
AppFormix license is required before installation.

For installation in a customer environment, identify the opportunity in Salesforce and submit a POC plan to appformix-plm@juniper.net. After approval, a license may be requested by sending the following information to APPFORMIX-KEY-REQUEST@juniper.net.
```
Company Name:
Customer / Contact Name:
Company address:
Phone:
E-mail:

Cluster type: OpenStack or VMware vCenter or Network devices (e.g., standalone)
Number of hosts:
Number of instances (virtual machines):
Number of network devices:
Duration of trial:
```

#### AppFormix packages
Get the following packages and copy them onto the controller.
* appformix-2.16.5.tar.gz
* appformix-dependencies-images-2.16.5.tar.gz
* appformix-openstack-images-2.16.5.tar.gz
* appformix-platform-images-2.16.5.tar.gz

Copy the license file onto the controller as well.

#### Build playbook inventory
The playbook is in package `appformix-2.16.5.tar.gz`.
```
tar xzf appformix-2.16.5.tar.gz
cd appformix-2.16.5
mkdir inventory
```

inventory/hosts
```
[compute]
10.0.0.30 ansible_ssh_user=heat-admin
10.0.0.31 ansible_ssh_user=heat-admin

[appformix_controller]
10.0.0.100 ansible_ssh_user=root

[openstack_controller]
10.0.0.20 ansible_ssh_user=heat-admin
```

inventory/group_vars/all
```
openstack_platform_enabled: true

appformix_version: 2.16.5
appformix_manager_version: 2.16.5
appformix_license: /root/appformix-internal-openstack-2.15.sig

appformix_docker_images:
  - /root/appformix-platform-images-2.16.5.tar.gz
  - /root/appformix-openstack-images-2.16.5.tar.gz
  - /root/appformix-dependencies-images-2.16.5.tar.gz

appformix_plugins: '{{ appformix_contrail_factory_plugins }} + {{ appformix_network_device_factory_plugins }} + {{ appformix_openstack_factory_plugins }} + {{ appformix_application_factory_plugins }} + {{ appformix_remote_host_factory_plugins }} + {{appformix_network_device_factory_juniper_plugins }}'

appformix_network_device_monitoring_enabled: true
appformix_remote_host_monitoring_enabled: true
appformix_jti_network_device_monitoring_enabled: true
```

#### SSH key
Copy `id_rsa` and `id_rsa.pub` from `undercloud:/home/stack/.ssh` directory to `controller:/root/.ssh`, for the controller to access overcloud nodes as `heat-admin`.

Enable SSH key for localhost.
```
ssh-copy-id root@localhost
```

#### OpenStack environment variable
openrc
```
export OS_USERNAME=admin
export OS_PASSWORD=R2ckp9Rtj4vMxgXYKj6p9fFF2
export OS_AUTH_URL=http://10.0.0.20:5000/v2.0
export OS_PROJECT_NAME=admin
export OS_IDENTITY_API_VERSION=2
export OS_IMAGE_API_VERSION=2
export OS_NO_CACHE=1
```

#### Check connectivity
```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible -i inventory -m ping all
```

#### Run playbook
```
source openrc
cd appformix-2.16.5
ansible-playbook -i inventory appformix_openstack.yml 
```


# 3 Start AppFormix

Open AppFormix web UI, http://<controller address>:9000, to initialize.

Run `docker ps` on the controller to get the port of each AppFormix service.

* dashboard: 9000
* openstack_adapter: 7500
* controller: 7000
* datamanager: 8090


