import os
import pwd
import shutil
from socket import gethostbyname
from subprocess import check_output

from charmhelpers.core.hookenv import (
    related_units,
    relation_get,
    relation_ids,
    unit_get
)

from charmhelpers.core.host import service_restart

from charmhelpers.core.templating import render

def contrail_ctx():
    return { "host_ip": gethostbyname(unit_get("private-address")) }

def cassandra_ctx():
    return { "cassandra_servers": [ gethostbyname(relation_get("private-address", unit, rid))
                                    + ":" + (rpc_port if rpc_port else port)
                                    for rid in relation_ids("cassandra")
                                    for unit, rpc_port, port in
                                    ((unit, relation_get("rpc_port", unit, rid), relation_get("port", unit, rid))
                                     for unit in related_units(rid))
                                    if rpc_port or port ] }

def discovery_ctx():
    ctxs = [ { "disc_server_ip": vip if vip \
                 else gethostbyname(relation_get("private-address", unit, rid)),
               "disc_server_port": port }
             for rid in relation_ids("contrail-discovery")
             for unit, port, vip in
             ((unit, relation_get("port", unit, rid), relation_get("vip", unit, rid))
              for unit in related_units(rid))
             if port ]
    return ctxs[0] if ctxs else {}

def fix_nodemgr():
    # add files missing from contrail-nodemgr package
    shutil.copy("files/contrail-nodemgr-analytics.ini",
                "/etc/contrail/supervisord_analytics_files")
    pw = pwd.getpwnam("contrail")
    os.chown("/etc/contrail/supervisord_analytics_files/contrail-nodemgr-analytics.ini",
             pw.pw_uid, pw.pw_gid)
    shutil.copy("files/contrail-analytics-nodemgr", "/etc/init.d")
    os.chmod("/etc/init.d/contrail-analytics-nodemgr", 0755)
    service_restart("supervisor-analytics")

def fix_permissions():
    os.chmod("/etc/contrail", 0755)
    os.chown("/etc/contrail", 0, 0)

def fix_services():
    # redis listens on localhost by default
    check_output(["sed", "-i", "-e",
                  "s/^bind /# bind /",
                  "/etc/redis/redis.conf"])
    service_restart("redis-server")

def write_analytics_api_config():
    ctx = {}
    ctx.update(contrail_ctx())
    ctx.update(cassandra_ctx())
    ctx.update(discovery_ctx())
    render("contrail-analytics-api.conf",
           "/etc/contrail/contrail-analytics-api.conf", ctx)

def write_collector_config():
    ctx = {}
    ctx.update(contrail_ctx())
    ctx.update(cassandra_ctx())
    ctx.update(discovery_ctx())
    render("contrail-collector.conf",
           "/etc/contrail/contrail-collector.conf", ctx)

def write_nodemgr_config():
    ctx = discovery_ctx()
    render("contrail-analytics-nodemgr.conf",
           "/etc/contrail/contrail-analytics-nodemgr.conf", ctx)

def write_query_engine_config():
    ctx = {}
    ctx.update(cassandra_ctx())
    ctx.update(discovery_ctx())
    render("contrail-query-engine.conf",
           "/etc/contrail/contrail-query-engine.conf", ctx)
