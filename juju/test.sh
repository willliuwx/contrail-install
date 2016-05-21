#!/bin/sh

juju bootstrap
juju add-machine ssh:root@10.84.32.12
rm ~/.ssh/known_hosts 
juju deploy --to 1 --config config.yaml cs:trusty/nova-compute
juju deploy --config config.yaml local:trusty/neutron-contrail
juju add-relation nova-compute neutron-contrail

