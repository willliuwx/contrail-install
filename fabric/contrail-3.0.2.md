#1 Overview

This guide is to install Contrail networking (without OpenStack) 3.0.2 for CentOS 7.2.

The testbed.py in Appendix A.1 is for 9 controlling servers, 3 controller nodes, 3 analytics nodes and 3 analytics-db nodes.

Each controller node has the following services.
* configuration
* control
* web UI
* RabbitMQ
* Cassandra
* Zookeeper
* Kafka (disabled)
* HAProxy

The analytics node has the following services.
* analytics

The analytics-db node has the following services.
* Cassandra
* Zookeeper (disabled)
* Kafka

The testbed.py in Appendix A.2 is for 4 controlling servers, 3 controller nodes and 1 analytics node. Here analytics and analytics-db nodes are combined.


#2 Pre-Installation

Servers are installed with CentOS 7.2.1511 and kernel 3.10.0-327.el7.x86_64 without any upgrading.

Check the following items.
* Networking, servers can connect to each other.
* Hostname, `ping $(hostname)` has to work.
* NTP, NTP service is running and `ntpq -p` has to show connection to NTP server.


#3 Install

* Take the first server as the builder, copy and install Contrail installation package, and setup fabric utility and local repo.
```
rpm -ivh contrail-install-packages-3.0.2.1-8~liberty.el7.centos.noarch.rpm
cd /opt/contrail/contrail_packages/
./setup.sh
```

* Create /opt/contrail/utils/fabfile/testbeds/testbed.py. Take Appendix A.1 as the template.

* Goto /opt/contrail/utils directory. All fab commands have to run from there.
```
cd /opt/contrail/utils
```

* Install Contrail package on all other servers.
```
fab fab install_pkg_all:<path>/contrail-install-packages-3.0.2.1-8~liberty.el7.centos.noarch.rpm
```

* Install Contrail services.
```
fab install_contrail
```

* Update testbed.py to install database on controllers.
Here is the change for Appendix A.1.
```
-    'database': [analytics_db1, analytics_db2, analytics_db3],
+    'database': [controller1, controller2, controller3],
```

Here is the change for Appendix A.2.
```
-    'database': [analytics1],
+    'database': [controller1, controller2, controller3],
```

* Install database and provisioning services on controllers.
```
fab install_database
fab setup_database

# Disable supervisor-database.
# Kafka is managed by supervisor-database. It's also disabled.
fab -R cfgm -- "sudo systemctl stop supervisor-database"
fab -R cfgm -- "sudo systemctl disable supervisor-database"
fab setup_common
fab setup_ha
fab setup_rabbitmq_cluster
fab increase_limits
fab setup_cfgm
fab verify_cfgm
fab setup_control
fab verify_control
```

* Reverse the change in testbed.py, put analytics back to role 'database'.
```
fab setup_database

# Disable Zookeeper.
fab -R database -- "sudo service zookeeper stop"
fab -R database -- "sudo systemctl disable zookeeper"

# Update Kafka to use the Zookeeper on controllers and restart it.
fab -R database -- "sudo sed -i 's/zookeeper.connect=.*/zookeeper.connect=10.1.1.1:2181,10.1.1.2:2181,10.1.1.3:2181/g'  /usr/share/kafka/config/server.properties"
fab -R database -- "sudo service supervisor-database restart"
fab setup_collector
fab -R collector -- "openstack-config --set /etc/contrail/contrail-alarm-gen.conf DEFAULTS zk_list 10.1.1.1:2181 10.1.1.2:2181 10.1.1.3:2181"
fab -R collector -- "openstack-config --set /etc/contrail/contrail-collector.conf DEFAULT zookeeper_server_list 10.1.1.1:2181,10.1.1.2:2181,10.1.1.3:2181"
fab -R collector -- "openstack-config --set /etc/contrail/contrail-snmp-collector.conf DEFAULTS zookeeper 10.1.1.1:2181,10.1.1.2:2181,10.1.1.3:2181"
fab -R collector -- "openstack-config --set /etc/contrail/contrail-topology.conf DEFAULTS zookeeper 10.1.1.1:2181,10.1.1.2:2181,10.1.1.3:2181"
fab restart_collector
fab setup_webui
fab prov_config
fab prov_database
fab prov_analytics
fab prov_control_bgp
fab prov_external_bgp
fab prov_metadata_services
fab prov_encap_type
fab setup_remote_syslog
```


