# 1 Overview
This guide is to integrate Contrail 3.1.0.0-45 with existing OpenStack Mitaka on CentOS 7.2.1511.

Note: This guide is not for production deployment!

* CentOS: CentOS Linux release 7.2.1511 (Core)
* Kernel: 3.10.0-327.10.1.el7.x86_64
* Contrail: contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
* Disable SELinux (/etc/systconfig/selinux)
```
sestatus
setenforce 0
```

* Disable firewall
```
systemctl stop firewalld
systemctl disable firewalld
```


# 2 Install Contrail controller
#### 1. Copy Contrail installation package to the builder. The builder could be one of servers in the cluster, or a separated server.

#### 2. Install the package and build local repo.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
```

#### 3. Build /opt/contrail/utils/fabfile/testbeds/testbed.py
Appendix A.1 is an example of testbed.py.
* No `openstack` role.
* No `compute` role, compute/vrouter will be added separately.
* Orchestration is `none`.

#### 4. Apply the patch to fabric scripts.
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

#### 5. Run fabric commands to install and setup Contrail controller. All fab commands have to run in /opt/contrail/utils directory.
```
cd /opt/contrail/utils
# This step is required for multi-node deployment.
sudo fab install_pkg_all_without_openstack:<Contrail package>
sudo fab install_without_openstack
sudo fab setup_without_openstack
```


# 3 Update Contrail configuration
#### 1. Update /etc/contrail/contrail-keystone-auth.conf.
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

#### 2. Update /etc/contrail/contrail-api.conf.
```
aaa_mode = cloud-admin
auth = keystone

[KEYSTONE]
admin_domain_id = 7881cd825a3c418d884859965d7433d5
```

#### 3. Update /etc/contrail/vnc_api_lib.ini.
```
[auth]
AUTHN_TYPE = keystone
AUTHN_PROTOCOL = http
AUTHN_SERVER = <Keystone server>
AUTHN_PORT = 35357
AUTHN_URL = /v2.0/tokens
```

#### 4. Update /etc/contrail/supervisord_config_files/contrail-api.ini.
Add `--conf_file /etc/contrail/contrail-keystone-auth.conf` to `command`.

#### 5. Restart configuration services.
```
service supervisor-config restart
```


# 4 Install Neutron Contrail plug-in
#### 1. Copy Contrail installation package to Neutron server.

#### 2. Install the package and build local repo.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
yum repolist
```

#### 3. Install Neutron Contrail plug-in.
```
yum install neutron-plugin-contrail python-contrail
```

#### 4. Update /etc/neutron/neutron.conf.
For now, plugin takes parameters from [keystoen_authtoken] for v2 auth.
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
admin_user=neutron
admin_password=<password>
admin_tenant_name=service

[quotas]
quota_driver = neutron_plugin_contrail.plugins.opencontrail.quota.driver.QuotaDriver
quota_network = -1
quota_subnet = -1
quota_port = -1
```

#### 5. Update /etc/neutron/plugins/opencontrail/ContrailPlugin.ini.
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

#### 6. Restart Neutron server.
```
service neutron-server restart
```


# 5 Install Contrail vrouter on compute node
#### 1. Stop and disable OVS services.
```
systemctl stop neutron-openvswitch-agent
systemctl stop neutron-l3-agent 
systemctl stop neutron-metadata-agent
systemctl stop neutron-vpn-agent
systemctl stop openvswitch
systemctl disable neutron-openvswitch-agent
systemctl disable neutron-l3-agent 
systemctl disable neutron-metadata-agent
systemctl disable neutron-vpn-agent
systemctl disable neutron-openvswitch-agent
systemctl disable openvswitch
rmmod vport_vxlan
rmmod openvswitch
```

#### 2. Copy Contrail installation package to compute node.

#### 3. Install the package and build local repo.
```
sudo rpm -ivh contrail-install-packages-3.1.1.0-45~centos71mitaka.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
sudo ./setup.sh
yum repolist
```

#### 4. Install Contrail vrouter.
```
yum install contrail-vrouter-common openstack-utils
```

#### 5. Setup vrouter.
```
setup-vnc-compute --self_ip <vrouter address> \
    --cfgm_ip <Contrail configuration address> \
    --keystone_ip <Keystone address> \
    --keystone_admin_user <username> \
    --keystone_admin_password <password> \
    --keystone_admin_tenant <tenant name> \
    --ncontrols 1 \
    --orchestrator none \
    --hypervisor libvirt \
    --no_contrail_openstack \
    --mgmt_self_ip <vrouter address> \
    --no_nova_config
```

#### 6. Reboot server.
```
reboot
```


# Appendix A.1 testbed.py for controller only
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


