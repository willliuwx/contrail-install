
# 1 Overview

This is to deploy Contrail 5.0-122 and OpenShift 3.9 with RHEL based Contrail containers on RHEL 7.5.

All VMs are based on RHEL cloud image `rhel-server-7.5-x86_64-kvm.qcow2` with the following customizations.
* set hostname
* set /etc/hosts
* enable root password
* disable cloud-init
* SSH server
* configure networking
* relabel SELinux

# 2 Builder

For a clearner deployment, have a separated server as the builder to run Ansible playbook.

#### Register system
```
subscription-manager register
subscription-manager attach --auto
subscription-manager repos \
    --enable rhel-7-server-extras-rpms \
    --enable rhel-7-server-ansible-2.4-rpms
```

#### Create SSH key
```
ssh-keygen
```

Create `.ssh/config`.
```
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

#### Install packages
```
yum install -y python-netaddr ansible
```
Ansible version is 2.4.6.0 (ansible-2.4.6.0-1.el7ae.noarch).



# 3 Registry

Alternatively build an insecured private registry to host container images, on the builder.

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

#### Pull container image
Once container images are released, they will be available on hub.juniper.net/contrail. For beta, need to load image from file.

#### Push container image
After pull images from public registry or load from file, tag images and push them to private registry.


# 4 Inventory

## 4.1 2-server
The minimum deployment is with 2 servers, one master and one node.


## 4.2 HA
An example of HA deployment is with 1 loadbalancer, 3 masters, 2 infrastructure nodes and 2 tenant nodes.



# 5 Deploy

```
cd openshift-ansible
ansible-playbook \
    -i inventory/<inventory> \
    playbooks/prerequisites.yml

ansible-playbook \
    -i inventory/<inventory> \
    playbooks/deploy_cluster.yml
```

# 6 Post installation


