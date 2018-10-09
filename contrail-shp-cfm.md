
# Single Host POC

# Contrail 5.0.1 Fabric Management

## Topology

```
                            +-------------+
                            |   client    |
                            | 172.16.1.10 |
                            +-------------+
                                   |
                                 br-ext
                                   |
  +------------------------+---------------------+------------------------+
  | vqfx-s1                |  xe-0/0/0           |                        |
  |  em0: 10.6.1.21        |  172.16.1.254/24    |                        |
  |  lo0: 10.6.0.21                                                       |
  |  ASN: 64021                                                           |
  |                                                                       |
  |  10.6.50.1/30       |  |  10.6.50.5/30       |  |  10.6.50.9/30       |
  |  xe-0/0/1           |  |  xe-0/0/2           |  |  xe-0/0/3           |
  +---------------------+--+---------------------+--+---------------------+
          |                        |                        |
       br-s1-xe1                br-s1-xe2                br-s1-xe3
          |                        |                        |
  +---------------------+  +---------------------+  +---------------------+
  |  xe-0/0/0           |  |  xe-0/0/0           |  |  xe-0/0/0           |
  |  10.6.50.2/30       |  |  10.6.50.6/30       |  |  10.6.50.10/30      |
  |                     |  |                     |  |                     |
  | vqfx-l1             |  | vqfx-l2             |  | vqfx-l3             |
  |  em0: 10.6.8.11     |  |  em0: 10.6.8.12     |  |  em0: 10.6.8.13     |
  |  lo0: 10.6.0.11     |  |  lo0: 10.6.0.13     |  |  lo0: 10.6.0.13     |
  |  ASN: 64011         |  |  ASN: 64012         |  |  ASN: 64013         |
  |                     |  |                     |  |                     |
  | xe-0/0/1            |  | xe-0/0/1 | xe-0/0/2 |  | xe-0/0/1 | xe-0/0/2 |
  +---------------------+  +----------+----------+  +----------+----------+
       |                        |          |             |          |
    br-l1-xe1                br-l2-xe1  br-l2-xe2     br-l3-xe1  br-l3-xe2
       |                        |          |             |          |
  +------------+            +-------+      |         +-------+      |
  | command    |            | bms21 |      |         | bms31 |      |
  |  10.6.8.10 |            +-------+      |         +-------+      |
  | openstack  |                           |                        |
  |  10.6.8.1  |                       +--------------------------------+
  | contrail   |                       |          bms-dh                |
  |  10.6.8.2  |                       +--------------------------------+
  | csn        |
  |  10.6.8.3  |        management: 10.6.8.0/24
  | compute    |        lookback:   10.6.0.0/24
  |  10.6.8.4  |        spine-leaf: 10.6.50.0/24
  +------------+        rack-1:     10.6.11.0/24
        |               rack-2:     10.6.12.0/24
      br-int            rack-3:     10.6.13.0/24
    10.6.8.254
        |
     HAProxy
  Contrail web UI:   http://<host>:8180
  Contrail Command:  https://<host>:9091
  OpenStack Horizon: http://<host>
```


## Resource
```
              vCPU    memory(GB)    disk(GB)    OS
command         4        32            100      CentOS 7.5-1805
openstack       6        48            150      CentOS 7.5-1805
contrail        6        48            150      CentOS 7.5-1805
csn             2        16             80      CentOS 7.5-1805
compute         4        32            100      CentOS 7.5-1805
vqfx-s1-re      1         1                     Junos 18.1
vqfx-s1-pfe     1         2                     Junos 18.1
vqfx-l1-re      1         1                     Junos 18.1
vqfx-l1-pfe     1         2                     Junos 18.1
vqfx-l2-re      1         1                     Junos 18.1
vqfx-l2-pfe     1         2                     Junos 18.1
vqfx-l3-re      1         1                     Junos 18.1
vqfx-l3-pfe     1         2                     Junos 18.1
bms21           1         1                     Cirros 0.4.0
bms22           1         1                     Cirros 0.4.0
bms-dh          1         1                     CentOS 7.5-1805
client          1         1                     Cirros 0.4.0
----------------------------------------------------------------
Total          35       193
```


