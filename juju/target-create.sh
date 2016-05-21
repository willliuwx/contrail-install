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
}

create()
{
    for ((service=1; service <= $2; service++))
    do
        container_create $1
        juju scp target-provision.sh $cid:
        juju run --machine $cid "sudo ./target-provision.sh"
        echo ""
    done
}

#if [ ! $1 ]
#then
#    echo "The machine ID is missing!"
#    exit 0
#fi

#if [ ! $2 ]
#then
#    echo "The number of target machine is missing!"
#    exit 0
#fi

#create $1 $2
create 1 7
create 2 6
create 3 6
create 4 6

echo "Done."

