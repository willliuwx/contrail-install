#!/bin/sh

machine_agent_state()
{
    juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"machines\"][\"$1\"][\"agent-state\"]" 2> /dev/null
}

wait_for_machine()
{
    while [ "$(machine_agent_state $1)" != started ]; do
        sleep 10
        echo "waiting for machine $1..."
    done
    echo "Machine $1 is running..."
}

create_openstackrc()
{
    keystone_addr=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"keystone\"][\"units\"][\"keystone/0\"][\"public-address\"]")

    cat << __EOF__ > openstackrc
export OS_USERNAME=admin
export OS_PASSWORD=contrail123
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$keystone_addr:5000/v2.0/
export OS_NO_CACHE=1
export OS_IDENTITY_API_VERSION=2.0
__EOF__
}

set_ssh_port_forwarding()
{
    pid=$(ps -ax | grep "ssh -N -f" | grep 8080 | awk '{print $1}')
    if [ $pid ]
    then
      sudo kill -9 $pid
    fi

    public_addr=$(ip -f inet addr show dev em1 | grep inet | awk '{split($2, a, "/"); print a[1]}')
    openstack_ui_addr=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"openstack-dashboard\"][\"units\"][\"openstack-dashboard/0\"][\"public-address\"]")
    contrail_ui_addr=$(juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"contrail-webui\"][\"units\"][\"contrail-webui/0\"][\"public-address\"]")

    sudo ssh -N -f \
            -L $public_addr:80:$openstack_ui_addr:80 \
            -L $public_addr:443:$openstack_ui_addr:443 \
            -L $public_addr:8080:$contrail_ui_addr:8080 \
            -L $public_addr:8143:$contrail_ui_addr:8143 \
            -l root localhost
}

bootstrap_local_2()
{
    juju bootstrap
    juju add-machine \
            --constraints "root-disk=40G cpu-cores=8 mem=64G" \
            --series trusty
    juju add-machine \
            --constraints "root-disk=20G cpu-cores=4 mem=16G" \
            --series trusty
    wait_for_machine 1
    wait_for_machine 2

    echo "Setup machine 1 (controller)..."
    juju scp -- -o StrictHostKeyChecking=no local-machine-setup.sh 1:.
    juju scp -- -o StrictHostKeyChecking=no ubuntu-cloud.trusty.conf 1:.
    juju scp -- -o StrictHostKeyChecking=no user-hook-local 1:.
    juju run --machine 1 "sudo ./local-machine-setup.sh lxc"


    echo "Setup machine 2 (compute)..."
    juju scp -- -o StrictHostKeyChecking=no local-machine-setup.sh 2:.
    juju run --machine 2 "sudo ./local-machine-setup.sh compute"

    echo "Deploy..."
    juju-deployer -c contrail-2n-lxc.yaml

    create_openstackrc
    set_ssh_port_forwarding
}

bootstrap_local_3()
{
    juju bootstrap
    juju add-machine \
            --constraints "root-disk=40G cpu-cores=4 mem=32G" \
            --series trusty
    juju add-machine \
            --constraints "root-disk=40G cpu-cores=4 mem=32G" \
            --series trusty
    juju add-machine \
            --constraints "root-disk=20G cpu-cores=4 mem=16G" \
            --series trusty
    wait_for_machine 1
    wait_for_machine 2
    wait_for_machine 3

    echo "Setup machine 1 (controller)..."
    juju scp -- -o StrictHostKeyChecking=no local-machine-setup.sh 1:.
    juju scp -- -o StrictHostKeyChecking=no ubuntu-cloud.trusty.conf 1:.
    juju scp -- -o StrictHostKeyChecking=no user-hook-local 1:.
    juju run --machine 1 "sudo ./local-machine-setup.sh lxc"

    echo "Setup machine 2 (controller)..."
    juju scp -- -o StrictHostKeyChecking=no local-machine-setup.sh 2:.
    juju scp -- -o StrictHostKeyChecking=no ubuntu-cloud.trusty.conf 2:.
    juju scp -- -o StrictHostKeyChecking=no user-hook-local 2:.
    juju run --machine 2 "sudo ./local-machine-setup.sh machine"
    juju run --machine 2 "sudo service ufw stop"

    echo "Setup machine 3 (compute)..."
    juju scp -- -o StrictHostKeyChecking=no local-machine-setup.sh 3:.
    juju run --machine 3 "sudo ./local-machine-setup.sh compute"

    echo "Deploy..."
    juju-deployer -c contrail-3n-group.yaml

    create_openstackrc
    set_ssh_port_forwarding
}

bootstrap_manual_2()
{
    juju bootstrap
    juju add-machine ssh:root@10.87.64.145
    juju add-machine ssh:root@10.84.32.12
    wait_for_machine 1
    wait_for_machine 2

    echo "Deploy..."
    juju-deployer -c contrail-user-2.yaml
}

bootstrap_manual_5()
{
    juju bootstrap
    juju add-machine ssh:root@10.87.64.199
    juju add-machine ssh:root@10.87.64.219
    juju add-machine ssh:root@10.87.64.239
    juju add-machine ssh:root@10.87.64.143
    juju add-machine ssh:root@10.87.64.144
    wait_for_machine 1
    wait_for_machine 2
    wait_for_machine 3
    wait_for_machine 4
    wait_for_machine 5

    echo "Deploy..."
    juju-deployer -c contrail-5n-lxc.yaml
    create_openstackrc
}

bootstrap_manual_8()
{
    juju bootstrap
    juju add-machine ssh:root@10.87.64.199
    juju add-machine ssh:root@10.87.64.198
    juju add-machine ssh:root@10.87.64.219
    juju add-machine ssh:root@10.87.64.218
    juju add-machine ssh:root@10.87.64.239
    juju add-machine ssh:root@10.87.64.238
    juju add-machine ssh:root@10.87.64.143
    juju add-machine ssh:root@10.87.64.144
    wait_for_machine 1
    wait_for_machine 2
    wait_for_machine 3
    wait_for_machine 4
    wait_for_machine 5
    wait_for_machine 6
    wait_for_machine 7
    wait_for_machine 8

    echo "Deploy..."
    #juju-deployer -c contrail-user-2.yaml
}

load_image()
{
    juju scp -- -o StrictHostKeyChecking=no openstackrc glance/0:.
    juju scp -- -o StrictHostKeyChecking=no $1 glance/0:.
    juju run --unit glance/0 "source /home/ubuntu/openstackrc; glance image-create --container-format bare --disk-format qcow2 --visibility public --file /home/ubuntu/cirros-0.3.4-x86_64-disk.img --name cirros"
}

help()
{
    echo "help"
}

main()
{
    case "$1" in
        local-2)
            shift
            bootstrap_local_2 "$@"
            ;;
        local-3)
            shift
            bootstrap_local_3 "$@"
            ;;
        manual-2)
            shift
            bootstrap_manual_2 "$@"
            ;;
        manual-5)
            shift
            bootstrap_manual_5 "$@"
            ;;
        manual-8)
            shift
            bootstrap_manual_8 "$@"
            ;;
        load-image)
            shift
            load_image "$@"
            ;;
        test)
            shift
            set_ssh_port_forwarding
            ;;
        *)
            help
            ;;
    esac
}

main "$@"
exit 0

