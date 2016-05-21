#!/bin/sh

lines="
admin_user = admin
admin_password = contrail123
admin_tenant_name = admin
"

lines=$(echo "$lines" | sed -e 's/$/\\n/' | tr -d '\n')

sed -i.orig -e "s@\[keystone_authtoken\]@\0$lines@" /etc/neutron/plugins/opencontrail/ContrailPlugin.ini

