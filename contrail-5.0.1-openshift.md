
# 1 Overview

This is to deploy OpenShift and Contrail 5.0.1-0.214.
* OpenShift Enterprise 3.9 with RHEL 7 based Contrail containers on RHEL 7.5 host
* OpenShift Origin 3.9 with CentOS 7 based Contrail containers on CentOS 7.5 host

## 1.1 Host prerequisites

#### RHEL

All VMs are based on RHEL cloud image `rhel-server-7.5-x86_64-kvm.qcow2` with the following customizations.
* Set hostname (/etc/hostname).
* Enable root password.
* Disable cloud-init service.
* Update SSH server configuration to allow login as root.
* Set `/root/.ssh/authorized_keys` if using existing SSH key. Or this can be done later when building the builder.
* Configure networking.
* Set timezone.
* Install NTP package, and enable the service.
* Build `/etc/hosts` with all hosts in the cluster.
* Relabel SELinux.

#### CentOS


## 1.2 Host spec

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


# 2 Builder

For a clearner deployment, have a separated server as the builder to run Ansible playbook and optionally run private registry. For minimum deployment, the builder and the master can stay together on the same host.

#### RHEL
Register system and enable repositories.
```
subscription-manager register
subscription-manager attach --auto
subscription-manager repos \
    --enable rhel-7-server-extras-rpms \
    --enable rhel-7-server-ansible-2.5-rpms
```


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

```
yum install -y python-netaddr ansible
```
Ansible version 2.5.6-1.el7ae from repo `rhel-7-server-ansible-2.5-rpms`.


## 2.3 Playbook