## Build host

### Ubuntu 16.04.3 with 256GB memory, 2T disk, 32 vCPU
Install packages.
```
apt-get install sshpass isc-dhcp-server
```

### CentOS 7.5 with 256GB memory, 2T disk, 32 vCPU
Install packages.
```
yum install sshpass dhcp
```

`sshpass` is for SSH to vQFX with password in command line. This is only for initialization. After that, SSH key will be used.

`isc-dhcp-server` is for providing DHCP service to vQFX for initialization. After that, static address will be configured on vQFX.

### SSH key
```
ssh-keygen
```

### Enable SNAT

Enable SNAT on the host for the cluster to access external/internet.

Ensure `ip_forward` is enabled. Otherwise, enable it in `/etc/sysctl.conf`.
```
cat /proc/sys/net/ipv4/ip_forward
```

Add `iptables` rule into NAT table.
```
iptables -t nat -A POSTROUTING -o br-mgmt -j SNAT --to 10.87.68.133
```

### Enable HAProxy

This for accessing cluster, like web UI, API, etc.
```
apt-get install haproxy
```

```
listen openstack_horizon
  bind 10.87.68.133:80
  server 10.6.8.1 10.6.8.1:80 check inter 2000 rise 2 fall 5

listen contrail-command
  bind 10.87.68.133:9091
  mode tcp
  server 10.6.8.10 10.6.8.10:9091 check inter 2000 rise 2 fall 5

listen contrail-webui
  bind 10.87.68.133:8180
  server 10.6.8.2 10.6.8.2:8180 check inter 2000 rise 2 fall 5
```

### Enable firewall rule for CentOS
Enable VNC access.
```
iptables -A IN_public -p tcp --match multiport --dports 5900:5999 -j ACCEPT
```

## Build POC

* vQFX vmdk image for RE and PFE.
* CentOS image `CentOS-7-x86_64-GenericCloud-1805.qcow2`.
* Cirros image `cirros-0.4.0-x86_64-disk.img`.
* Playbook `contrail-ansible-deployer-5.0.1-0.214.tgz`.
* Script `poc`, `contrail-command`.
* command_servers.yml, instances.yaml
* playbook.patch

```
./poc build-poc
```
or
```
./poc create-bridge
./poc launch-vqfx
./poc configure-vqfx
./poc launch-bms
```

## Post deployment

Contrail Command Cluster:Advanced Options:Endpoints,
Update nodejs endpoint to `http://10.6.11.2:8180`.

Infrastructure:Servers, unassign role `vrouter` on `csn`. Add `csn` to Cluster:ClusterNodes:ServiceNodes.

Update ingress rule in default SG.

Contrail web UI -> Configure -> Infrastructure -> Project Settings -> Other Settings, enable `VxLAN Routing`.

Add default route `10.6.0.0/24 via 10.6.11.254` to all cluster nodes for reaching loopback addresses.

## Import fabric

Physical routers, BGP routers and a default logical router are created.

Assign role, leaf vQFX is `leaf` and `CRB-Access`, spine vQFX is `spine` and `CRB-Gateway` and `DC-Gateway`.

Check fabric device to ensure CSN is assocated.


## Overlay BGP

Overlay BGP peering is configured on all devices.

vqfx-l1
```
set groups __contrail_basic__ snmp community public authorization read-only
set groups __contrail_ip_clos__ routing-options router-id 10.6.0.11
set groups __contrail_ip_clos__ routing-options route-distinguisher-id 10.6.0.11
set groups __contrail_ip_clos__ routing-options forwarding-table export PFE-LB
set groups __contrail_ip_clos__ routing-options forwarding-table ecmp-fast-reroute
set groups __contrail_ip_clos__ policy-options policy-statement PFE-LB then load-balance per-packet
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from interface lo0.0
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term default then reject
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol bgp
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term default then reject
set groups __contrail_overlay_bgp__ routing-options resolution rib bgp.rtarget.0 resolution-ribs inet.0
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 type internal
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-address 10.6.0.11
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 hold-time 90
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family evpn signaling
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family route-target
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 export _contrail_ibgp_export_policy
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 multipath
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.11.2 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.21 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.13 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.12 peer-as 64512
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet-vpn then next-hop self
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet6-vpn then next-hop self
set groups __contrail_overlay_evpn__ protocols evpn encapsulation vxlan
set groups __contrail_overlay_evpn__ protocols evpn multicast-mode ingress-replication
set groups __contrail_overlay_evpn__ protocols evpn extended-vni-list all
set groups __contrail_overlay_evpn__ switch-options vtep-source-interface lo0.0
set groups __contrail_overlay_evpn__ switch-options route-distinguisher 10.6.0.11:1
set groups __contrail_overlay_evpn__ switch-options vrf-target target:64512:1
set groups __contrail_overlay_evpn__ switch-options vrf-target auto
```

