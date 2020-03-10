#!/bin/bash

controller="ceph-controller.maas"
series="bionic"
prov_nodes=( "ceph-mds.maas" "ceph-mon.maas" "ceph-osd-2.maas" "ceph-osd-1.maas" "ceph-osd-3.maas") 


ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$controller <<EOF
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
sudo apt-add-repository 'deb https://download.ceph.com/debian-nautilus/ $series main'
sudo apt update 
sudo apt install ceph-deploy -y
if [ ! -f "~/.ssh/id_rsa" ]
then
cd ~/.ssh/
ssh-keygen -f id_rsa -t rsa -N ''
fi 
EOF

controller_key=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$controller "cat ~/.ssh/id_rsa.pub")
echo "pub key: $controller_key"

for node in "${prov_nodes[@]}"
do
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$node <<EOF
sudo useradd -d /home/ceph-admin -m ceph-admin
sudo usermod --password ceph-admin ceph-admin
sudo usermod -s /bin/bash ceph-admin
echo "ceph-admin ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ceph-admin
sudo apt-get install python-minimal -y
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
sudo apt-add-repository 'deb https://download.ceph.com/debian-nautilus/ $series main'
sudo su - ceph-admin
mkdir /home/ceph-admin/.ssh/
touch /home/ceph-admin/.ssh/authorized_keys
echo $controller_key > /home/ceph-admin/.ssh/authorized_keys
EOF
echo "Host ${node/.maas/}" >> config
echo "   StrictHostKeyChecking=no" >> config
echo "   UserKnownHostsFile=/dev/null" >> config
echo "   Hostname ${node/.maas/}" >> config
echo "   User ceph-admin" >> config
done

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ./config ubuntu@$controller:~/.ssh/config

if [ -f "./config" ]
then
rm config
fi
