#!/bin/sh

mv /etc/apt/sources.list /etc/apt/sources.list.orig

cat << __EOF__ > /etc/apt/sources.list
deb http://10.84.5.100/contrail/images/ubuntu-14.04.2 trusty main restricted
__EOF__

apt-get update

apt-get install -y --force-yes openjdk-7-jre-headless=7u75-2.5.4-1~trusty1

sed -i 's/^jdk.tls.disabledAlgorithms/#jdk.tls.disabledAlgorithms/g' /usr/lib/jvm/default-java/jre/lib/security/java.security

service ifmap-server restart