vqfx-l2
```
set groups __contrail_basic__ snmp community public authorization read-only
set groups __contrail_ip_clos__ routing-options router-id 10.6.0.12
set groups __contrail_ip_clos__ routing-options route-distinguisher-id 10.6.0.12
set groups __contrail_ip_clos__ routing-options forwarding-table export PFE-LB
set groups __contrail_ip_clos__ routing-options forwarding-table ecmp-fast-reroute
set groups __contrail_ip_clos__ policy-options policy-statement PFE-LB then load-balance per-packet
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from interface lo0.0
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term default then reject
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol bgp
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term default then reject
set groups __contrail_overlay_bgp__ routing-options resolution rib bgp.rtarget.0 resolution-ribs inet.0
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 type internal
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-address 10.6.0.12
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 hold-time 90
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family evpn signaling
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family route-target
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 export _contrail_ibgp_export_policy
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 multipath
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.11.2 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.21 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.13 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.11 peer-as 64512
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet-vpn then next-hop self
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet6-vpn then next-hop self
set groups __contrail_overlay_evpn__ protocols evpn encapsulation vxlan
set groups __contrail_overlay_evpn__ protocols evpn multicast-mode ingress-replication
set groups __contrail_overlay_evpn__ protocols evpn extended-vni-list all
set groups __contrail_overlay_evpn__ switch-options vtep-source-interface lo0.0
set groups __contrail_overlay_evpn__ switch-options route-distinguisher 10.6.0.12:1
set groups __contrail_overlay_evpn__ switch-options vrf-target target:64512:1
set groups __contrail_overlay_evpn__ switch-options vrf-target auto
```

vqfx-l3
```
set groups __contrail_basic__ snmp community public authorization read-only
set groups __contrail_ip_clos__ routing-options router-id 10.6.0.13
set groups __contrail_ip_clos__ routing-options route-distinguisher-id 10.6.0.13
set groups __contrail_ip_clos__ routing-options forwarding-table export PFE-LB
set groups __contrail_ip_clos__ routing-options forwarding-table ecmp-fast-reroute
set groups __contrail_ip_clos__ policy-options policy-statement PFE-LB then load-balance per-packet
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from interface lo0.0
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term default then reject
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol bgp
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term default then reject
set groups __contrail_overlay_bgp__ routing-options resolution rib bgp.rtarget.0 resolution-ribs inet.0
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 type internal
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-address 10.6.0.13
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 hold-time 90
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family evpn signaling
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family route-target
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 export _contrail_ibgp_export_policy
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 multipath
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.11.2 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.21 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.12 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.11 peer-as 64512
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet-vpn then next-hop self
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet6-vpn then next-hop self
set groups __contrail_overlay_evpn__ protocols evpn encapsulation vxlan
set groups __contrail_overlay_evpn__ protocols evpn multicast-mode ingress-replication
set groups __contrail_overlay_evpn__ protocols evpn extended-vni-list all
set groups __contrail_overlay_evpn__ switch-options vtep-source-interface lo0.0
set groups __contrail_overlay_evpn__ switch-options route-distinguisher 10.6.0.13:1
set groups __contrail_overlay_evpn__ switch-options vrf-target target:64512:1
set groups __contrail_overlay_evpn__ switch-options vrf-target auto
```

