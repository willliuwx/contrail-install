
## Builder
Package 'fabric' and 'python-netaddr' is required.
```
# apt-get install fabric python-netaddr
```

## Contrail Only

### Install Contrail

```
# fab install_pkg_all_without_openstack:<package>
# fab install_without_openstack:manage_nova_compute='no'
# fab setup_without_openstack:manage_nova_compute='no',config_nova='no'
```

### Post installation
Fix device manager.
/etc/contrail/supervisord_config_files/contrail-device-manager.ini
```
-command=/usr/bin/contrail-device-manager --conf_file
+command=/usr/bin/contrail-device-manager --conf_file  /etc/contrail/contrail-device-manager.conf
```

Reload configuration and restart node manager to report new status.
```
supervisorctl -s unix:///tmp/supervisord_config.sock reload
supervisorctl -s unix:///tmp/supervisord_config.sock restart contrail-config-nodemgr
```

### Web UI local authentication
Update /etc/contrail/config.global.js.
```
config.orchestration.Manager = 'none'

config.multi_tenancy = {};
config.multi_tenancy.enabled = false;

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


## Contrail with existing OpenStack


