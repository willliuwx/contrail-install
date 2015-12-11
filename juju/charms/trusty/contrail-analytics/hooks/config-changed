#!/usr/bin/env python

from socket import gethostbyname
import sys

import yaml

from charmhelpers.contrib.openstack.utils import configure_installation_source

from charmhelpers.core.hookenv import (
    Hooks,
    UnregisteredHookError,
    config,
    local_unit,
    log,
    relation_get,
    relation_set,
    unit_get
)

from charmhelpers.core.host import (
    restart_on_change,
    service_restart
)

from charmhelpers.fetch import (
    apt_install,
    apt_upgrade,
    configure_sources
)

from contrail_analytics_utils import (
    fix_nodemgr,
    fix_permissions,
    fix_services,
    write_analytics_api_config,
    write_collector_config,
    write_nodemgr_config,
    write_query_engine_config
)

PACKAGES = [ "contrail-analytics", "contrail-utils", "contrail-nodemgr",
             "python-jinja2" ]

hooks = Hooks()
config = config()

@hooks.hook("cassandra-relation-changed")
def cassandra_changed():
    # 'port' is used in legacy precise charm
    if not relation_get("rpc_port") and not relation_get("port"):
        log("Relation not ready")
        return
    cassandra_relation()

@hooks.hook("cassandra-relation-departed")
@hooks.hook("cassandra-relation-broken")
@restart_on_change({"/etc/contrail/contrail-collector.conf": ["contrail-collector"],
                    "/etc/contrail/contrail-query-engine.conf": ["contrail-query-engine"],
                    "/etc/contrail/contrail-analytics-api.conf": ["contrail-analytics-api"]})
def cassandra_relation():
    write_collector_config()
    write_query_engine_config()
    write_analytics_api_config()

@hooks.hook("config-changed")
def config_changed():
    pass

@hooks.hook("contrail-discovery-relation-changed")
def contrail_discovery_changed():
    if not relation_get("port"):
        log("Relation not ready")
        return
    contrail_discovery_relation()

@hooks.hook("contrail-discovery-relation-departed")
@hooks.hook("contrail-discovery-relation-broken")
@restart_on_change({"/etc/contrail/contrail-collector.conf": ["contrail-collector"],
                    "/etc/contrail/contrail-query-engine.conf": ["contrail-query-engine"],
                    "/etc/contrail/contrail-analytics-api.conf": ["contrail-analytics-api"],
                    "/etc/contrail/contrail-analytics-nodemgr.conf": ["contrail-analytics-nodemgr"]})
def contrail_discovery_relation():
    write_collector_config()
    write_query_engine_config()
    write_analytics_api_config()
    write_nodemgr_config()

@hooks.hook("http-services-relation-joined")
def http_services_joined():
    name = local_unit().replace("/", "-")
    addr = gethostbyname(unit_get("private-address"))
    services = [ { "service_name": "contrail-analytics-api",
                   "service_host": "0.0.0.0",
                   "service_port": 8081,
                   "service_options": [ "mode http", "balance leastconn", "option httpchk GET /analytics HTTP/1.0" ],
                   "servers": [ [ name, addr, 8081, "check" ] ] } ]
    relation_set(services=yaml.dump(services))

@hooks.hook()
def install():
    configure_installation_source(config["openstack-origin"])
    configure_sources(True, "install-sources", "install-keys")
    apt_upgrade(fatal=True, dist=True)
    apt_install(PACKAGES, fatal=True)
    fix_permissions()
    fix_services()
    fix_nodemgr()

def main():
    try:
        hooks.execute(sys.argv)
    except UnregisteredHookError as e:
        log("Unknown hook {} - skipping.".format(e))

@hooks.hook("upgrade-charm")
def upgrade_charm():
    write_collector_config()
    write_query_engine_config()
    write_analytics_api_config()
    write_nodemgr_config()
    service_restart("supervisor-analytics")

if __name__ == "__main__":
    main()