vqfx-s1
```
set groups __contrail_basic__ snmp community public authorization read-only
set groups __contrail_ip_clos__ routing-options router-id 10.6.0.21
set groups __contrail_ip_clos__ routing-options route-distinguisher-id 10.6.0.21
set groups __contrail_ip_clos__ routing-options forwarding-table export PFE-LB
set groups __contrail_ip_clos__ routing-options forwarding-table ecmp-fast-reroute
set groups __contrail_ip_clos__ policy-options policy-statement PFE-LB then load-balance per-packet
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback from interface lo0.0
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_EXP term default then reject
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol bgp
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback from protocol direct
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term loopback then accept
set groups __contrail_ip_clos__ policy-options policy-statement IPCLOS_BGP_IMP term default then reject
set groups __contrail_overlay_bgp__ routing-options resolution rib bgp.rtarget.0 resolution-ribs inet.0
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 type internal
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-address 10.6.0.21
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 hold-time 90
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family evpn signaling
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 family route-target
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 export _contrail_ibgp_export_policy
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 local-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 multipath
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.11.2 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.13 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.12 peer-as 64512
set groups __contrail_overlay_bgp__ protocols bgp group _contrail_asn-64512 neighbor 10.6.0.11 peer-as 64512
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet-vpn then next-hop self
set groups __contrail_overlay_bgp__ policy-options policy-statement _contrail_ibgp_export_policy term inet6-vpn then next-hop self
set groups __contrail_overlay_evpn__ protocols evpn encapsulation vxlan
set groups __contrail_overlay_evpn__ protocols evpn multicast-mode ingress-replication
set groups __contrail_overlay_evpn__ protocols evpn extended-vni-list all
set groups __contrail_overlay_evpn__ switch-options vtep-source-interface lo0.0
set groups __contrail_overlay_evpn__ switch-options route-distinguisher 10.6.0.21:1
set groups __contrail_overlay_evpn__ switch-options vrf-target target:64512:1
set groups __contrail_overlay_evpn__ switch-options vrf-target auto
```

vqfx-s1 logical router
```
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-import term t1 from community target_64512_8000004
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-export term t1 then community add target_64512_8000004
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000004 members target:64512:8000004
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-import
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-export
set groups __contrail_overlay_evpn_type5__ interfaces lo0 unit 1005 family inet address 127.0.0.1/32
set groups __contrail_overlay_evpn_type5__ protocols evpn default-gateway no-gateway-community
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 instance-type vrf
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 interface lo0.1005
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 vrf-import _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-import
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 vrf-export _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5-export
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 protocols evpn ip-prefix-routes advertise direct-nexthop
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 protocols evpn ip-prefix-routes encapsulation vxlan
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 protocols evpn ip-prefix-routes vni 5
```

vqfx-s1 DC-Gateway
```
set groups __contrail_overlay_evpn_type5__ forwarding-options family inet filter input redirect_to_public_vrf_filter
set groups __contrail_overlay_evpn_type5__ firewall family inet filter redirect_to_public_vrf_filter term term-5 then routing-instance _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5
set groups __contrail_overlay_evpn_type5__ firewall family inet filter redirect_to_public_vrf_filter term default-term then accept
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_ea1d61ae-3fba-41e1-8374-827209ad9910__-l3-5 routing-options static route 0.0.0.0/0 next-table inet.0
```

Check `bgp summary` on each vQFX, all underlay and overlay BGP peering should be all established.
```
root@vqfx-l1> show bgp summary    
Groups: 2 Peers: 5 Down peers: 0
Table          Tot Paths  Act Paths Suppressed    History Damp State    Pending
bgp.rtarget.0        
                       6          6          0          0          0          0
inet.0               
                       8          5          0          0          0          0
bgp.evpn.0           
                       0          0          0          0          0          0
Peer                     AS      InPkt     OutPkt    OutQ   Flaps Last Up/Dwn State|#Active/Received/Accepted/Damped...
10.6.0.12             64512        375        374       0       0     2:48:23 Establ
  bgp.rtarget.0: 1/1/1/0
  bgp.evpn.0: 0/0/0/0
  default-switch.evpn.0: 0/0/0/0
  __default_evpn__.evpn.0: 0/0/0/0
10.6.0.13             64512         80         79       0       0       34:07 Establ
  bgp.rtarget.0: 1/1/1/0
  bgp.evpn.0: 0/0/0/0
  default-switch.evpn.0: 0/0/0/0
  __default_evpn__.evpn.0: 0/0/0/0
10.6.0.21             64512        375        375       0       0     2:48:31 Establ
  bgp.rtarget.0: 1/1/1/0
  bgp.evpn.0: 0/0/0/0
  default-switch.evpn.0: 0/0/0/0
  __default_evpn__.evpn.0: 0/0/0/0
10.6.11.2             64512         10         10       0       0        3:12 Establ
  bgp.rtarget.0: 3/3/3/0
  bgp.evpn.0: 0/0/0/0
  default-switch.evpn.0: 0/0/0/0
  __default_evpn__.evpn.0: 0/0/0/0
10.6.50.1             64021       1992       1997       0       0    14:55:26 Establ
  inet.0: 5/8/8/0

{master:0}
```

