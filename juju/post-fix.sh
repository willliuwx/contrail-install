#!/bin/sh

# Fix plugin configuration.
fix_plugin()
{
    juju scp -- -o StrictHostKeyChecking=no fix-plugin.sh neutron-api/0:.
    juju run --unit neutron-api/0 "sudo /home/ubuntu/fix-plugin.sh;sudo service neutron-server restart"
}

fix_config_prov()
{
    keystone_server=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"keystone\"][\"units\"][\"keystone/0\"][\"public-address\"]")

    api_server=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"contrail-configuration\"][\"units\"][\"contrail-configuration/0\"][\"public-address\"]")

    # Provision configuration node.
    unit=contrail-configuration/0
    host_name=$(juju run --unit $unit "hostname" | grep juju)
    host_address=$api_server

    cmd="python /usr/share/contrail-utils/provision_config_node.py --host_name $host_name --host_ip $host_address --api_server_ip $api_server --api_server_port 8082 --oper add --admin_user admin --admin_password contrail123 --admin_tenant_name admin --openstack_ip $keystone_server"

    juju run --unit $unit "$cmd"
}

fix_analytics_prov()
{
    keystone_server=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"keystone\"][\"units\"][\"keystone/0\"][\"public-address\"]")

    api_server=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"contrail-configuration\"][\"units\"][\"contrail-configuration/0\"][\"public-address\"]")

    # Provision analytics node.
    unit=contrail-analytics/0
    host_name=$(juju run --unit $unit "hostname" | grep juju)

    host_address=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"contrail-analytics\"][\"units\"][\"contrail-analytics/0\"][\"public-address\"]")

    cmd="python /usr/share/contrail-utils/provision_analytics_node.py --host_name $host_name --host_ip $host_address --api_server_ip $api_server --api_server_port 8082 --oper add --admin_user admin --admin_password contrail123 --admin_tenant_name admin --openstack_ip $keystone_server"

    juju run --unit $unit "$cmd"
}

fix_analytics_cassandra()
{
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-analytics-api.conf"
    juju run --unit contrail-analytics/0 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-collector.conf"
    juju run --unit contrail-analytics/0 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-query-engine.conf"
    juju run --unit contrail-analytics/0 "$cmd"
    juju run --unit contrail-analytics/0 "service supervisor-analytics restart"

    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-analytics-api.conf"
    juju run --unit contrail-analytics/1 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-collector.conf"
    juju run --unit contrail-analytics/1 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-query-engine.conf"
    juju run --unit contrail-analytics/1 "$cmd"
    juju run --unit contrail-analytics/1 "service supervisor-analytics restart"

    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-analytics-api.conf"
    juju run --unit contrail-analytics/2 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-collector.conf"
    juju run --unit contrail-analytics/2 "$cmd"
    cmd="sed -i -e 's/9160/9042/g' /etc/contrail/contrail-query-engine.conf"
    juju run --unit contrail-analytics/2 "$cmd"
    juju run --unit contrail-analytics/2 "service supervisor-analytics restart"
}

fix_analytics_cassandra

