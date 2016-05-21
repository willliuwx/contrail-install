#!/bin/sh

mkdir -p /var/crashes

ip=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d"/" -f1)
hostname=$(hostname)

echo "$ip    $hostname" >> /etc/hosts

apt-get install -y ntp > /dev/null 2>&1

cat << __EOF__ > /etc/ntp.conf
restrict 127.0.0.1
restrict ::1
server 127.127.1.0 iburst
driftfile /var/lib/ntp/drift
__EOF__

service ntp restart > /dev/null 2>&1