## Add BMS `bms21`, `bms31` and `bms-dh` to Infrastructure -> Servers.

## Create VN `red` 192.168.10.0/24 and `blue` 192.168.20.0/24.

## Launch VM `vm1-red` on VN `red` and VM `vm1-blue` on VN `blue`.

## Create BMS instance `bms21` on VN `red`.

Interface and VxLAN are configured on `vqfx-l2`.
```
set groups __contrail_overlay_evpn__ protocols evpn vni-options vni 6 vrf-target target:64512:8000005
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 flexible-vlan-tagging
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 native-vlan-id 4094
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 encapsulation extended-vlan-bridge
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 unit 0 vlan-id 4094
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-import term t1 from community target_64512_8000005
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000005 members target:64512:8000005
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail_red-l2-6-import
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail_red-l2-6-export
set groups __contrail_overlay_evpn__ vlans contrail_red-l2-6 interface xe-0/0/1.0
set groups __contrail_overlay_evpn__ vlans contrail_red-l2-6 vxlan vni 6
```

```
root@vqfx-l2> show ethernet-switching table 

MAC flags (S - static MAC, D - dynamic MAC, L - locally learned, P - Persistent static
           SE - statistics enabled, NM - non configured MAC, R - remote PE MAC, O - ovsdb MAC)


Ethernet switching table : 2 entries, 2 learned
Routing instance : default-switch
   Vlan                MAC                 MAC      Logical                Active
   name                address             flags    interface              source
   contrail_red-l2-6   02:cd:3f:ba:e4:58   D        vtep.32770             10.6.11.4                     
   contrail_red-l2-6   52:54:00:11:3f:5b   D        xe-0/0/1.0           

{master:0}
root@vqfx-l2> show evpn database 
Instance: default-switch
VLAN  DomainId  MAC address        Active source                  Timestamp        IP address
     6          02:cd:3f:ba:e4:58  10.6.11.4                      Sep 29 20:52:38  192.168.10.3
     6          52:54:00:11:3f:5b  xe-0/0/1.0                     Sep 29 20:55:11

{master:0}
root@vqfx-l2> show route table default-switch.evpn.0 

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

2:10.6.0.12:1::6::52:54:00:11:3f:5b/304 MAC/IP        
                   *[EVPN/170] 03:38:07
                      Indirect
2:10.6.11.4:2::6::02:cd:3f:ba:e4:58/304 MAC/IP        
                   *[BGP/170] 03:40:41, MED 100, localpref 200, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.5 via xe-0/0/0.0
2:10.6.11.4:2::6::02:cd:3f:ba:e4:58::192.168.10.3/304 MAC/IP        
                   *[BGP/170] 03:40:41, MED 100, localpref 200, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.5 via xe-0/0/0.0
3:10.6.0.12:1::6::10.6.0.12/248 IM            
                   *[EVPN/170] 03:40:40
                      Indirect
3:10.6.11.3:2::6::10.6.11.3/248 IM            
                   *[BGP/170] 03:31:02, MED 200, localpref 100, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.5 via xe-0/0/0.0
3:10.6.11.4:2::6::10.6.11.4/248 IM            
                   *[BGP/170] 03:40:40, MED 200, localpref 100, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.5 via xe-0/0/0.0

{master:0}
root@vqfx-l2> show route receive-protocol bgp 10.6.11.2 

inet.0: 13 destinations, 16 routes (13 active, 0 holddown, 0 hidden)

:vxlan.inet.0: 9 destinations, 9 routes (9 active, 0 holddown, 0 hidden)

inet6.0: 2 destinations, 2 routes (2 active, 0 holddown, 0 hidden)

bgp.rtarget.0: 15 destinations, 15 routes (15 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  64512:64512:8000000/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000004/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000005/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000006/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:0/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:1/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:3/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:6/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:7/96                    
*                         10.6.11.2                    100        I

bgp.evpn.0: 4 destinations, 4 routes (4 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.11.4:2::6::02:cd:3f:ba:e4:58/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  2:10.6.11.4:2::6::02:cd:3f:ba:e4:58::192.168.10.3/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  3:10.6.11.3:2::6::10.6.11.3/248 IM                
*                         10.6.11.3            200     100        ?
  3:10.6.11.4:2::6::10.6.11.4/248 IM                
*                         10.6.11.4            200     100        ?

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.11.4:2::6::02:cd:3f:ba:e4:58/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  2:10.6.11.4:2::6::02:cd:3f:ba:e4:58::192.168.10.3/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  3:10.6.11.3:2::6::10.6.11.3/248 IM                
*                         10.6.11.3            200     100        ?
  3:10.6.11.4:2::6::10.6.11.4/248 IM                
*                         10.6.11.4            200     100        ?

{master:0}
root@vqfx-l2> show route advertising-protocol bgp 10.6.11.2 

bgp.rtarget.0: 15 destinations, 15 routes (15 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  64012:64012:268435462/96                    
*                         Self                         100        I
  64012:64512:1/96                    
*                         Self                         100        I
  64012:64512:8000005/96                    
*                         Self                         100        I

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.0.12:1::6::52:54:00:11:3f:5b/304 MAC/IP            
*                         Self                         100        I
  3:10.6.0.12:1::6::10.6.0.12/248 IM                
*                         Self                         100        I

{master:0}
```

