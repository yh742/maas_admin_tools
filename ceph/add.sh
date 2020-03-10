#!/bin/bash

controller="ceph-controller.maas"
# prov_nodes=( "ceph-mon.maas" ) 
prov_nodes=( "ceph-mds.maas" "ceph-mon.maas" "ceph-osd-2.maas" "ceph-osd-1.maas" ) 

controller_key=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$controller "cat ~/.ssh/id_rsa.pub")
echo "pub key: $controller_key"

for node in "$@"
do
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$node <<EOF
sudo useradd -d /home/ceph-admin -m ceph-admin
sudo usermod --password ceph-admin ceph-admin
sudo usermod -s /bin/bash ceph-admin
echo "ceph-admin ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ceph-admin
sudo apt-get install python-minimal -y
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
sudo apt-add-repository 'deb https://download.ceph.com/debian-nautilus/ xenial main'
sudo su - ceph-admin
mkdir /home/ceph-admin/.ssh/
touch /home/ceph-admin/.ssh/authorized_keys
echo $controller_key > /home/ceph-admin/.ssh/authorized_keys
EOF
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$controller <<EOF
echo "Host ${node/.maas/}" >> ~/.ssh/config
echo "   StrictHostKeyChecking=no" >> ~/.ssh/config
echo "   UserKnownHostsFile=/dev/null" >> ~/.ssh/config
echo "   Hostname ${node/.maas/}" >> ~/.ssh/config
echo "   User ceph-admin" >> ~/.ssh/config
EOF
done

