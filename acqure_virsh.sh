#!/bin/bash
# creates a virsh pod in maas
# usage: ./acquire_virsh.sh <ip address>
# this assumes you are using maas admin profile

# check if machine and command is okay
status=$(maas admin machines read | jq --arg ip "$1" '.[] | select(.ip_addresses==[$ip]) | .status_name')
echo "$status"
if ! [ "$status" = '"Deployed"' ] 
then
	echo "error: node not ready for script"
	exit
fi 

if [ $# -eq 0 ] 
then 
	echo "error: ./acquire_virsh.sh <ip address>"
	echo "error: must select a target node to acquire as pod"
	exit
fi

grep ^libvirtd /etc/group >/dev/null 2>&1
if ! [ $? -eq 0 ] 
then
	echo "debug: adding to libvirtd group"
	sudo adduser maas libvirtd
fi

ssh-keygen -F $1 2>&1 >/dev/null
if ! [ $? -eq 0 ]
then
	ssh-keyscan -H $1 >> ~/.ssh/known_hosts
fi

# update software 
ssh ubuntu@$1 <<EOF
sudo add-apt-repository ppa:maas/stable -y
sudo apt update
sudo apt upgrade -y
sudo apt install bridge-utils qemu-kvm libvirt-bin -y
cd /etc/network/interfaces.d/
sudo chmod 777 50-cloud-init.cfg
if ! [ -f "50-cloud-init.backup" ]; then sudo cp 50-cloud-init.cfg 50-cloud-init.backup; fi
EOF

# add maas public key to the target node
maas_key=$(cat /var/lib/maas/.ssh/id_rsa.pub)
ssh ubuntu@$1 "cat ~/.ssh/authorized_keys" | grep "$maas_key" >/dev/null 2>&1
if ! [ $? -eq 0 ] 
then 
	echo "debug: adding maas ssh key to node"
	cat /var/lib/maas/.ssh/id_rsa.pub | ssh ubuntu@$1 "cat >> ~/.ssh/authorized_keys"
fi 

# edit cloud init file
init_script=$(ssh ubuntu@$1 "cat /etc/network/interfaces.d/50-cloud-init.backup")
intf=''
br=''
for x in $(echo "$init_script" | grep -i static)
do
	if [[ $x == eth* ]]
	then 
		intf=$(echo "$x")
		br=$(echo "$x" | sed s/eth/br/)
	fi
done
auto="auto $br"
iface="iface $br inet static"
address="$(echo "$init_script" | grep -i address)"
dns="$(echo "$init_script" | grep -i -m1 dns-nameservers)"
gateway="$(echo "$init_script" | grep -i gateway)"
br_l1="    bridge_ports $intf"
br_l2="    bridge_stp off"
br_l3="    bridge_fd 0"
br_l4="    bridge_maxwait 0"

init_script=$(echo "$init_script" | sed s/static/manual/ | sed /address/d | sed /gateway/d | sed "0,/$dns/! s/$dns//")
new_script=$(echo "$init_script

$auto
$iface
$address
$dns
$gateway
$br_l1
$br_l2
$br_l3
$br_l4")
echo "************************************* APPLYING CLOUD-INIT FILE *************************************"
echo "$new_script"
echo "****************************************************************************************************"
echo -e "$new_script" | ssh ubuntu@$1 "sudo cat > /etc/network/interfaces.d/50-cloud-init.cfg"
ssh ubuntu@$1 "sudo reboot"

# wait until it is up
sleep 10
ssh -o ConnectTimeout=10 ubuntu@$1 "echo 'debug: bridge up!'"
while test $? -gt 0
do
	sleep 10
	echo "Trying again..."
	ssh -o ConnectTimeout=10 ubuntu@$1 "echo 'debug: bridge up!'"
done

# copy network xml
echo '<network><name>default</name><forward mode="bridge" /><bridge name="'"$br"'" /></network>' | ssh ubuntu@$1 "cat > ~/net-default.xml"

# setup network with xml, pool storage, install vnc
ssh ubuntu@$1 <<EOF
sudo virsh net-destroy default
sudo virsh net-undefine default
sudo virsh net-define net-default.xml
sudo virsh net-autostart default
sudo virsh net-start default
x=\$(lsblk -o NAME,FSTYPE -dsn | awk '\$2 == "" {print \$1}' | sed s/^/\\\/dev\\\//)
echo "-----unpartitioned blocks-----"
echo "\$x"
echo "------------------------------"
sudo pvcreate \$x
sudo vgcreate default \$x
# sudo virsh pool-define-as default logical --target /dev/default
sudo lvcreate -l 100%FREE -n data default
sudo mkfs.ext4 /dev/default/data
sudo mkdir /mnt/vm
sudo mount /dev/default/data /mnt/vm
sudo virsh pool-define-as default dir - - - - "/mnt/vm"
sudo virsh pool-start default
sudo virsh pool-autostart default
# sudo virsh pool-define-as default2 dir - - - - "/var/lib/libvirt/images"
# sudo virsh pool-autostart default2
# sudo virsh pool-start default2
sudo apt-get install virt-manager -y
sudo apt-get install ubuntu-desktop gnome-panel gnome-settings-daemon metacity -y
sudo apt-get install --no-install-recommends ubuntu-desktop gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal -y
sudo apt-get install vnc4server -y
sudo mkdir ~/.vnc/
sudo chmod 777 ~/.vnc/
sudo echo "gnome-panel &" > ~/.vnc/xstartup
sudo echo "gnome-settings-daemon &" >> ~/.vnc/xstartup
sudo echo "metacity &" >> ~/.vnc/xstartup
sudo echo "nautilus &" >> ~/.vnc/xstartup
sudo printf "ims1234\nims1234\n\n" | vncpasswd
sudo chown -R ubuntu:ubuntu /home/ubuntu/.vnc
sudo chmod 600 /home/ubuntu/.vnc/passwd
vncserver
EOF

# create a pod 
pod_name=$(maas admin machines read | jq -r --arg ip "$1" '.[] | select(.ip_addresses==[$ip]) | .hostname')-pod
maas_status=$(maas admin pods create type=virsh power_address=qemu+ssh://ubuntu@$1/system name=$pod_name)
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Success. Pod created as $pod_name"