* Two type-3 multicast routes are advetised by Contrail. When VN `red` is created, Contrail adds a type-3 multicast route of CSN. When VM `vm1-red` on VN `red` is created on compute, Contrail adds a type-3 multicast route of compute.
* Two type-2 MAC/IP routes (one with MAC and one with IP) of VM `vm1-red` are advertised by Contrail.
* One type-3 multicast route of vQFX itself is advertised.
* One type-2 MAC/IP route (with MAC) of `bms21` is advertised. vQFX only does L2 learning, no type-2 MAC/IP route with IP.

* When BMS sends DHCP request, vQFX sends it to all type-3 routes in VXLAN. CSN responds the request.
* When BMS sends ARP request, vQFX sends it to all type-3 routes in VXLAN. VM on compute responds the request.
* When BMS sends packet to VM, vQFX sends it to compute based on type-2 route.


## Create BMS instance `bms31` on VN `blue`.

```
set groups __contrail_overlay_evpn__ protocols evpn vni-options vni 7 vrf-target target:64512:8000006
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 flexible-vlan-tagging
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 native-vlan-id 4094
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 encapsulation extended-vlan-bridge
set groups __contrail_overlay_evpn__ interfaces xe-0/0/1 unit 0 vlan-id 4094
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-import term t1 from community target_64512_8000006
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000006 members target:64512:8000006
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail_blue-l2-7-import
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail_blue-l2-7-export
set groups __contrail_overlay_evpn__ vlans contrail_blue-l2-7 interface xe-0/0/1.0
set groups __contrail_overlay_evpn__ vlans contrail_blue-l2-7 vxlan vni 7
```

