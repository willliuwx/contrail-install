
# 1 Overview

Contrail 5.0.0 with OpenStack Ocata

#### CentOS
* Controller and builder VMs are based on `CentOS-7-x86_64-GenericCloud-1805.qcow2`.
* Compute node is installed from `CentOS-7-x86_64-Minimal-1804.iso`.


# 2 Builder

## 2.1 SSH

Use existing SSH key or generate new key.
```
ssh-keygen
```

Create `.ssh/config`.
```
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```


## 2.2 Ansible

Ansible version 2.4.2 is required.

#### CentOS
Install Ansible without EPEL repo. Ansible 2.4.2.0-2.el7 will be installed from CentOS 7 `extras` repo.
```
yum install ansible
```


## 2.3 Playbook

Install `git`. Contrail playbook uses `git` to get OpenStack Kolla playbook.
```
yum install git
```

Get contrail-ansible-deployer-5.0.0-1.40.tgz from Juniper.
```
tar xzf contrail-ansible-deployer-5.0.0-1.40.tgz
```


## 2.4 Registry


# 3 Deploy

## 3.1 instances.yaml

## 3.2 Pre-deployment
For CentOS, kernel on compute node has to be 3.10.0-693.21.1.el7.x86_64.

## 3.3 Run playbook
```
cd contrail-ansible-deployer
#ansible-playbook -i inventory/ \
#    playbooks/provision_instances.yml

ansible-playbook -i inventory/ \
    playbooks/configure_instances.yml

ansible-playbook -i inventory/ -e orchestrator=openstack \
    playbooks/install_contrail.yml
```


# Ubuntu

xenial-server-cloudimg-amd64-disk1.img

Ubuntu 16.04.4 LTS Xenial

Docker version 17.05.0-ce, build 89658be

kernel: 4.4.0-124-generic

Install python (2.7) and python-pip before running playbooks.


# instances.yaml

#### non-HA, single network
```
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    ntpserver: 10.84.5.100
    domainsuffix: local
instances:
  bms1:
    provider: bms
    ip: 10.84.29.61
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms2:
    provider: bms
    ip: 10.84.29.62
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms3:
    provider: bms
    ip: 10.84.29.63
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: hub.juniper.net/contrail
  CONTAINER_REGISTRY_USERNAME: JNPR-FieldUser13
  CONTAINER_REGISTRY_PASSWORD: qyrbAfCE46wQuTx7jc8R
contrail_configuration:
  CONTRAIL_VERSION: 5.0.0-0.40-ocata
  CLOUD_ORCHESTRATOR: openstack
  VROUTER_GATEWAY: 10.84.29.254
  PHYSICAL_INTERFACE: eth0
kolla_config:
  kolla_globals:
    enable_haproxy: "no"
    enable_ironic: "no"
    enable_swift: "no"
  kolla_passwords:
    keystone_admin_password: contrail123
```

#### non-HA, management and data networks
```
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    ntpserver: 10.84.5.100
    domainsuffix: local
instances:
  bms1:
    provider: bms
    ip: 10.84.29.61
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms2:
    provider: bms
    ip: 10.84.29.62
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms3:
    provider: bms
    ip: 10.84.29.63
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: hub.juniper.net/contrail
  CONTAINER_REGISTRY_USERNAME: JNPR-FieldUser13
  CONTAINER_REGISTRY_PASSWORD: qyrbAfCE46wQuTx7jc8R
contrail_configuration:
  CONTRAIL_VERSION: 5.0.0-0.40-ocata
  CLOUD_ORCHESTRATOR: openstack
  CONTROL_DATA_NET_LIST: 192.168.2.0/24
  PHYSICAL_INTERFACE: eth1
  VROUTER_GATEWAY: 192.168.2.254
kolla_config:
  kolla_globals:
    enable_haproxy: "no"
    enable_ironic: "no"
    enable_swift: "no"
  kolla_passwords:
    keystone_admin_password: contrail123
```

#### HA, management and data networks
```
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    ntpserver: 10.84.5.100
    domainsuffix: local
instances:
  bms1:
    provider: bms
    ip: 10.84.29.61
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms2:
    provider: bms
    ip: 10.84.29.63
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms3:
    provider: bms
    ip: 10.84.29.65
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms4:
    provider: bms
    ip: 10.84.29.62
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms5:
    provider: bms
    ip: 10.84.29.64
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms6:
    provider: bms
    ip: 10.84.29.66
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms7:
    provider: bms
    ip: 10.84.29.12
    roles:
      vrouter:
      openstack_compute:
  bms8:
    provider: bms
    ip: 10.84.29.13
    roles:
      vrouter:
      openstack_compute:
  bms9:
    provider: bms
    ip: 10.84.29.14
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: hub.juniper.net/contrail
  CONTAINER_REGISTRY_USERNAME: JNPR-FieldUser13
  CONTAINER_REGISTRY_PASSWORD: qyrbAfCE46wQuTx7jc8R
contrail_configuration:
  CONTRAIL_VERSION: 5.0.0-0.40-ocata
  CLOUD_ORCHESTRATOR: openstack
  CONTROL_DATA_NET_LIST: 192.168.2.0/24
  PHYSICAL_INTERFACE: p514p2
  VROUTER_GATEWAY: 192.168.2.254
  WEBUI_INSECURE_ACCESS: true
kolla_config:
  kolla_globals:
    enable_ironic: "no"
    enable_swift: "no"
    kolla_internal_vip_address: 192.168.2.251
    kolla_external_vip_address: 10.84.29.251
    contrail_api_interface_address: 192.168.2.251
  kolla_passwords:
    keystone_admin_password: contrail123
```

#### Set lower disk space for POC.
```
contrail_configuration:
  CONFIG_NODEMGR__DEFAULTS__minimum_diskGB: 20
  DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: 20
```

#### Set role specific variable.
```
instances:
  bms3:
    provider: bms
    ip: 10.84.29.63
    roles:
      vrouter:
        PHYSICAL_INTERFACE: eth1
        VROUTER_GATEWAY: 192.168.2.254
      openstack_compute:
```

#### Set Keystone version.
```
contrail_configuration:
  KEYSTONE_AUTH_URL_VERSION: /v3
```


## Add compute node

* Create instances.yaml for the new compute nodes and run configure_instances.
* Add new compute nodes into instances.yaml of the cluster and run contrail_install.


