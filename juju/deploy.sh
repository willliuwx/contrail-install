#!/bin/bash

container_create()
{
    # $1: machine ID

    cid=$(juju add-machine lxc:$1 2>&1 | awk '{print $3}')
    echo "Container $cid is added, waiting for it starts..."
    loop=1
    while [ $loop == "1" ]
    do
        sleep 3
        state=$(juju status | grep -A 1 $cid | grep started | awk '{print $2}')
        if [[ $state == "started" ]]
        then
            loop=0
            echo ""
            echo "Container $cid starts."
        else
            echo -n "*"
        fi
    done

    echo "Provisioning $cid..."
    juju scp target-provision.sh $cid:
    juju run --machine $cid "sudo ./target-provision.sh"
}

deploy_openstack()
{
    # $1: machine ID

    echo "Deploy OpenStack services..."
    for service in \
        "trusty/rabbitmq-server" \
        "--config config.yaml trusty/mysql" \
        "--config config.yaml trusty/keystone" \
        "--config config.yaml trusty/nova-cloud-controller" \
        "--config config.yaml trusty/glance" \
        "--config config.yaml trusty/openstack-dashboard" \
        "--config config.yaml trusty/neutron-api"
    do
        container_create $1
        echo "Provisioning $cid..."
        juju scp target-provision.sh $cid:
        juju run --machine $cid "sudo ./target-provision.sh"
        echo "Deploy service $service..."
        juju deploy --to $cid $service
        echo ""
    done
    echo ""
}

deploy_contrail()
{
    # $1: machine ID

    echo "Deploy Contrail services..."
    for service in \
        "--config config.yaml local:trusty/cassandra" \
        "trusty/zookeeper" \
        "--config config.yaml local:trusty/contrail-configuration" \
        "--config config.yaml local:trusty/contrail-control" \
        "--config config.yaml local:trusty/contrail-analytics" \
        "--config config.yaml local:trusty/contrail-webui" \
        "--config config.yaml trusty/haproxy"
    do
        container_create $1
        echo "Deploy service $service..."
        juju deploy --to $cid $service
        echo ""
    done
    echo ""
}

add_contrail()
{
    # $1: machine ID

    echo "Deploy Contrail services..."
    for service in \
        "zookeeper" \
        "contrail-configuration" \
        "contrail-control" \
        "contrail-analytics" \
        "contrail-webui" \
        "haproxy"
    do
        container_create $1
        echo "Deploy service $service..."
        juju add-unit --to $cid $service
        echo ""
    done
    echo ""
}

deploy_compute()
{
    # $1: machine ID

    echo "Deploy compute node..."
    juju deploy --to $1 --config config.yaml trusty/nova-compute
    echo ""
}

add_compute()
{
    # $1: machine ID

    echo "Deploy compute node..."
    juju add-unit --to $1 nova-compute
    echo ""
}

deploy_subordinate()
{
    echo "Deploy subordinate services..."
    juju deploy local:trusty/keepalived
    juju deploy --config config.yaml local:trusty/neutron-api-contrail
    juju deploy --config config.yaml local:trusty/neutron-contrail
    echo ""
}

export JUJU_REPOSITORY=charms

#deploy_openstack 3
#deploy_contrail 1
#add_contrail 2
add_contrail 4
deploy_compute 5
#add_compute 6
deploy_subordinate

echo "Done."

