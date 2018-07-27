
# 1 Overview

Contrail 5.0.1 with OpenStack Ocata

## Traffic isolation
There are 3 types of traffic.
* management, including SSH, SNMP, administation traffic.
* API, including both OpenStack and Contrail API traffic, RabbitMQ, database, etc.
* ctrl/data, including XMPP and DNS between vrouter and control node, BGP and tunnel/encapsulation traffic.

For security or bandwidth reservation, traffic could be required on separated networks.

#### All traffic on signle network
Deployment will be done on management network. All traffic will be on management network as well.

#### Separated management and API/ctrl/data traffic
The easiest way is to do deployment on the API/ctrl/data network. Management work is not visible to OpenStack and Contrail. In case web UI or API needs to be accessed from management network, need to open it.

#### Separated management, API and ctrl/data traffic
Do deployment on API network and put ctrl/data traffic on ctrl/data network.


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

For beta, get contrail-ansible-deployer from Github.


## 2.4 Registry


# 3 Deploy

## 3.1 instances.yaml

[A.1](#a1) Run deployment on management network. All traffic is on management network.

[A.2](#a2) Run deployment on management network. All OpenStack traffic (API, RabbitMQ, MySQL, etc.) is on management network. All Contrail traffic (API and ctrl/data) is on the ctrl/data network.

## 3.2 Pre-deployment

## 3.3 Run playbook
```
cd contrail-ansible-deployer

ansible-playbook -i inventory/ -e orchestrator=openstack \
    playbooks/configure_instances.yml

ansible-playbook -i inventory/ \
    playbooks/install_openstack.yml

ansible-playbook -i inventory/ -e orchestrator=openstack \
    playbooks/install_contrail.yml
```

## 3.4 Post-deployment


# Appendix

## A.1 non-HA, single network
The single network could be either management network or API/ctrl/data network.
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
    ip: 10.87.68.171
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
  bms2:
    provider: bms
    ip: 10.87.68.172
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms3:
    provider: bms
    ip: 10.87.68.173
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  #CONTAINER_REGISTRY: ci-repo.englab.juniper.net:5010
  CONTAINER_REGISTRY: 10.84.5.81:5010
  REGISTRY_PRIVATE_INSECURE: True
  #CONTAINER_REGISTRY: hub.juniper.net/contrail
  #CONTAINER_REGISTRY_USERNAME:
  #CONTAINER_REGISTRY_PASSWORD:
contrail_configuration:
  CONTRAIL_VERSION: ocata-5.0-154
  CLOUD_ORCHESTRATOR: openstack
  VROUTER_GATEWAY: 10.87.68.254
kolla_config:
  kolla_globals:
    enable_haproxy: "no"
    enable_ironic: "no"
    enable_swift: "no"
  kolla_passwords:
    keystone_admin_password: contrail123
```

## A.2 non-HA, management and ctrl/data networks
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
  CONTAINER_REGISTRY_USERNAME:
  CONTAINER_REGISTRY_PASSWORD:
contrail_configuration:
  CONTRAIL_VERSION: 5.0.0-0.40-ocata
  CLOUD_ORCHESTRATOR: openstack
  CONTROLLER_NODES: 172.16.0.172
  CONTROL_NODES: 172.16.0.172
  VROUTER_GATEWAY: 172.16.0.254
kolla_config:
  kolla_globals:
    enable_haproxy: "no"
    enable_ironic: "no"
    enable_swift: "no"
  kolla_passwords:
    keystone_admin_password: contrail123
```

## A.3 HA, management and data networks
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
    ip: 10.87.68.171
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms2:
    provider: bms
    ip: 10.87.68.172
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms3:
    provider: bms
    ip: 10.87.68.173
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
  bms7:
    provider: bms
    ip: 10.87.68.174
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: hub.juniper.net/contrail
  CONTAINER_REGISTRY_USERNAME:
  CONTAINER_REGISTRY_PASSWORD:
contrail_configuration:
  CONTRAIL_VERSION: 5.0.0-0.40-ocata
  CLOUD_ORCHESTRATOR: openstack
  CONTROLLER_NODES: 172.16.0.171,172.16.0.172,172.16.0.173
  CONTROL_NODES: 172.16.0.171,172.16.0.172,172.16.0.173
  VROUTER_GATEWAY: 172.16.0.254
  WEBUI_INSECURE_ACCESS: true
kolla_config:
  kolla_globals:
    enable_ironic: "no"
    enable_swift: "no"
    kolla_internal_vip_address: 172.16.0.170
    kolla_external_vip_address: 10.87.68.170
    contrail_api_interface_address: 172.16.0.170
  kolla_passwords:
    keystone_admin_password: contrail123
```

#### Contrail traffic isolation
```
contrail_configuration:
# Address on the controller for API access.
  CONTROLLER_NODES: 172.16.0.172
# Address on the controller for XMPP, BGP and DNS.
  CONTROL_NODES: 172.16.0.172
```

#### CSN (Contrail Service Node)
```
  bms4:
    provider: bms
    ip: 10.87.68.174
    roles:
      vrouter:
        TSN_EVPN_MODE: True
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


