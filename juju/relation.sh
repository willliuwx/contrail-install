#!/bin/sh

juju add-relation keystone mysql
juju add-relation glance mysql
juju add-relation glance keystone
juju add-relation openstack-dashboard keystone
juju add-relation nova-cloud-controller mysql
juju add-relation nova-cloud-controller rabbitmq-server
juju add-relation nova-cloud-controller glance
juju add-relation nova-cloud-controller keystone
juju add-relation neutron-api mysql
juju add-relation neutron-api rabbitmq-server
juju add-relation neutron-api nova-cloud-controller
juju add-relation neutron-api keystone
juju add-relation neutron-api neutron-api-contrail
juju add-relation nova-compute:shared-db mysql:shared-db
juju add-relation nova-compute:amqp rabbitmq-server:amqp
juju add-relation nova-compute glance
juju add-relation nova-compute nova-cloud-controller

juju add-relation contrail-configuration:cassandra cassandra:database
juju add-relation contrail-configuration zookeeper
juju add-relation contrail-configuration rabbitmq-server
juju add-relation contrail-configuration keystone

juju add-relation contrail-control:contrail-discovery contrail-configuration:contrail-discovery
juju add-relation contrail-control:contrail-ifmap contrail-configuration:contrail-ifmap
juju add-relation contrail-analytics:cassandra cassandra:database
juju add-relation contrail-analytics contrail-configuration

juju add-relation neutron-api-contrail contrail-configuration
juju add-relation neutron-api-contrail keystone

juju add-relation nova-compute neutron-contrail
juju add-relation neutron-contrail:contrail-discovery contrail-configuration:contrail-discovery
juju add-relation neutron-contrail:contrail-api contrail-configuration:contrail-api
juju add-relation neutron-contrail keystone

juju add-relation contrail-webui keystone
juju add-relation contrail-webui:cassandra cassandra:database
juju add-relation contrail-webui:contrail_discovery contrail-configuration:contrail-discovery
juju add-relation contrail-webui:contrail_api contrail-configuration:contrail-api

juju add-relation contrail-configuration haproxy
juju add-relation contrail-analytics haproxy
juju add-relation contrail-webui haproxy
juju add-relation haproxy keepalived

