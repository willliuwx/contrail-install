import os
import pwd
import shutil
from socket import gethostbyname, gethostname
from subprocess import (
    CalledProcessError,
    check_call,
    check_output
)

import apt_pkg
from apt_pkg import version_compare
import json

from charmhelpers.core.hookenv import (
    local_unit,
    log,
    related_units,
    relation_get,
    relation_ids,
    relation_type,
    remote_unit,
    unit_get
)
from charmhelpers.core.host import service_restart
from charmhelpers.core.templating import render

apt_pkg.init()

def dpkg_version(pkg):
    try:
        return check_output(["dpkg-query", "-f", "${Version}\\n", "-W", pkg]).rstrip()
    except CalledProcessError:
        return None

CONTRAIL_VERSION = dpkg_version("contrail-control")

def contrail_api_ctx():
    ctxs = [ { "api_server": gethostbyname(relation_get("private-address", unit, rid)),
               "api_port": port }
             for rid in relation_ids("contrail-api")
             for unit, port in
             ((unit, relation_get("port", unit, rid)) for unit in related_units(rid))
             if port ]
    return ctxs[0] if ctxs else {}

def contrail_ctx():
    return { "host_ip": gethostbyname(unit_get("private-address")) }

def contrail_discovery_ctx():
    ctxs = [ { "discovery_server": vip if vip \
                 else gethostbyname(relation_get("private-address", unit, rid)),
               "discovery_port": port }
             for rid in relation_ids("contrail-discovery")
             for unit, port, vip in
             ((unit, relation_get("port", unit, rid), relation_get("vip", unit, rid))
              for unit in related_units(rid))
             if port ]
    return ctxs[0] if ctxs else {}

def contrail_ifmap_ctx():
    ctxs = []
    unit = local_unit()
    for rid in relation_ids("contrail-ifmap"):
        for u in related_units(rid):
            creds = relation_get("creds", u, rid)
            if creds:
                creds = json.loads(creds)
                if unit in creds:
                    cs = creds[unit]
                    ctx = {}
                    ctx["ifmap_user"] = cs["username"]
                    ctx["ifmap_password"] = cs["password"]
                    ctxs.append(ctx)
    return ctxs[0] if ctxs else {}

def fix_nodemgr():
    # add files missing from contrail-nodemgr package
    shutil.copy("files/contrail-nodemgr-control.ini",
                "/etc/contrail/supervisord_control_files")
    pw = pwd.getpwnam("contrail")
    os.chown("/etc/contrail/supervisord_control_files/contrail-nodemgr-control.ini",
             pw.pw_uid, pw.pw_gid)
    shutil.copy("files/contrail-control-nodemgr", "/etc/init.d")
    os.chmod("/etc/init.d/contrail-control-nodemgr", 0755)
    service_restart("supervisor-control")

def fix_permissions():
    os.chmod("/etc/contrail", 0755)
    os.chown("/etc/contrail", 0, 0)

def identity_admin_ctx():
    ctxs = [ { "auth_host": gethostbyname(hostname),
               "auth_port": relation_get("service_port", unit, rid) }
             for rid in relation_ids("identity-admin")
             for unit, hostname in
             ((unit, relation_get("service_hostname", unit, rid)) for unit in related_units(rid))
             if hostname ]
    return ctxs[0] if ctxs else {}

def provision_control():
    host_name = gethostname()
    host_ip = gethostbyname(unit_get("private-address"))
    a_ip, a_port = [ (gethostbyname(relation_get("private-address", unit, rid)),
                      port)
                     for rid in relation_ids("contrail-api")
                     for unit, port in
                     ((unit, relation_get("port", unit, rid)) for unit in related_units(rid))
                     if port ][0]
    user, password, tenant = [ (relation_get("service_username", unit, rid),
                                relation_get("service_password", unit, rid),
                                relation_get("service_tenant_name", unit, rid))
                               for rid in relation_ids("identity-admin")
                               for unit in related_units(rid) ][0]
    log("Provisioning control {}".format(host_ip))
    check_call(["contrail-provision-control",
                "--host_name", host_name,
                "--host_ip", host_ip,
                "--router_asn", "64512",
                "--api_server_ip", a_ip,
                "--api_server_port", str(a_port),
                "--oper", "add",
                "--admin_user", user,
                "--admin_password", password,
                "--admin_tenant_name", tenant])

def units(relation):
    """Return a list of units for the specified relation"""
    return [ unit for rid in relation_ids(relation)
                  for unit in related_units(rid) ]

def unprovision_control():
    if not remote_unit():
        return
    host_name = gethostname()
    host_ip = gethostbyname(unit_get("private-address"))
    relation = relation_type()
    a_ip = None
    a_port = None
    if relation == "contrail-api":
        a_ip = gethostbyname(relation_get("private-address"))
        a_port = relation_get("port")
    else:
        a_ip, a_port = [ (gethostbyname(relation_get("private-address", unit, rid)),
                          relation_get("port", unit, rid))
                         for rid in relation_ids("contrail-api")
                         for unit in related_units(rid) ][0]
    user = None
    password = None
    tenant = None
    if relation == "identity-admin":
        user = relation_get("service_username")
        password = relation_get("service_password")
        tenant = relation_get("service_tenant_name")
    else:
        user, password, tenant = [ (relation_get("service_username", unit, rid),
                                    relation_get("service_password", unit, rid),
                                    relation_get("service_tenant_name", unit, rid))
                                   for rid in relation_ids("identity-admin")
                                   for unit in related_units(rid) ][0]
    log("Unprovisioning control {}".format(host_ip))
    check_call(["contrail-provision-control",
                "--host_name", host_name,
                "--host_ip", host_ip,
                "--router_asn", "64512",
                "--api_server_ip", a_ip,
                "--api_server_port", str(a_port),
                "--oper", "del",
                "--admin_user", user,
                "--admin_password", password,
                "--admin_tenant_name", tenant])

def write_control_config():
    ctx = {}
    ctx.update(contrail_ctx())
    ctx.update(contrail_discovery_ctx())
    ctx.update(contrail_ifmap_ctx())
    target = "/etc/contrail/contrail-control.conf" \
             if version_compare(CONTRAIL_VERSION, "2.0") >= 0 \
             else "/etc/contrail/control-node.conf"
    render("control-node.conf", target, ctx, "root", "contrail", 0440)

def write_nodemgr_config():
    ctx = contrail_discovery_ctx()
    render("contrail-control-nodemgr.conf",
           "/etc/contrail/contrail-control-nodemgr.conf", ctx)

def write_vnc_api_config():
    ctx = {}
    ctx.update(contrail_api_ctx())
    ctx.update(identity_admin_ctx())
    render("vnc_api_lib.ini", "/etc/contrail/vnc_api_lib.ini", ctx)
