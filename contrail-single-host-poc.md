
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

Ubuntu 16.04.3 with 256GB memory, 1T disk, 32 vCPU

### Install packages

```
apt-get install bridge-utils ifenslave \
  qemu-kvm libvirt-bin virtinst libguestfs-tools \
  sshpass isc-dhcp-server
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

frontend contrail-webui-http
    bind 10.87.68.133:8080
    default_backend contrail-webui-http-backend

backend contrail-webui-http-backend
    balance roundrobin
    cookie SERVERID insert indirect nocache
    server 10.6.8.2 10.6.8.2:8180 cookie 10.6.8.2 weight 1 maxconn 1024 check
```

## Build POC

* vQFX vmdk image for RE and PFE.
* CentOS image `CentOS-7-x86_64-GenericCloud-1805.qcow2`.
* Cirros image `cirros-0.4.0-x86_64-disk.img`.
* Playbook `contrail-ansible-deployer-5.0.1-0.214.tgz`.
* Script `poc`.
* deploy-command
* command_servers.yml
* playbook.patch

```
./poc build-poc
```