Download OpenShift Deployer package 5.0.1 from [Juniper site](https://www.juniper.net/support/downloads/?p=contrail#sw).
```
tar xzf contrail-openshift-deployer-5.0.1-0.214.tgz
```

## 2.4 Registry

Alternatively build an insecured private registry to host Contrail container images, on the builder.

#### Install Docker
```
yum install -y docker
systemctl enable docker
systemctl start docker
```
Docker version is 1.13.1.

#### Launch registry container
```
docker pull registry
docker run -d --env REGISTRY_HTTP_ADDR=0.0.0.0:5100 \
    --restart always --net host --name registry registry
```

#### Build registry
Once container images are released, they will be available on hub.juniper.net/contrail. For beta, need to load image from file.

After pull images from public registry or load from file, tag images and push them to private registry.


# 3 Deploy

## 3.1 Inventory

* [inventory file](#a1-1-master-and-2-nodes-on-single-network) for 1 master and 2 nodes (1 infra and 1 user) on single network
* [inventory file](#a2-3-masters-and-2-nodes-on-single-network) for 3 masters and 2 nodes (1 infra node and 1 user node) on single network
* [inventory file]() for 1 master and 2 nodes (1 infr and 1 user) on separated management and OpenShift networks
* [inventory file]() for 3 masters and 2 nodes (1 infra node and 1 user node) on separated management and OpenShift networks


## 3.2 Pre-deployment

Make sure all customizations in [1 Overview](#1-overview) are done prior to running playbooks.

#### RHEL
All RHEL hosts have to be registered and repos have to be enabled prior to deployment.

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

* Enable yum repo for OpenShift Enterprise 3.9.
```
subscription-manager repos \
    --enable rhel-7-server-rpms \
    --enable rhel-7-server-extras-rpms \
    --enable rhel-7-server-ose-3.9-rpms \
    --enable rhel-7-fast-datapath-rpms
```


In case SSH key is new, copy it to all hosts in the cluster.
```
ssh-copy-id root@<host>
```


## 3.3 Run playbooks

```
cd openshift-ansible
ansible-playbook -i inventory/<inventory> playbooks/prerequisites.yml
ansible-playbook -i inventory/<inventory> playbooks/deploy_cluster.yml
```

## 3.4 Post-deployment

#### DNS on master
Right after playbook was completed, `dnsmasq` doesn't work properly on master. External name can't be resolved. Need to restart it to make it work.
```
systemctl restart dnsmasq
```

#### NTP service
Install and enable NTP service on all hosts.
```
yum install -y ntp
systemctl enable ntpd
systemctl start ntpd
```

In case NTP package is already installed, for some reason, deployment crashed NTP service. Need to check and restart it on all hosts.
```
systemctl restart ntpd
```

#### Coredump pattern
Set coredump pattern on all nodes (not master). This is required by `nodemgr` to detect coredump.
```
echo "/var/crashes/core.%e.%p.%h.%t" > /proc/sys/kernel/core_pattern
```

#### Default floating IP pool
Make sure the default FIP pool exist in Contrail.

Configure default FIP pool for kube-manager.
```
oc edit configmap kube-manager-config -n kube-system
```

Add this line in `data`.
```
KUBERNETES_PUBLIC_FIP_POOL: "{'domain': 'default-domain', 'project': 'k8s-default', 'network': 'public', 'name': 'default'}"
```

Remove the container, OpenShift will re-create it with updated environment.
```
id=$(docker ps | awk "/k8s_contrail-kube-manager/"'{print $1}'); \
    docker stop $id; \
    docker rm $id
```

#### OpenShift authentication
Create user `admin` and password.
```
oc adm policy add-cluster-role-to-user cluster-admin admin
htpasswd -bc /etc/origin/master/htpasswd admin contrail123
```
In case of HA, this has to be done on all masters.

#### Ingress/External IP address
When create a `LoadBalancer` type of service, OpenShift will allocate external IP address by default from 172.46.0.0/16. With Contrail, the external address (VIP of loadbalancer) will be allocated from the default floating IP pool configured for kube-manager, or from user specified floating IP pool. To disable OpenShift allocating external address, add this line to `networkConfig` section in `/etc/origin/master/master-config.yaml` and restart `atomic-openshift-master-controllers` service.
```
ingressIPNetworkCIDR: 0.0.0.0/32
```

#### OpenShift web console
Update service type to `NodePort` on port 30443.
```
oc edit service webconsole -n openshift-web-console
```
```
spec:
  clusterIP: 10.97.8.137
  externalTrafficPolicy: Cluster
  ports:
  - name: https
    nodePort: 30443
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    webconsole: "true"
  sessionAffinity: None
  type: NodePort
```

Update `consolePublicURL` and `masterPublicURL` using IP address, instead of name.
```
oc edit configmap webconsole-config -n openshift-web-console
```
```
      consolePublicURL: https://<infra node IP address>:30443/console/
      masterPublicURL: https://<master IP address>:8443
```

Update `/etc/origin/master/master-config.yaml`.
```
# Add infra node IP address.
corsAllowedOrigins:
- (?i)//10\.84\.29\.100(:|\z)
# Set redirect URL for web console and master public URL.
oauthConfig:
  assetPublicURL: https://10.84.29.100:30443/console/
  masterPublicURL: https://10.84.29.97:8443
```

Restart master service.
```
systemctl restart atomic-openshift-master-api
```

#### Firewall rule for NodePort
Due to the issue [https://github.com/kubernetes/kubernetes/issues/39823](https://github.com/kubernetes/kubernetes/issues/39823), which is fixed by the pull [https://github.com/kubernetes/kubernetes/pull/52569](https://github.com/kubernetes/kubernetes/pull/52569), the quick workaround is to add a rule on all nodes.
```
iptables -I FORWARD 2 -j ACCEPT
```

#### Firewall rule for DNS
DNS server in pod is set to local node host address. DNS request from pod inside is sent to vrouter who passes to the node host. On each node, firewall rule is required to allow such traffic.
```
iptables -I INPUT 4 -j ACCEPT -p udp --dport 53
```


# 4 Validate

#### Contrail web UI
Use browser open `https://<master>:8143`. User name is `admin`. Password is `contrail123`. This is the default password.


#### OpenShift web console
Use browser open `https://<infra node>:30443`. User name is `admin`. Password is whatever set by `htpasswd`.


#### Unisolated project
```
apiVersion: v1
kind: Namespace
metadata:
  name: demo
```
Check Contrail for the new project.


#### Isolated project
```
apiVersion: v1
kind: Namespace
metadata:
  name: private
  annotations: {
    opencontrail.org/isolation: "true"
  }
```
Check Contrail for the new project and virtual network.


#### User pod
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
```
Login the pod, check networking.


#### Replication controller

Pod `nginx` needs permission to set GID. Otherwise, "oc logs" shows error message.
```
setgid(101) failed (1: Operation not permitted)
```

Add service account to SCC `anyuid`. This allows `nginx` pod to set GID. Here is an example.
```
oc adm policy add-scc-to-user anyuid system:serviceaccount:demo:default
```
[understanding-service-accounts-sccs](https://blog.openshift.com/understanding-service-accounts-sccs)

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
Check pod.


#### Service with ClusterIP

`ClusterIP` is the default type of service.
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
  type: ClusterIP
```
Check cluster IP address.

Check service name `web.demo.svc.cluster.local` resolving on both all master hosts and node hosts.

Check connectivity to service by either name or cluster address from user pod.


#### Service with LoadBalancer
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
  type: LoadBalancer
```
An external address is allocated from default floating IP pool.

Use annotation to allocate external address from specific floating IP pool. FIP can also be specified. Here is an example.
```
kind: Service
apiVersion: v1
metadata:
  name: web
  annotations:
    "opencontrail.org/fip_pool": '{"domain": "default-domain", "project": "k8s-demo", "network": "demo-pool", "name": "default"}'
spec:
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
  externalIPs:
  - 10.100.1.8
```


#### Service with NodePort
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
  type: NodePort
```


# Appendix

## A.1 1 master and 2 nodes on single network
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
openshift_release=v3.9
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
openshift_web_console_install=true
openshift_web_console_nodeselector={'region': 'infra'}
openshift_use_openshift_sdn=false
os_sdn_network_plugin_name='cni'
openshift_disable_check=disk_availability,package_version,docker_storage

contrail_registry=10.87.68.165:5100
openshift_docker_insecure_registries=10.87.68.165:5100
#contrail_registry=hub.juniper.net/contrail
#contrail_registry_username=
#contrail_registry_password=
openshift_use_contrail=true
contrail_version=5.0
contrail_container_tag=5.0.1-0.214-rhel-queens
vrouter_physical_interface=eth0
vrouter_gateway=10.84.29.254

[masters]
10.84.29.97 openshift_hostname=b7vm97

[etcd]
10.84.29.97 openshift_hostname=b7vm97

[nodes]
10.84.29.97 openshift_hostname=b7vm97
10.84.29.100 openshift_hostname=b7vm100 openshift_node_labels="{'region': 'infra'}"
10.84.29.101 openshift_hostname=b7vm101
```



