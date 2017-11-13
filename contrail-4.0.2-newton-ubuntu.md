
# 1 Context

#### Contrail version
Contrail 4.0.2-35 Newton Xenial

#### Package
contrail-cloud-docker_4.0.2.0-35-newton_xenial.tgz
contrail-server-manager-installer_4.0.2.0-35~newton_all.deb

#### Host OS
* Ubuntu 16.04.2 LTS with kernel 4.4.0-62-generic.
* Ubuntu 16.04.3 LTS with kernel 4.4.0-87-generic.

With Ubuntu 16.04.3, due to package dependency, libnl-3-200 needs to be downgraded on compute node.
```
apt-get install libnl-3-200=3.2.27-1
```

In case Ubuntu 16.04.3 is used as KVM hypervisor to run controller VMs, it's required to reinstall pyOpenSSL for libvirt.
```
apt install pyton-pip
pip install --upgrade pip
pip uninstall pyOpenSSL
pip install pyOpenSSL
```

#### Nodes
* 1 Server Manager
* 3 Controllers (Contrail and OpenStack)
* 1 Contrail Loadbalancer
* 1 Compute

#### Prerequisites
* Access to public Ubuntu repo (python, python-apt, python-dev, etc.)
* SSH key
* Networking
* hosts and DNS
* NTP


# 2 Server Manager

Install server manager lite. Package python-dev is required but not included in SM installation package. If it's not pre-installed, access to public repo is required, and it will take a few more minutes to update apt repo and install python-dev package. Otherwise, argument "--no-external-repos" can be used for setup.sh to not setup public repo.
```
dpkg -i contrail-server-manager-installer_4.0.2.0-35~newton_all.deb
cd /opt/contrail/contrail_server_manager
./setup.sh --all --smlite
```
Web UI is on port 9080.


# 3 JSON Files

## 3.1 Image of Contrail

Add image of Contrail package. The command takes a few minutes to unpack the image. Then, in background, it takes a while (about 30 minutes) for SM to create registry container and load all container images into registry. Run "server-manager display image" to check if the image is completely loaded.
```
server-manager add image --file_name contrail-pkg.json
```

Here is an example of image JSON file.
```
{
"image": [
    {
        "category": "package",
        "id": "newton_400_20",
        "path": "contrail-cloud-docker_4.0.0.0-20-newton_xenial.tgz",
        "type": "contrail-ubuntu-package",
        "version": "400_20"
    }
]
}
```
Note, the image ID can not begin with a number and can only contain alphanumeric and '_'.


## 3.2 Cluster

Add cluster.
```
server-manager add cluster --file_name cluster.json
```

Contrail LB container(HAProxy, without keepalived) has to be on a separate server from controllers. It provides LB for only configuration and analytics services (not for web UI and any other services). Only one Contrail LB container is supported. The Contrail VIP has to be the address of the host running Contrail LB container.


### Server
Add server.
```
server-manager add server --file_name server.json
```


### Pre-configure
Pre-configure all servers to make them ready for deployment.
```
/opt/contrail/server_manager/client/preconfig.py \
    --server-json server.json --server-manager-ip 10.87.68.165
```


### Provision

```
server-manager provision --cluster_id poc1 newton_402_35_xenial
```