```
root@vqfx-l3> show ethernet-switching table 

MAC flags (S - static MAC, D - dynamic MAC, L - locally learned, P - Persistent static
           SE - statistics enabled, NM - non configured MAC, R - remote PE MAC, O - ovsdb MAC)


Ethernet switching table : 2 entries, 2 learned
Routing instance : default-switch
   Vlan                MAC                 MAC      Logical                Active
   name                address             flags    interface              source
   contrail_blue-l2-7  02:f1:09:36:08:b6   D        vtep.32769             10.6.11.4                     
   contrail_blue-l2-7  52:54:00:c6:c7:77   D        xe-0/0/1.0           

{master:0}
root@vqfx-l3> show evpn database 
Instance: default-switch
VLAN  DomainId  MAC address        Active source                  Timestamp        IP address
     7          02:f1:09:36:08:b6  10.6.11.4                      Sep 30 00:50:29  192.168.20.3
     7          52:54:00:c6:c7:77  xe-0/0/1.0                     Sep 30 00:56:08

{master:0}
root@vqfx-l3> show route table default-switch.evpn.0 

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

2:10.6.0.13:1::7::52:54:00:c6:c7:77/304 MAC/IP        
                   *[EVPN/170] 00:01:45
                      Indirect
2:10.6.11.4:4::7::02:f1:09:36:08:b6/304 MAC/IP        
                   *[BGP/170] 00:07:25, MED 100, localpref 200, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.9 via xe-0/0/0.0
2:10.6.11.4:4::7::02:f1:09:36:08:b6::192.168.20.3/304 MAC/IP        
                   *[BGP/170] 00:07:25, MED 100, localpref 200, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.9 via xe-0/0/0.0
3:10.6.0.13:1::7::10.6.0.13/248 IM            
                   *[EVPN/170] 00:07:24
                      Indirect
3:10.6.11.3:4::7::10.6.11.3/248 IM            
                   *[BGP/170] 00:07:24, MED 200, localpref 100, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.9 via xe-0/0/0.0
3:10.6.11.4:4::7::10.6.11.4/248 IM            
                   *[BGP/170] 00:07:24, MED 200, localpref 100, from 10.6.11.2
                      AS path: ?, validation-state: unverified
                    > to 10.6.50.9 via xe-0/0/0.0

{master:0}
root@vqfx-l3> show route receive-protocol bgp 10.6.11.2 

inet.0: 13 destinations, 16 routes (13 active, 0 holddown, 0 hidden)

:vxlan.inet.0: 9 destinations, 9 routes (9 active, 0 holddown, 0 hidden)

inet6.0: 2 destinations, 2 routes (2 active, 0 holddown, 0 hidden)

bgp.rtarget.0: 17 destinations, 17 routes (17 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  64512:64512:8000000/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000004/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000005/96                    
*                         10.6.11.2                    100        I
  64512:64512:8000006/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:0/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:1/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:3/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:6/96                    
*                         10.6.11.2                    100        I
  64512:10.6.11.2:7/96                    
*                         10.6.11.2                    100        I

bgp.evpn.0: 4 destinations, 4 routes (4 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.11.4:4::7::02:f1:09:36:08:b6/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  2:10.6.11.4:4::7::02:f1:09:36:08:b6::192.168.20.3/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  3:10.6.11.3:4::7::10.6.11.3/248 IM                
*                         10.6.11.3            200     100        ?
  3:10.6.11.4:4::7::10.6.11.4/248 IM                
*                         10.6.11.4            200     100        ?

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.11.4:4::7::02:f1:09:36:08:b6/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  2:10.6.11.4:4::7::02:f1:09:36:08:b6::192.168.20.3/304 MAC/IP            
*                         10.6.11.4            100     200        ?
  3:10.6.11.3:4::7::10.6.11.3/248 IM                
*                         10.6.11.3            200     100        ?
  3:10.6.11.4:4::7::10.6.11.4/248 IM                
*                         10.6.11.4            200     100        ?

{master:0}
root@vqfx-l3> show route advertising-protocol bgp 10.6.11.2 

bgp.rtarget.0: 17 destinations, 17 routes (17 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  64013:64013:268435463/96                    
*                         Self                         100        I
  64013:64512:1/96                    
*                         Self                         100        I
  64013:64512:8000006/96                    
*                         Self                         100        I

default-switch.evpn.0: 6 destinations, 6 routes (6 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  2:10.6.0.13:1::7::52:54:00:c6:c7:77/304 MAC/IP            
*                         Self                         100        I
  3:10.6.0.13:1::7::10.6.0.13/248 IM                
*                         Self                         100        I

{master:0}
```

