# 1 Introduction

This is the guide for integrating Contrail with Kubernetes.

Versions:
* CentOS 7.3
* Contrail 4.0.0.0-20
* Kubernetes 1.7.1

# 2 Builder

Builder is where Ansible playbook runs to deploy Contrail. It's recommended to have a separate server as the builder.

## 2.1 Private repo

In case the environment doesn't have access to public repo, a private repo is required to hold all packages. It's recommended to build private repo on the builder.

See [Appendix A Private repo](#appendix-a-private-repo) for details.

## 2.2 Ansible

Ansible used in this guide is 2.3.0.0.

If there is old version, need to remove it with all modules and install the new version.
```
yum erase ansible
mv /usr/lib/python2.7/site-packages/ansible /usr/lib/python2.7/site-packages/ansible.old
yum install ansible
```

## 2.3 Playbook

Unpack playbook package contrail-ansible-4.0.0.0-20.tar.gz.
```
mkdir contrail-ansible
tar -C contrail-ansible -xzf contrail-ansible-4.0.0.0-20.tar.gz
```

## 2.4 Inventory file

Create inventory file playbooks/inventory/kubernetes.ini.

See [Appendix B Inventory file](#appendix-b-inventory-file)

## 2.5 Container image

Copy container images to playbooks/container_images directory. With Contrail 4.0.0.0, Ubuntu trusty (14.04) based container is used for CentOS host.
```
contrail-agent-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analyticsdb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-analytics-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-controller-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-kube-manager-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-lb-ubuntu14.04-4.0.0.0-20.tar.gz
contrail-vrouter-compiler-centos7-4.0.0.0-20.tar.gz
```


# 3 Kubernetes

## 3.1 Install with kubeadm

[Bootstrapping Clusters with kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/)

Install Docker. Version 1.12 is recommended.
```
yum install docker
```

Add Kubernete repo /etc/yum.repos.d/kubernetes.repo.
```
[kubernetes]
name=Kubernetes
baseurl=http://yum.kubernetes.io/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
    https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
```

Ensure SELinux is disabled or permissive.
```
sestatues
setenforce 0
```

Install packages.
```
yum install -y kubelet kubeadm

systemctl enable docker
systemctl start docker
```

Determine service address pool. The default is 10.96.0.0/12.

Update /etc/systemd/system/kubelet.service.d/10-kubeadm.conf.
* On the master, comment or remove the KUBELET_NETWORK_ARGS.
* Update cluster-dns address if service address pool is not default.

Enable and start kubelet.
```
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
```

Provision the master. Argument --service-cidr can be used if the service address pool is not the default.
```
kubeadm init
```

Disable firewall or add rule to open the port.
```
systemctl disable firewalld
systemctl stop firewalld
```

Provision all compute nodes. The 'join' command is from the output of master provisioning.
```
kubeadm join --token <token> <master-ip>:<master-port>
```

On the master, enable the insecure-port in /etc/kubernetes/manifests/kube-apiserver.yaml. And restart kubelet.
```
     - --secure-port=6443
     - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
+    - --insecure-port=8080
+    - --insecure-bind-address=0.0.0.0
```

```
service kubelet restart
```

On the master, add KUBECONFIG.
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
```

## 3.2 Install Manually
[Manual installation on CentOS](https://kubernetes.io/docs/getting-started-guides/centos/centos_manual_config/)


# 4 Contrail

## 4.1 Pre-deployment

### 4.1.1 SSH Key

For Ansible to access all hosts with SSH key, place private key on the builder and add public key to .ssh/authorized_keys on all hosts.

### 4.1.2 Private repo

If private repo is required, add private repo to all hosts.

See [Appendix A Private repo](#appendix-a-private-repo) for details.

### 4.1.3 Docker

Docker is installed as part of Kubernetes installation by kubeadm, but manual installation doesn't require Docker.

Install Docker now if it's not installed yet. Docker version used by this guide is 1.12.6.

Note: If Docker 1.12.1 exists on host, it works fine, no need to upgrade. Ensure Docker is running.

In case to upgrade/install Docker from the private repo, remove some packages that cause dependency issue, then install Docker.
```
yum erase libselinux-devel libselinux-utils libsepo-devel libsepol-devel
yum install docker
systemctl enable docker
systemctl start docker
```

Check Docker cgroup driver by "docker info | grep cGroup". If it's cgroupfs (existing Docker), no update required. If it's systemd (upgraded Docker), "--cgroup-driver=systemd" has to be added into command line in /usr/lib/systemd/system/kubelet.service.

Note, adding arguments into KUBELET_ARGS in /etc/kubenetes/kubelet doesn't take effect, even after "system daemon-reload" and "ps ax | grep kubelet" shows the argument, it just has no effect.

### 4.1.4 NTP

NTP service is required by Contrail on all hosts. In case no NTP service is available in the closed environment, set standalong NTP server on each host.

Install NTP service.
```
yum install ntp
```

Update /etc/ntp.conf.
```
server 127.127.1.0
fudge 127.127.1.0 stratum 8
```

Enable and start NTP service.
```
systemctl enable ntpd
systemctl start ntpd
```

Verify NTP service.
```
ntpq -p
```

### 4.1.5 Kernel

On compute node, kernel used in this guide is 3.10.0-514.21.1.el7.x86_64. Package kernel-devel and kernel-headers are also required to compile vrouter kernel module.

This upgrade is only required for CentOS 7.2, not for CentOS 7.3.

### 4.1.6 Flannel network

If flannel network is already deployed with Kubernetes, it needs to be removed.
```
systemctl stop flannel
systemctl disable flannel
systemctl restart docker
```

The flannel0 interface doesn't have a link address.
```
6: flannel0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1472 qdisc pfifo_fast state UNKNOWN mode DEFAULT qlen 500
    link/none 
```

It causes problem when hitting this line in /usr/lib/python2.7/dist-packages/contrail_vrouter_provisioning/network.py in vrouter agent container. It only happens when vhost0 interface is already created.
```
            dev_mac = netifaces.ifaddresses(i)[netifaces.AF_LINK][0]['addr']
```

### 4.1.7 Insecured access

Ensure insecured access is enabled in /etc/docker/daemon.json.
```
{ "insecure-registries":["192.168.189.143:44380"] }
```

```
service kubelet restart
```

### 4.1.8 Hostname

Update /etc/kubenetes/kubelet to remove argument '--hostname-override'. Contrail needs to know the compute node hostname to locate vrouter and link container (VM object) to that vrouter. So control node can push configuration to that vrouter.
```
#NODE_HOSTNAME="--hostname-override=192.168.189.136"
```


## 4.2 Deploy

Run playbook.
```
ansible-playbook -i inventory/kubernetes.ini site.yml
```

## 4.3 Post-deployment

### 4.3.1 kubenetes-cni

Install kubnetes-cni package. Or just extract kubernets-cni.tgz to /opt/cni/bin directory.

### 4.3.2 CNI

Update /usr/lib/systemd/system/kubelet.service to add CNI arguments. Note, adding arguments to /etc/kubenetes/kubelet has no effect.
```
                    ${KUBELET_ARGS} \
+                   --network-plugin=cni \
+                   --cni-conf-dir=/etc/cni/net.d \
+                   --cni-bin-dir=/opt/cni/bin \
                    --cadvisor-port 4194 \
                    ${KUBELET_INFRA}
```

Restart kubelet service.
```
systemctl daemon-reload
systemctl restart kubelet
systemctl status kubelet -l
```

## 4.4 Validate

Since private registry is not ready, load Docker images onto compute node.
```
docker load < nginx.tar.gz
docker load < pause.tar.gz
```

Create pod yaml files on the master and launch them.
```
kubectl create -f web-1.yaml
kubectl create -f web-2.yaml
```

web-1.yaml
```
apiVersion: v1
kind: Pod
metadata:
  name: web-1
spec:
  containers:
  - name: web
    image: docker.io/nginx
    imagePullPolicy: IfNotPresent
```

Check networking in pod and ping each other.
```
kubectl exec web-1 ip addr
kubectl exec web-2 ip addr
kubectl exec web-1 ping <address of web-2>
```


# Appendix A Private repo

## A.1 Build private repo

Required packages have to be collected on a server who has access to public repo. Enable package cache by setting "keepcache=1" in /etc/yum.conf. Install all required packages and they will be cached in /var/cache/yum/86_64/7/<repo>/packages directory.

Install createrepo package.
```
yum install createrepo
```

Create a private repo dictory and copy packages from cache there. Then create the private repo.
```
createrepo /path/to/private-repo
```

Copy private repo to builder.

Install httpd on the builder.

Create a link to private repo.
```
ln -s /path/to/private-repo /var/www/html/private
```

## A.2 Add private repo

Create /etc/yum.repos.d/private.repo.
```
[private]
baseurl = http://<builder address>/private
enabled = 1
gpgcheck = 0
name = private
priority = 99
```

Refresh yum data.
```
yum clean all
yum repolist
```

# Appendix B Inventory file
```
[contrail-controllers]
192.168.189.131

[contrail-analytics]
192.168.189.131

[contrail-analyticsdb]
192.168.189.131

[contrail-kubernetes]
192.168.189.131

[contrail-compute]
192.168.189.137

[all:vars]
docker_install_method = package
ansible_user = root

cloud_orchestrator = kubernetes
contrail_compute_mode = container
vrouter_physical_interface = eno49

os_release = ubuntu14.04
contrail_version = 4.0.0.0-20

webui_config = {'http_listen_port': '8085'}


kubernetes_pod_subnet = 10.10.0.0/16
kubernetes_service_subnet = 10.80.0.0/16
kubernetes_cluster_project = {'domain': 'default-domain', 'project': 'kubernetes'}
kubernetes_public_fip_pool = {'domain': 'default-domain', 'project': 'kubernetes', 'network': 'public', 'name': 'default'}

```


