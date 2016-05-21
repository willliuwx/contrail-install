#!/bin/sh

set_ntp()
{
    rm -f /etc/ntp.conf
    DEBIAN_FRONTEND=noninteractive apt-get install -y ntp
    cat << _EOT_ > /etc/ntp.conf
driftfile /var/lib/ntp/drift
server 10.84.5.100
restrict 127.0.0.1
restrict -6 ::1
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
_EOT_
    service ntp restart
}

set_controller_interface()
{
    cat << _EOT_ > /etc/network/interfaces.d/eth0.cfg
auto eth0
iface eth0 inet manual

auto lxcbr0
iface lxcbr0 inet dhcp
    bridge_ports eth0

_EOT_

    ifdown eth0 && ifup eth0 lxcbr0
}

install_lxc()
{
    DEBIAN_FRONTEND=noninteractive apt-get install -y lxc
}

set_lxc_hook()
{
    cp ubuntu-cloud.trusty.conf /usr/share/lxc/config
    cp user-hook-local /usr/share/lxc/hooks/user-hook
}

help()
{
    echo "Usage:"
    echo "$0 machine"
    echo "$0 lxc"
    echo "$0 compute"
    echo ""
    exit 0
}

machine_setup()
{
    set_ntp
}

lxc_setup()
{
    set_controller_interface
    set_ntp
    install_lxc
    set_lxc_hook
}

compute_setup()
{
    set_ntp
}

main()
{
    case "$1" in
        machine)
            shift
            machine_setup "$@"
            ;;
        lxc)
            shift
            lxc_setup "$@"
            ;;
        compute)
            shift
            compute_setup "$@"
            ;;
        *)
            help
            ;;
    esac
}

main "$@"
exit 0

