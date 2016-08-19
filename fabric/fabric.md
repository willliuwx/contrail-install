# Contrail Only

* [Contrail 3.0.2.0-51 on CentOS 7.0.1406](#2.2-contrail-3.0.2.0-51-on-centos-7.0.1406)
* [Contrail 3.0.2.0-51 on CentOS 7.2.1511](#2.3-contrail-3.0.2.0-51-on-centos-7.2.1511)

#1 Contrail on Ubuntu

##1.1 Pre-Check

* Networking configuration
* Resolvable hostname, `ping $(hostname)`
* NTP service


##1.2 Contrail 3.0 on Ubuntu 14.04

###1.2.1 Version

* Ubuntu: 14.04.2
* Kernel:
* Contrail: contrail-install-packages_3.0.0.0-2723~ubuntu-14-04kilo_all.deb


###1.2.2 Install

* Copy Contrail installation package to the builder.

* If builder is a server in the cluster.
```
# dpkg -i <package>
# cd /opt/contrail/contrail_packages
# ./setup.sh
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py. Here is an [example](testbed-contrail-only.py).

* Apply the [patch](fabfile-3.0-2723.diff).

* Run fab commands.
```
# cd /opt/contrail/utils
# fab install_pkg_all_without_openstack:<package>
# fab install_without_openstack:manage_nova_compute='no'
# fab setup_without_openstack:manage_nova_compute='no',config_nova='no'
```

#2 Contrail on CentOS

##2.1 Pre-Check

* Configure networking.
* Update `/etc/hostname` with the hostname, ensure `ping $(hostname)` work.
* Enable NTP service, ensure the connection to NTP server.
* Disable SELinux by updating `/etc/sysconfig/selinux` or `/etc/selinux/config`.
* Disable firewall.


##2.2 Contrail 3.0.2.0-51 on CentOS 7.0.1406

###2.2.1 Version

* CentOS: CentOS Linux release 7.0.1406 (Core)
* Kernel: 3.10.0-123.el7.x86_64
* Contrail: contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm


###2.2.2 Install

* Copy Contrail installation package to the builder.

* Install the package.
```
rpm -ivh contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm
```

* Setup local repo.
```
cd /opt/contrail/contrail_packages/
./setup.sh
```

* Upgrade some packages.
```
yum install java-1.8.0-openjdk-headless
yum install lvm2-2.02.130
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Here is an [example](testbed-contrail-only.py).

* Install Contrail package on all nodes.
```
cd /opt/contrail/utils
fab install_pkg_all_without_openstack:<Contrail package>
```
This step is not required for single-node deployment.

* Install Contrail.
```
fab install_without_openstack
```

* Update /etc/cassandra/conf/cassandra-env.sh.
MaxTenuringThreshold=15

* Setup Contrail
```
fab setup_without_openstack
```

##2.3 Contrail 3.0.2.0-51 on CentOS 7.2.1511

###2.3.1 Version

* CentOS: CentOS Linux release 7.2.1511 (Core)
* Kernel: 3.10.0-327.el7.x86_64
* Contrail: contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm

###2.3.2 Install

* Copy Contrail installation package to the builder.

* Install the package.
```
rpm -ivh contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm
```

* Setup local repo.
```
cd /opt/contrail/contrail_packages/
./setup.sh
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Here is an [example](testbed-contrail-only.py).

* Install Contrail package on all nodes.
```
cd /opt/contrail/utils
fab install_pkg_all_without_openstack:<Contrail package>
```
This step is not required for single-node deployment.

* Install Contrail.
```
fab install_without_openstack
```

* Setup Contrail
```
fab setup_without_openstack
```



### Web UI local authentication
Update /etc/contrail/config.global.js.
```
config.staticAuth = [];
config.staticAuth[0] = {};
config.staticAuth[0].username = 'admin';
config.staticAuth[0].password = 'admin';
config.staticAuth[0].roles = ['superAdmin'];
```

Restart Web UI services.
```
# service supervisor-webui restart
```



