#!/bin/bash

source openstackrc

create_key()
{
    openssl genrsa -des3 -out ca.key 1024 
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt  
    openssl x509  -in  ca.crt -out ca.pem 
    openssl genrsa -des3 -out ca-int_encrypted.key 1024 
    openssl rsa -in ca-int_encrypted.key -out ca-int.key 
    openssl req -new -key ca-int.key -out ca-int.csr \
        -subj "/CN=ca-int@acme.com" 
    openssl x509 -req -days 3650 -in ca-int.csr -CA ca.crt \
        -CAkey ca.key -set_serial 01 -out ca-int.crt 
    openssl genrsa -des3 -out server_encrypted.key 1024 
    openssl rsa -in server_encrypted.key -out server.key 
    openssl req -new -key server.key -out server.csr \
        -subj "/CN=server@acme.com" 
    openssl x509 -req -days 3650 -in server.csr -CA ca-int.crt \
        -CAkey ca-int.key -set_serial 01 -out server.crt
}

create_container()
{
    barbican secret store --payload-content-type='text/plain' \
        --name='certificate' --payload="$(cat server.crt)"

    barbican secret store --payload-content-type='text/plain' \
        --name='private_key' --payload="$(cat server.key)"

    barbican container create --name='tls-container' --type='certificate' \
        --secret="certificate=$(barbican secret list | awk '/certificate/ {print $2}')" \
        --secret="private_key=$(barbican secret list | awk '/private_key/ {print $2}')"
}

launch_vm()
{
    echo "Add key..."
    key=$(nova keypair-list | awk '/vm-key/ {print $2}')
    if [ ! $key ]
    then
        nova keypair-add --pub-key id_rsa.pub vm-key
    fi

    echo "Launch VM..."
    vn_id=$(neutron net-list | awk '/ private / {print $2}')
    nova --os-tenant-name lbaas boot \
        --image cirros \
        --flavor m1.tiny \
        --key-name vm-key \
        --nic net-id=$vn_id \
        host1

    nova --os-tenant-name lbaas boot \
        --image cirros \
        --flavor m1.tiny \
        --key-name vm-key \
        --nic net-id=$vn_id \
        host2

    nova --os-tenant-name lbaas boot \
        --image cirros \
        --flavor m1.tiny \
        --key-name vm-key \
        --nic net-id=$vn_id \
        test
}

create_lb()
{
    subnet_id=$(neutron subnet-list | awk '/192.168/ {print $2}')
    neutron --os-tenant-name lbaas lbaas-loadbalancer-create \
        --name lb \
        --vip-address 192.168.10.250 \
        $subnet_id

    neutron --os-tenant-name lbaas lbaas-listener-create \
        --name lb-http \
        --loadbalancer lb \
        --protocol HTTP \
        --protocol-port 80

    neutron --os-tenant-name lbaas lbaas-listener-create \
        --name lb-https \
        --loadbalancer lb \
        --default-tls-container=$(barbican container list | awk '/tls-container/ {print $2}')
        --protocol TERMINATED_HTTPS \
        --protocol-port 443

    neutron --os-tenant-name lbaas lbaas-pool-create \
        --name lb-pool-http \
        --lb-algorithm ROUND_ROBIN \
        --listener lb-http \
        --protocol HTTP

    neutron --os-tenant-name lbaas lbaas-pool-create \
        --name lb-pool-https \
        --lb-algorithm ROUND_ROBIN \
        --listener lb-https \
        --protocol HTTP

    neutron --os-tenant-name lbaas lbaas-member-create \
        --subnet $subnet_id \
        --address 192.168.10.3 \
        --protocol-port 80 \
        lb-pool-http

    neutron --os-tenant-name lbaas lbaas-member-create \
        --subnet $subnet_id \
        --address 192.168.10.4 \
        --protocol-port 80 \
        lb-pool-http

    neutron --os-tenant-name lbaas lbaas-member-create \
        --subnet $subnet_id \
        --address 192.168.10.3 \
        --protocol-port 80 \
        lb-pool-https

    neutron --os-tenant-name lbaas lbaas-member-create \
        --subnet $subnet_id \
        --address 192.168.10.4 \
        --protocol-port 80 \
        lb-pool-https
}

help()
{
    echo "help"
}

main()
{
    case "$1" in
        launch-vm)
            shift
            launch_vm "$@"
            ;;
        create-lb)
            shift
            create_key
            create_container
            create_lb "$@"
            ;;
        *)
            help
            ;;
    esac
}

main "$@"
exit 0

