
# 1 Overview

#### Version
* Contrail 4.1.0-8
* RedHat 7.3

#### VM spec
* 6 vCPUs
* 48GB memory
* 100GB disk, no swap, single partition

#### 6 VMs allocation
* 1 builder/lb, run Ansible playbook to install the cluster and loadbalancer HAProxy.
* 3 master/controller, OpenShift master and Contrail controller.
* 2 node, OpenShift node and Contrail vrouter.


# 2 Builder

Ensure SSH root access by password is allowed. Then run the script as root to get all servers ready.
* Enable SSH key.
* Enable SELinux.
* Populate /etc/hosts.
* Register server and setup repo.
* Add EPEL repo.

Install packages on the builder to run Ansible playbook.
```
yum install -y \
    atomic-openshift-excluder \
    atomic-openshift-utils \
    python-netaddr \
    git
atomic-openshift-excluder unexclude -y
```

Copy Contrail package contrail-kubernetes-docker-images_4.1.0.0-8.tgz to the builder /tmp directory.

Clone playbook.
```
git clone https://github.com/savithruml/openshift-ansible -b contrail-openshift
git clone https://github.com/savithruml/openshift-contrail
cp openshift-contrail/openshift/install-files/all-in-one/ose-prerequisites.yml openshift-ansible/inventory/byo/
cp openshift-contrail/openshift/install-files/all-in-one/ose-install openshift-ansible/inventory/byo/
```

Update inventory file openshift-ansible/inventory/byo/ose-install.


Run playbooks.
```
cd openshift-ansible
ansible-playbook -i inventory/byo/ose-install inventory/byo/ose-prerequisites.yml
ansible-playbook -i inventory/byo/ose-install playbooks/byo/openshift_facts.yml
ansible-playbook -i inventory/byo/ose-install playbooks/byo/config.yml
```

The port for BGP peering between CNs is not opened. Need to add iptable rule to open them. Those ports seem to be dynamic, needs to open the range.

In case vrouter is on VM, it's nested vitualization. Due to an issue in vrouter, TX offload has to be turned off on vrouter underlay/physical interface.
```
ethtool -K <interface> tx off
```

Kube-manager needs to be brought up manually, due to the timeout issue (due to kernel difference), which is fixed in 5.0.


# issue, in 4.1, a new feature is added to support kubernetes liveness probe, a policy is attached to cluster-network to leak route to ip-fabric. Because of a bug, when enable SNAT, the default route in VN pointing to public network is also leaked to ip-frabric (due to the policy), that cause underlay connection down. to make SNAT work for OpenShift CI/CI, the policy ip-fabric-cluster-network-default is detached from cluster network (disable liveness probe).

Export info.
```
oc get deploymentconfigs/docker-registry -o yaml  > docker-registry.yaml
oc get deploymentconfigs/registry-console -o yaml  > registry-console.yaml
```

Save YAML files to /root/openshift-infra-pods.

Delete those things.
```
oc delete deploymentconfigs/docker-registry
oc delete deploymentconfigs/registry-console
```
Once this is done, edit the YAML files and remove the liveness/readiness probes section

then recreate the deployments:
```
oc create -f registry-console.yaml
oc create -f docker-registry.yaml 
```

Set label for region 'infra' where registry and console will be launched.
```
oc label node 5b4-vm174 region=infra
```

disable scheduling on infra nodes.
```
oadm manage-node 5b4-vm174 --schedulable=false
```

In Contrail, create "router" for SNAT. Attch cluster-network onto "router".
All containers have SNAT to internet.


build CI/CD
* Create a project on OpenShift web UI.

Ensure "cluster.local" is in the search list in /etc/resolv.conf.
Ensure all name resolving work.
```
search cluster.local
```



steps done till now:

1) Install OpenShift + Contrail

2) Once install is complete label one node with "region=infra" so that docker-registry, registry-console, router (openshift infra pods) are launched here

3) Router will come up fine, but not the other two. Hence save & delete the deployment/registry-console & deployment/docker-registry

oc get deployment/registry-console -o yaml > registry-console.yaml
oc get deployment/docker-registry -o yaml > docker-registry.yaml

oc delete deployment/registry-console
oc delete deployment/docker-registry

4) Next, edit the YAMLs to remove liveness, readiness probes

5) Set hostNetwork: true in docker-registry.yaml

6) Launch docker-registry & registry-console

oc create -f registry-console.yaml
oc create -f docker-registry.yaml

7) Remove policy from cluster-network in Contrail Web-UI

8) Enable SNAT & associate cluster-network

9) Test if pods can reach out to the internet

10) Turn off tx nic offload



```
#!/bin/bash

host_list="
    10.87.68.170
    10.87.68.171
    10.87.68.172
    10.87.68.173
    10.87.68.174
    10.87.68.175"

copy()
{
    for host in $host_list
    do
        scp /etc/selinux/config $host:/etc/selinux
    done
}


update_sshd_config()
{
    for host in $host_list
    do
        scp /etc/ssh/sshd_config $host:/etc/ssh
        ssh $host \
            service sshd restart
    done
}

enable_ssh_key()
{
    ssh-keygen -t rsa
    for host in $host_list
    do
        ssh-copy-id $host
    done
}

enable_selinux()
{
    for host in $host_list
    do
        ssh $host \
            sed -i -e 's/^SELINUX=.*/SELINUX=enforcing/g' /etc/selinux/config 
    done
}

set_hosts()
{
    for host in $host_list
    do
        scp /etc/hosts $host:/etc/
    done
}

register()
{
    for host in $host_list
    do
        ssh $host \
            subscription-manager register \
                --username contrail.systems \
                --password Embe1mpls_007 \
                --force
    done
}

set_repo()
{
    for host in $host_list
    do
        ssh $host \
            subscription-manager attach --pool=8a85f98c5f0117b2015f0f27aed92cd9
        ssh $host \
            subscription-manager repos --disable="*"
        ssh $host \
            subscription-manager repos \
                --enable="rhel-7-server-rpms" \
                --enable="rhel-7-server-extras-rpms" \
                --enable="rhel-7-server-ose-3.7-rpms" \
                --enable="rhel-7-fast-datapath-rpms"
    done
}

install_pkg()
{
    for host in $host_list
    do
        ssh $host \
            yum install -y wget
        ssh $host \
            wget -O /tmp/epel-release-latest-7.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        ssh $host \
            rpm -ivh /tmp/epel-release-latest-7.noarch.rpm
    done
}


update_sshd_config
enable_ssh_key
enable_selinux
set_hosts
register
set_repo
install_pkg
```