## Create logical router to connect VN `red` and `blue`.

```
set groups __contrail_overlay_evpn__ interfaces irb gratuitous-arp-reply
set groups __contrail_overlay_evpn__ interfaces irb unit 6 proxy-macip-advertisement
set groups __contrail_overlay_evpn__ interfaces irb unit 6 family inet address 192.168.10.7/24 virtual-gateway-address 192.168.10.1
set groups __contrail_overlay_evpn__ interfaces irb unit 7 proxy-macip-advertisement
set groups __contrail_overlay_evpn__ interfaces irb unit 7 family inet address 192.168.20.8/24 virtual-gateway-address 192.168.20.1
set groups __contrail_overlay_evpn__ protocols evpn vni-options vni 6 vrf-target target:64512:8000005
set groups __contrail_overlay_evpn__ protocols evpn vni-options vni 7 vrf-target target:64512:8000006
set groups __contrail_overlay_evpn__ protocols evpn encapsulation vxlan
set groups __contrail_overlay_evpn__ protocols evpn extended-vni-list all
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-import term t1 from community target_64512_8000005
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-export term t1 then community add target_64512_8000005
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_red-l2-6-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-import term t1 from community target_64512_8000006
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-export term t1 then community add target_64512_8000006
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail_blue-l2-7-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-import term t1 from community target_64512_8000004
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-import term t1 then accept
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-export term t1 then community add target_64512_8000004
set groups __contrail_overlay_evpn__ policy-options policy-statement _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-export term t1 then accept
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000005 members target:64512:8000005
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000006 members target:64512:8000006
set groups __contrail_overlay_evpn__ policy-options community target_64512_8000004 members target:64512:8000004
set groups __contrail_overlay_evpn__ switch-options vtep-source-interface lo0.0
set groups __contrail_overlay_evpn__ switch-options route-distinguisher 10.6.0.21:1
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail_red-l2-6-import
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail_blue-l2-7-import
set groups __contrail_overlay_evpn__ switch-options vrf-import _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-import
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail_red-l2-6-export
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail_blue-l2-7-export
set groups __contrail_overlay_evpn__ switch-options vrf-export _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-export
set groups __contrail_overlay_evpn__ switch-options vrf-target target:64512:1
set groups __contrail_overlay_evpn__ vlans bd-6 vlan-id 6
set groups __contrail_overlay_evpn__ vlans bd-6 l3-interface irb.6
set groups __contrail_overlay_evpn__ vlans bd-6 vxlan vni 6
set groups __contrail_overlay_evpn__ vlans bd-7 vlan-id 7
set groups __contrail_overlay_evpn__ vlans bd-7 l3-interface irb.7
set groups __contrail_overlay_evpn__ vlans bd-7 vxlan vni 7
set groups __contrail_overlay_evpn_type5__ interfaces lo0 unit 1005 family inet address 127.0.0.1/32
set groups __contrail_overlay_evpn_type5__ protocols evpn default-gateway no-gateway-community
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 instance-type vrf
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 interface lo0.1005
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 interface irb.7
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 interface irb.6
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 vrf-import _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-import
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 vrf-export _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5-export
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 protocols evpn ip-prefix-routes advertise direct-nexthop
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 protocols evpn ip-prefix-routes encapsulation vxlan
set groups __contrail_overlay_evpn_type5__ routing-instances _contrail___contrail_lr_internal_vn_7a6eaced-3942-4f01-87c8-cde26436acf8__-l3-5 protocols evpn ip-prefix-routes vni 1002
```

* `bms21` 192.168.10.4 ping `vm1-blue` 192.168.20.3.
* `bms21` sends ARP request for subnet gateway 192.168.10.1.
* vqfx-l1 sends request to all type-3 multicast routes (spine, CSN, compute).
* Vrouter is the subnet gateway for VM, but not BMS. So vrouter doesn't respond.
* Spine is the L3 GW for BMS, it responds the ARP request.
* `bms21` sends ICMP request to the spine.
* Spine does L3 routing and sends request to `vm1-blue` on compute.
* `vm1-blue` sends reply back to the spine who sends it back to `bms21`.



