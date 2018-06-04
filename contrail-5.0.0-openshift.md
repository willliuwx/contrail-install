
# 1 Overview

This guide is to deploy OpenShift 3.7 and Contrail Networking 5.0. All hosts are VM based on cloud image in this guide.

Contrail containers are hosted on Juniper registry and are validated with OpenShift Enterprise on RHEL. Send email to contrail-registry@juniper.net to request username and password.

#### CentOS
The deployment is OpenShift Origin 3.7 on CentOS 7.4. Cloud image is CentOS-7-x86_64-GenericCloud-1711.qcow2.

#### RHEL
The deployment is OpenShift Enterprise 3.7 on RHEL 7.5. Cloud image is rhel-server-7.5-x86_64-kvm.qcow2.

All RHEL hosts have to be registered and subscribed prior to deployment.

* Register.
```
subscription-manager register --username <username> --password <password> --force
```

* List available subscriptions.
```
subscription-manager list --available --matches 'Red Hat OpenShift*'
```

* Find a pool ID from the output of previous command and attach to it.
```
subscription-manager attach --pool=<ID>
```

* Check yum repo and disable them if they are not required. This not required for the host based on RHEL cloud image.
```
yum repolist
subscription-manager repos --disable *
```

* Enable yum repo for OpenShift Enterprise 3.7.
```
subscription-manager repos \
    --enable rhel-7-server-rpms \
    --enable rhel-7-server-extras-rpms \
    --enable rhel-7-server-ose-3.7-rpms \
    --enable rhel-7-fast-datapath-rpms
```


# 2 Builder

Builder is the place to run Ansible playbook and optionally host private registry. For the miminum deployment, builder and master can be on the same host.


## 2.1 SSH key

Setup SSH key or generate new key.
```
ssh-keygen
```


## 2.2 Ansible

Install Ansible and required packages. Ansible version has to be 2.4.2.0.

#### CentOS
```
yum install ansible python-netaddr patch
```
This installs Ansible 2.4.2.0 from extras/7/x86_64. Don't install EPEL repo on builder, because Ansible from EPEL is 2.5.3.

#### RHEL
```
yum install ansible python-netaddr patch
```
This installs Ansible 2.4.2.0 from rhel-7-server-extras-rpms/x86_64.


## 2.3 Playbook

Download playbook package contrail-openshift-deployer-5.0.0-0.40.tgz from Juniper download site, and unpack it on the builder.

