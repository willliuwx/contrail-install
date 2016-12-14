# Contrail Only

* [Contrail 3.0.2.0-51 on CentOS 7.0.1406](#22-contrail-3020-51-on-centos-701406)
* [Contrail 3.0.2.0-51 on CentOS 7.2.1511](#23-contrail-3020-51-on-centos-721511)
* [Contrail 3.1.0.0-25 on CentOS 7.2.1511](#24-contrail-3100-25-on-centos-721511)

# 1 Contrail on Ubuntu

## 1.1 Pre-Check

* Networking configuration
* Resolvable hostname, `ping $(hostname)`
* NTP service


## 1.2 Contrail 3.0 on Ubuntu 14.04

### 1.2.1 Version

* Ubuntu: 14.04.2
* Kernel:
* Contrail: contrail-install-packages_3.0.0.0-2723~ubuntu-14-04kilo_all.deb


### 1.2.2 Install

* Copy Contrail installation package to the builder.

* If builder is a server in the cluster.
```
dpkg -i <package>
cd /opt/contrail/contrail_packages
./setup.sh
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py. Here is an [example](testbed-contrail-only.py).

* Apply the [patch](fabfile-3.0-2723.diff).

* Run fab commands.
```
cd /opt/contrail/utils
fab install_pkg_all_without_openstack:<package>
fab install_without_openstack:manage_nova_compute='no'
fab setup_without_openstack:manage_nova_compute='no',config_nova='no'
```

# 2 Contrail on CentOS

## 2.1 Pre-Check

* Configure networking.
* Update `/etc/hostname` with the hostname, ensure `ping $(hostname)` work.
* Enable NTP service, ensure the connection to NTP server.
* Disable SELinux by updating `/etc/sysconfig/selinux` or `/etc/selinux/config`.
* Disable firewall.


## 2.2 Contrail 3.0.2.0-51 on CentOS 7.0.1406

### 2.2.1 Version

* CentOS: CentOS Linux release 7.0.1406 (Core)
* Kernel: 3.10.0-123.el7.x86_64
* Contrail: contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm


### 2.2.2 Install

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

## 2.3 Contrail 3.0.2.0-51 on CentOS 7.2.1511

### 2.3.1 Version

* CentOS: CentOS Linux release 7.2.1511 (Core)
* Kernel: 3.10.0-327.el7.x86_64
* Contrail: contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm

### 2.3.2 Install

* Copy Contrail installation package to the builder. The builder could be one of servers in the cluster, or a separated server.

* Install the package and setup local repo.
```
sudo rpm -ivh contrail-install-packages-3.0.2.0-51~centos71liberty.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Appendix A has examples of testbed.py.

* Run fabric commands to install and setup Contrail. All fab commands have to run in /opt/contrail/utils directory.
```
cd /opt/contrail/utils
# This step is required for multi-node deployment.
sudo fab install_pkg_all_without_openstack:<Contrail package>
sudo fab install_without_openstack
sudo fab setup_without_openstack
```


## 2.4 Contrail 3.1.0.0-25 on CentOS 7.2.1511

### 2.4.1 Version

* CentOS: CentOS Linux release 7.2.1511 (Core)
* Kernel: 3.10.0-327.el7.x86_64
* Contrail: contrail-install-packages-3.1.0.0-25~liberty.el7.centos.noarch.rpm

### 2.4.2 Install

* Copy Contrail installation package to the builder. The builder could be one of servers in the cluster, or a separated server.

* Install the package and setup local repo.
```
sudo rpm -ivh contrail-install-packages-3.1.0.0-25~liberty.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
```

* Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Appendix A has examples of testbed.py.

* Patch /usr/lib/python2.7/site-packages/contrail_provisioning/common/base.py.
```
@@ -346,7 +346,8 @@
                        'insecure': self._args.apiserver_insecure}
             for param, value in configs.items():
                 self.set_config(conf_file, 'global', param, value)
-        if self._args.orchestrator == 'vcenter':
+        if (self._args.orchestrator == 'vcenter') or \
+                (self._args.orchestrator == 'none'):
             # Remove the auth setion from /etc/contrail/vnc_api_lib.ini
             # if orchestrator is not openstack
             local("sudo contrail-config --del %s auth" % conf_file)
```

* Run fabric commands to install and setup Contrail. All fab commands have to run in /opt/contrail/utils directory.
```
cd /opt/contrail/utils
# This step is required for multi-node deployment.
sudo fab install_pkg_all_without_openstack:<Contrail package>
sudo fab install_without_openstack
sudo fab setup_without_openstack
```


## 2.5 Contrail 3.1.0.0-45 on CentOS 7.2.1511
Deploy Contrail and integrate it with existing OpenStack.
* Install Contrail controller only.
* Update OpenStack controller.
* Install Contrail vrouter on compute node.
* Update compute node.


### 2.5.1 Version
* CentOS: CentOS Linux release 7.2.1511 (Core)
* Kernel: 3.10.0-327.10.1.el7.x86_64
* Contrail: contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm


### 2.5.2 Install Contrail controller
1. Copy Contrail installation package to the builder. The builder could be one of servers in the cluster, or a separated server.

2. Install the package and setup local repo.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
```

3. Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Appendix A.3 is an example of testbed.py.

4. Apply the patch.
```
--- /usr/lib/python2.7/site-packages/contrail_provisioning/common/base.py.orig
+++ /usr/lib/python2.7/site-packages/contrail_provisioning/common/base.py
@@ -346,7 +346,8 @@
                        'insecure': self._args.apiserver_insecure}
             for param, value in configs.items():
                 self.set_config(conf_file, 'global', param, value)
-        if self._args.orchestrator == 'vcenter':
+        if (self._args.orchestrator == 'vcenter') or \
+                (self._args.orchestrator == 'none'):
             # Remove the auth setion from /etc/contrail/vnc_api_lib.ini
             # if orchestrator is not openstack
             local("sudo contrail-config --del %s auth" % conf_file)
--- /opt/contrail/utils/fabfile/tasks/install.py.orig
+++ /opt/contrail/utils/fabfile/tasks/install.py
@@ -914,13 +914,15 @@
     reboot = kwargs.get('reboot', 'True')
     execute('create_installer_repo')
     execute(create_install_repo_without_openstack, *tgzs, **kwargs)
-    execute(create_install_repo_dpdk)
+    if 'compute' in env.roledefs:
+        execute(create_install_repo_dpdk)
     execute(install_database, False)
     execute(install_cfgm)
     execute(install_control)
     execute(install_collector)
     execute(install_webui)
-    execute('install_vrouter', manage_nova_compute)
+    if 'compute' in env.roledefs:
+        execute('install_vrouter', manage_nova_compute)
     if getattr(env, 'interface_rename', True):
         print "Installing interface Rename package and rebooting the system."
         execute(install_interface_name, reboot)
--- /opt/contrail/utils/fabfile/tasks/provision.py.orig
+++ /opt/contrail/utils/fabfile/tasks/provision.py
@@ -2619,7 +2619,8 @@
     execute('verify_collector')
     execute('setup_webui')
     execute('verify_webui')
-    execute('setup_vrouter', manage_nova_compute, config_nova)
+    if 'compute' in env.roledefs:
+        execute('setup_vrouter', manage_nova_compute, config_nova)
     execute('prov_config')
     execute('prov_database')
     execute('prov_analytics')
@@ -2630,7 +2631,7 @@
     execute('setup_remote_syslog')
     execute('add_tsn', restart=False)
     execute('add_tor_agent', restart=False)
-    if reboot == 'True':
+    if reboot == 'True' and 'compute' in env.roledefs:
         print "Rebooting the compute nodes after setup all."
         execute(compute_reboot)
         # Clear the connections cache
```

5. Run fabric commands to install and setup Contrail controller. All fab commands have to run in /opt/contrail/utils directory.
```
cd /opt/contrail/utils
# This step is required for multi-node deployment.
sudo fab install_pkg_all_without_openstack:<Contrail package>
sudo fab install_without_openstack
sudo fab setup_without_openstack
```


### 2.5.3 Enable authentication
1. Update /etc/contrail/contrail-keystone-auth.conf.
```
[KEYSTONE]
auth_url = http://<Keystone server>:35357/v2.0
auth_host = <Keystone server>
auth_protocol = http
auth_port = 35357
admin_user = admin
admin_password = <admin password>
admin_tenant_name = admin
memcache_servers = 127.0.0.1:11211
insecure = False
```

2. Update /etc/contrail/contrail-api.conf.
```
aaa_mode = cloud-admin
auth = keystone
```

3. Update /etc/contrail/vnc_api_lib.ini.
```
[auth]
AUTHN_TYPE = keystone
AUTHN_PROTOCOL = http
AUTHN_SERVER = <Keystone server>
AUTHN_PORT = 35357
AUTHN_URL = /v2.0/tokens
```

4. Update /etc/contrail/supervisord_config_files/contrail-api.ini.
Add `--conf_file /etc/contrail/contrail-keystone-auth.conf` to `command`.

5. Restart configuration services.
```
service supervisor-config restart
```


### 2.5.4 Install Neutron Contrail plug-in.
1. Copy Contrail installation package to Neutron server.

2. Install the package.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
```

3. Apply the patch.
```
--- /opt/contrail/contrail_packages/setup.sh.orig
+++ /opt/contrail/contrail_packages/setup.sh
@@ -28,13 +28,13 @@
 cd /opt/contrail/contrail_install_repo; tar xvzf /opt/contrail/contrail_packages/contrail_rpms.tgz
 
 # create shell scripts and put to bin
-cp /opt/contrail/contrail_packages/helpers/* /opt/contrail/bin/
+#cp /opt/contrail/contrail_packages/helpers/* /opt/contrail/bin/
 
 # Remove existing python-crypto-2.0.1 rpm.
-yum -y --disablerepo=* remove python-crypto-2.0.1
+#yum -y --disablerepo=* remove python-crypto-2.0.1
 
 # install if available
-yum -y install yum-plugin-priorities
+#yum -y install yum-plugin-priorities
 
 #Install basic packages 
-yum -y install contrail-fabric-utils contrail-setup
+#yum -y install contrail-fabric-utils contrail-setup
```

4. Build local repo.
```
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
yum repolist
```

5. Install Neutron Contrail plug-in.
```
yum install neutron-plugin-contrail python-contrail
```

6. Update /etc/neutron/neutron.conf.
```
[DEFAULT]
core_plugin = neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2
api_extensions_path = extensions:/usr/lib/python2.7/dist-packages/neutron_plugin_contrail/extensions

[database]
connection = sqlite:////var/lib/neutron/neutron.sqlite

[service_providers]
service_provider = LOADBALANCER:Opencontrail:neutron_plugin_contrail.plugins.opencontrail.loadbalancer.driver.OpencontrailLoadbalancerDriver:default

[keystone_authtoken]
auth_host = 172.27.22.65
auth_protocol = http

[QUOTAS]
quota_network = -1
quota_subnet = -1
quota_port = -1
```

7. Update /etc/neutron/plugins/opencontrail/ContrailPlugin.ini.
```
[APISERVER]
api_server_ip = <Contrail configuration>
api_server_port = 8082
contrail_extensions = ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None

aaa_mode=cloud-admin

[COLLECTOR]
analytics_api_ip = <Contrail analytics>
analytics_api_port = 8081

[KEYSTONE]
auth_url = http://<Keystone>:35357/v2.0
admin_user=admin
admin_password=<admin password>
admin_tenant_name=admin
```

8. Restart Neutron server.
```
service neutron-server restart
```


### 2.5.5 Install Contrail vrouter on compute node.
1. Copy Contrail installation package to compute node.

2. Install the package.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
```

3. Apply the patch.
```
--- /opt/contrail/contrail_packages/setup.sh.orig
+++ /opt/contrail/contrail_packages/setup.sh
@@ -28,13 +28,13 @@
 cd /opt/contrail/contrail_install_repo; tar xvzf /opt/contrail/contrail_packages/contrail_rpms.tgz
 
 # create shell scripts and put to bin
-cp /opt/contrail/contrail_packages/helpers/* /opt/contrail/bin/
+#cp /opt/contrail/contrail_packages/helpers/* /opt/contrail/bin/
 
 # Remove existing python-crypto-2.0.1 rpm.
-yum -y --disablerepo=* remove python-crypto-2.0.1
+#yum -y --disablerepo=* remove python-crypto-2.0.1
 
 # install if available
-yum -y install yum-plugin-priorities
+#yum -y install yum-plugin-priorities
 
 #Install basic packages 
-yum -y install contrail-fabric-utils contrail-setup
+#yum -y install contrail-fabric-utils contrail-setup
```

4. Build local repo.
```
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
yum repolist
```

5. Install Contrail vrouter.
```
yum install neutron-plugin-contrail python-contrail
```




# 3 Split configuration DB and analytics DB
There are three controlling roles in this deployment model, controller (configuration, control, web UI, RabbitMQ, Zookeeper and Cassandra), analytics and analytics-DB (Cassandra and Kafka).

1. Install packages, database is installed on analytics-DB. Here is an example of role definition in testbed.py.
```
env.roledefs = {
    'all': [controller1, controller2, controller3, \
            analytics1, analytics2, analytics3, \
            analytics_db1, analytics_db2, analytics_db3],
    'cfgm': [controller1, controller2, controller3],
    'control': [controller1, controller2, controller3],
    'compute': [compute1, compute2],
    'collector': [analytics1, analytics2, analytics3],
    'webui': [controller1, controller2, controller3],
    'database': [analytics_db1, analytics_db2, analytics_db3],
    'build': [builder],
}
```
```
fab install_without_openstack
```

2. Update role definition to install database on controller.
```
env.roledefs = {
    'all': [controller1, controller2, controller3, \
            analytics1, analytics2, analytics3, \
            analytics_db1, analytics_db2, analytics_db3],
    'cfgm': [controller1, controller2, controller3],
    'control': [controller1, controller2, controller3],
    'compute': [compute1, compute2],
    'collector': [analytics1, analytics2, analytics3],
    'webui': [controller1, controller2, controller3],
    'database': [controller1, controller2, controller3],
    'build': [builder],
}
```
```
fab install_database
```

* Setup all services on controller.
```
fab setup_database  
fab verify_database 
fab setup_common
fab setup_ha
fab setup_rabbitmq_cluster
fab increase_limits
fab setup_cfgm
fab verify_cfgm 
fab setup_control
fab verify_control 
```

3. Reverse the change in testbed.py to set analytics-DB with database role and setup all the rest.
```
env.roledefs = {
    'all': [controller1, controller2, controller3, \
            analytics1, analytics2, analytics3, \
            analytics_db1, analytics_db2, analytics_db3],
    'cfgm': [controller1, controller2, controller3],
    'control': [controller1, controller2, controller3],
    'compute': [compute1, compute2],
    'collector': [analytics1, analytics2, analytics3],
    'webui': [controller1, controller2, controller3],
    'database': [analytics_db1, analytics_db2, analytics_db3],
    'build': [builder],
}
```
```
fab setup_database
fab verify_database
fab setup_collector
fab setup_webui
fab verify_webui 
fab setup_vrouter
fab prov_config
fab prov_database
fab prov_analytics
fab prov_control_bgp
fab prov_external_bgp
fab prov_metadata_services
fab prov_encap_type
fab setup_remote_syslog 
fab increase_vrouter_limits
fab compute_reboot
fab verify_compute
```


# Appendix A.1 testbed.py for single-node deployment
```
from fabric.api import env

node1 = 'centos@10.84.29.109'
builder = 'centos@10.84.29.109'

env.roledefs = {
    'all': [node1],
    'cfgm': [node1],
    'control': [node1],
    'compute': [node1],
    'collector': [node1],
    'webui': [node1],
    'database': [node1],
    'rabbit': [node1],
    'build': [builder],
}

env.hostnames = {
    node1: 'vm109',
}

router_asn = 64512
ext_routers = []
env.key_filename = '/home/centos/.ssh/id_rsa'
env.orchestrator = 'none'
env.interface_rename = False
multi_tenancy = False
minimum_diskGB = 10
```


# Appendix A.2 testbed.py for 2-node deployment
```
from fabric.api import env

controller1 = 'centos@10.84.29.108'
compute1 = 'centos@10.84.29.109'
builder = 'centos@10.84.29.108'

env.roledefs = {
    'all': [controller1, compute1],
    'cfgm': [controller1],
    'control': [controller1],
    'compute': [compute1],
    'collector': [controller1],
    'webui': [controller1],
    'database': [controller1],
    'rabbit': [controller1],
    'build': [builder],
}

env.hostnames = {
    controller1: 'vm108',
    compute1: 'vm109',
}

router_asn = 64512
ext_routers = []
env.key_filename = '/home/centos/.ssh/id_rsa'
env.orchestrator = 'none'
env.interface_rename = False
multi_tenancy = False
minimum_diskGB = 10
```


# Appendix A.3 testbed.py for controller only
```
from fabric.api import env

controller1 = 'centos@10.84.29.108'
builder = 'centos@10.84.29.108'

env.roledefs = {
    'all': [controller1],
    'cfgm': [controller1],
    'control': [controller1],
    'collector': [controller1],
    'webui': [controller1],
    'database': [controller1],
    'rabbit': [controller1],
    'build': [builder],
}

env.hostnames = {
    controller1: 'vm108'
}

router_asn = 64512
ext_routers = []
env.key_filename = '/home/centos/.ssh/id_rsa'
env.orchestrator = 'none'
env.interface_rename = False
multi_tenancy = False
minimum_diskGB = 10
```


# Appendix B Web UI local authentication
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


