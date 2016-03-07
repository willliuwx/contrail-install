## Contrail Only

### Install Contrail

* Copy Contrail installation package, for example, contrail-install-packages_3.0.0.0-2723~ubuntu-14-04kilo_all.deb, to the builder.

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