#4 Add vRouter

* Update testbed.py with vrouter host info. Update role 'all' and 'compute'.

* Copy Contrail package to the vRouter and create local repo.
```
fab install_pkg_node:<path>/<package>,root@10.1.1.20
fab create_install_repo_node:root@10.1.1.20
```

* Install vrouter package, setup and reboot..
```
fab install_only_vrouter_node:no,root@10.1.1.20
fab setup_only_vrouter_node:no,no,root@10.1.1.20
fab reboot_node:no,root@10.1.1.20
```


#Appendix A.1 testbed.py
```
from fabric.api import env

controller1 = 'root@10.1.1.1'
controller2 = 'root@10.1.1.2'
controller3 = 'root@10.1.1.3'
analytics1 = 'root@10.1.1.4'
analytics2 = 'root@10.1.1.5'
analytics3 = 'root@10.1.1.6'
analytics_db1 = 'root@10.1.1.7'
analytics_db2 = 'root@10.1.1.8'
analytics_db3 = 'root@10.1.1.9'
compute1 = 'root@10.1.1.20'
builder = 'root@10.1.1.1'

ext_routers = []
router_asn = 64512

env.roledefs = {
    'all': [controller1, controller2, controller3, \
            analytics1, analytics2, analytics3, \
            analytics_db1, analytics_db2, analytics_db3]
    'cfgm': [controller1, controller2, controller3],
    'control': [controller1, controller2, controller3],
    'compute': [],
    'collector': [analytics1, analytics2, analytics3],
    'webui': [controller1, controller2, controller3],
    'database': [analytics_db1, analytics_db2, analytics_db3],
    'build': [builder],
}

env.hostnames = {
    controller1: 'vm1',
    controller2: 'vm2',
    controller3: 'vm3',
    analytics1: 'vm4',
    analytics2: 'vm5',
    analytics3: 'vm6',
    analytics_db1: 'vm7',
    analytics_db2: 'vm8',
    analytics_db3: 'vm9',
    compute1: 'vm20',
}

env.key_filename = '/root/.ssh/id_rsa'
env.orchestrator = 'none'
env.interface_rename = False
multi_tenancy = False
do_parallel = False
env.ha = {
    'contrail_internal_vip': '10.1.1.250',
}
```


#Appendix A.2 testbed.py
```
from fabric.api import env

controller1 = 'root@10.1.1.1'
controller2 = 'root@10.1.1.2'
controller3 = 'root@10.1.1.3'
analytics1 = 'root@10.1.1.4'
compute1 = 'root@10.1.1.20'
builder = 'root@10.1.1.1'

ext_routers = []
router_asn = 64512

env.roledefs = {
    'all': [controller1, controller2, controller3, analytics1],
    'cfgm': [controller1, controller2, controller3],
    'control': [controller1, controller2, controller3],
    'compute': [],
    'collector': [analytics1],
    'webui': [controller1, controller2, controller3],
    'database': [analytics1],
    'build': [builder],
}

env.hostnames = {
    controller1: 'vm1',
    controller2: 'vm2',
    controller3: 'vm3',
    analytics1: 'vm4',
    compute1: 'vm20',
}

env.key_filename = '/root/.ssh/id_rsa'
env.orchestrator = 'none'
env.interface_rename = False
multi_tenancy = False
do_parallel = False
env.ha = {
    'contrail_internal_vip': '10.1.1.250',
}
```