A few updates are required to the playbook. Get [openshift-ansible-5.0.0-40.patch](https://github.com/tonyliu0592/contrail-install/raw/master/openshift/openshift-ansible-5.0.0-40.patch) and apply to the original playbook.
```
tar xzf contrail-openshift-deployer-5.0.0-0.40.tgz
patch -p0 < openshift-ansible-5.0.0-40.patch
```

## 2.4 Registry

Optionally, build a private insecured registry to host Contrail containers.



# 3 Host

Master/Controller VM spec:
* 6 vCPU
* 64GB memory
* 200GB disk

Node VM spec:
* 4 vCPU
* 32GB memory
* 100GB disk

LB VM spec:
* 2 vCPU
* 16GB memory
* 40GB disk

Customize cloud image.
* Set password.
* Enable password and key for SSH access.
* Configure networking.
* Remove cloud-init.
 

# 4 Deployment

## 4.1 Inventory

* [inventory file](#a1-1-master-and-1-node-on-single-network) for 1 master and 1 node (infra and user together) on single network
* [inventory file](#a2-3-masters-and-2-nodes-on-single-network) for 3 masters and 2 nodes (1 infra node and 1 user node) on single network
* [inventory file]() for 1 master and 1 node (infr and user together) on separated management and OpenShift networks
* [inventory file]() for 3 masters and 2 nodes (1 infra node and 1 user node) on separated management and OpenShift networks


## 4.2 Pre-deployment

#### CentOS
* Set /etc/hosts including all hosts in the cluster.
* Upgrade kernel on all nodes (kernel-3.10.0-693.21.1.el7.x86_64.rpm). 
* Add EPEL repo on all hosts.
```
yum install epel-release
yum repolist
```
* Configure insecure access in case of using private registry.

#### RHEL
* Set /etc/hosts including all hosts in the cluster.
* Upgrade kernel on all nodes (kernel-3.10.0-693.21.1.el7.x86_64.rpm). 
* Configure insecure access in case of using private registry.


## 4.3 Run playbooks

```
ansible-playbook \
    -i inventory/byo/poc.yml \
    inventory/byo/ose-prerequisites.yml

ansible-playbook \
    -i inventory/byo/poc.yml \
    playbooks/byo/openshift_facts.yml

ansible-playbook \
    -i inventory/byo/poc.yml \
    playbooks/byo/config.yml
```


## 4.4 Post-deployment

#### 1 Restart NTP service on all hosts.
```
systemctl restart ntpd
```

#### 2 Create user 'admin' and password.
```
oadm policy add-cluster-role-to-user cluster-admin admin
htpasswd -bc /etc/origin/master/htpasswd admin contrail123
```

#### 3 Check OpenShift web UI.

Open "https://<master address>:8443" to access OpenShift web UI.

#### 4 Enable distributed SNAT for k8s-default-pod-network.

* Update namespace 'default' with this annotation.
```
opencontrail.org/ip_fabric_snat: "true"
```

* Edit namespace 'default' to add the annotation.
```
oc edit namespace default
```

* Check it.
```
# oc get namespace default -o yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    opencontrail.org/ip_fabric_snat: "true"
    openshift.io/node-selector: ""
    openshift.io/sa.initialized-roles: "true"
    openshift.io/sa.scc.mcs: s0:c1,c0
    openshift.io/sa.scc.supplemental-groups: 1000000000/10000
    openshift.io/sa.scc.uid-range: 1000000000/10000
  creationTimestamp: 2018-06-02T22:54:19Z
  name: default
  resourceVersion: "28387"
  selfLink: /api/v1/namespaces/default
  uid: e23ea59d-66b7-11e8-9485-525400e197c0
spec:
  finalizers:
  - kubernetes
  - openshift.io/origin
status:
  phase: Active
```

* On Contrail web UI, update Configure -> Global Config -> Virtual Routers -> Forwarding Options to set "SNAT Port Translation Pools". For example, TCP 51000 - 52000, UDP 52000 - 53000.

#### 5 On all nodes (not masters), add an iptables rule after KUBE rules.
```
iptables -I INPUT 4 -j ACCEPT
```

```
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
KUBE-SERVICES  all  --  anywhere             anywhere             /* kubernetes service portals */
KUBE-FIREWALL  all  --  anywhere             anywhere            
KUBE-NODEPORT-NON-LOCAL  all  --  anywhere             anywhere             /* Ensure that non-local NodePort traffic can flow */
ACCEPT     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
ACCEPT     icmp --  anywhere             anywhere            
ACCEPT     all  --  anywhere             anywhere            
ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
OS_FIREWALL_ALLOW  all  --  anywhere             anywhere            
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited
```


# 5 Validate

## 5.1 pod

ubuntu.yaml
```
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu
  labels:
    app: ubuntu
spec:
  containers:
    - name: ubuntu
      image: ubuntu-upstart
```

Create pod.
```
oc create -f ubuntu.yaml
```

Check pod.
```
oc get pod ubuntu
```

Login pod to check address.

## 5.2 DNS

Login pod to check DNS and underlay connectivity.
```
ping google.com
wget google.com
```
Node host address is the DNS server address in pod (/etc/resovl.conf).

See "DNS query flow Condition in OpenShift 3.6" in https://www.redhat.com/en/blog/red-hat-openshift-container-platform-dns-deep-dive-dns-changes-red-hat-openshift-container-platform-36

## 5.3 Service

Create a replication controller with 2 pods.
```
apiVersion: v1
kind: ReplicationController
metadata:
  name: web
spec:
  replicas: 2
  selector:
    app: web
  template:
    metadata:
      name: web
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
```

Create a service.
```
kind: Service
apiVersion: v1
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Service name is web.default.svc.cluster.local. This name can be resolved in other pods.


# 6 OpenShift CI/DI

On OpenShift web UI, create a project 'portal'.

In project 'portal', browse catalog and select Python.



# Appendix A Inventory file

## A.1 1 master and 1 node on single network
```
[OSEv3:children]
masters
nodes
etcd

[OSEv3:vars]
ansible_ssh_user=root
ansible_become=yes
debug_level=2
#deployment_type=origin
deployment_type=openshift-enterprise
openshift_release=v3.7
containerized=false
openshift_install_examples=true
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]
osm_cluster_network_cidr=10.32.0.0/12
openshift_portal_net=10.96.0.0/12
openshift_use_dnsmasq=true
openshift_clock_enabled=true
openshift_hosted_manage_registry=true
openshift_hosted_manage_router=true
openshift_enable_service_catalog=false
openshift_use_openshift_sdn=false
os_sdn_network_plugin_name='cni'
openshift_disable_check=disk_availability,package_version,docker_storage

openshift_use_contrail=true
contrail_version=5.0
contrail_container_tag=5.0.0-0.40
contrail_registry=10.87.68.165:5100
#contrail_registry_username=<username>
#contrail_registry_password=<password>
vrouter_physical_interface=eth0
vrouter_gateway=10.84.29.254

[masters]
10.84.29.99 openshift_hostname=b7vm99

[etcd]
10.84.29.99 openshift_hostname=b7vm99

[nodes]
10.84.29.99 openshift_hostname=b7vm99
10.84.29.100 openshift_hostname=b7vm100 openshift_node_labels="{'region': 'infra'}"
```

## A.2 3 masters and 2 nodes on single network
```
[OSEv3:children]
masters
nodes
etcd
lb

[OSEv3:vars]
ansible_ssh_user=root
ansible_become=yes
debug_level=2
#deployment_type=origin
deployment_type=openshift-enterprise
openshift_release=v3.7
containerized=false
openshift_install_examples=true
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]
osm_cluster_network_cidr=10.32.0.0/12
openshift_portal_net=10.96.0.0/12
openshift_use_dnsmasq=true
openshift_clock_enabled=true
openshift_hosted_manage_registry=true
openshift_hosted_manage_router=true
openshift_enable_service_catalog=false
openshift_use_openshift_sdn=false
os_sdn_network_plugin_name='cni'
openshift_disable_check=disk_availability,package_version,docker_storage

openshift_use_contrail=true
contrail_version=5.0
contrail_container_tag=5.0.0-0.40
contrail_registry=10.87.68.165:5100
#contrail_registry=hub.juniper.net/contrail
#contrail_registry_username=<username>
#contrail_registry_password=<password>
vrouter_physical_interface=eth0
vrouter_gateway=10.84.29.254

[lb]
10.84.29.96 openshift_hostname=b7vm96

[masters]
10.84.29.97 openshift_hostname=b7vm97
10.84.29.98 openshift_hostname=b7vm98
10.84.29.99 openshift_hostname=b7vm99

[etcd]
10.84.29.97 openshift_hostname=b7vm97
10.84.29.98 openshift_hostname=b7vm98
10.84.29.99 openshift_hostname=b7vm99

[nodes]
10.84.29.97 openshift_hostname=b7vm97
10.84.29.98 openshift_hostname=b7vm98
10.84.29.99 openshift_hostname=b7vm99
10.84.29.100 openshift_hostname=b7vm100 openshift_node_labels="{'region': 'infra'}"
10.84.29.101 openshift_hostname=b7vm101
```

## A.3 1 master and 1 node on separated management and OpenShift networks

## A.4 3 masters and 2 nodes on separated management and OpenShift networks



```
#!/bin/bash


img_list="
contrail-analytics-alarm-gen:5.0.0-0.40
contrail-analytics-api:5.0.0-0.40
contrail-analytics-collector:5.0.0-0.40
contrail-analytics-query-engine:5.0.0-0.40
contrail-analytics-snmp-collector:5.0.0-0.40
contrail-analytics-topology:5.0.0-0.40
contrail-external-cassandra:5.0.0-0.40
contrail-external-kafka:5.0.0-0.40
contrail-external-rabbitmq:5.0.0-0.40
contrail-external-zookeeper:5.0.0-0.40
contrail-controller-config-api:5.0.0-0.40
contrail-controller-config-devicemgr:5.0.0-0.40
contrail-controller-config-schema:5.0.0-0.40
contrail-controller-config-svcmonitor:5.0.0-0.40
contrail-controller-control-control:5.0.0-0.40
contrail-controller-control-dns:5.0.0-0.40
contrail-controller-control-named:5.0.0-0.40
contrail-controller-webui-job:5.0.0-0.40
contrail-controller-webui-web:5.0.0-0.40
contrail-kubernetes-cni-init:5.0.0-0.40
contrail-kubernetes-kube-manager:5.0.0-0.40
contrail-nodemgr:5.0.0-0.40
contrail-vrouter-agent:5.0.0-0.40
contrail-vrouter-kernel-init:5.0.0-0.40"

for img in $img_list; do
    docker pull hub.juniper.net/contrail/$img
    docker tag hub.juniper.net/contrail/$img localhost.localdomain:5100/$img
    docker push localhost.localdomain:5100/$img
    docker rmi -f hub.juniper.net/contrail/$img
    docker rmi -f localhost.localdomain:5100/$img
done
```

```
#!/bin/bash

docker pull 10.87.68.165:5100/contrail-nodemgr:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-kubernetes-kube-manager:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-external-zookeeper:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-external-rabbitmq:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-external-kafka:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-external-cassandra:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-webui-web:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-webui-job:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-control-named:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-control-dns:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-control-control:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-config-svcmonitor:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-config-schema:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-config-devicemgr:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-controller-config-api:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-analytics-query-engine:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-analytics-collector:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-analytics-api:5.0.0-0.40
docker pull 10.87.68.165:5100/contrail-analytics-alarm-gen:5.0.0-0.40
```

