#!/bin/bash 

# setup GPU passthrough for VM
ssh ubuntu@$1 <<EOF
if ! [[ \$(ls /sys/class/iommu/) ]]
then 
	echo "error: iommu not supported"
	exit
fi
EOF

pci_id=$(ssh ubuntu@$1 "lspci -nn | grep -i '3d controller' | grep -o '\[[a-z0-9]*\:[a-z0-9]*\]' | sort --unique" | sed "s/\[//g; s/\]//g")

if ! [[ $pci_id ]] 
then
	echo "error: no gpus found"
	exit
fi
comma_sep=$(echo $pci_id | sed s/\ /,/g)
echo "gpu-pci-bar:"$comma_sep

# edit /etc/initram-fs/modules, /etc/modules
ssh ubuntu@$1 <<EOF
sudo chmod 777 /etc/modules
echo -e "vfio\nvfio_iommu_type1" > /etc/modules
echo "vfio_pci ids=$comma_sep" >> /etc/modules
echo -e "vfio_virqfd\nkvm\nkvm_intel" >> /etc/modules
echo "-------EDITED /etc/modules--------"
cat /etc/modules
echo "----------------------------------"
sudo chmod 777 /etc/initramfs-tools/modules
echo -e "vfio\nvfio_iommu_type1\nvfio_pci ids=$comma_sep\nvhost-net" > /etc/initramfs-tools/modules
echo "-------EDITED /etc/initramfs-tools/modules--------"
cat /etc/initramfs-tools/modules
echo "----------------------------------"
sudo update-initramfs -u
sudo reboot
EOF

# wait until it is up
sleep 10
ssh -o ConnectTimeout=10 ubuntu@$1 "echo 'debug: machine up!'"
while test $? -gt 0
do
        sleep 10
        echo "Trying again..."
        ssh -o ConnectTimeout=10 ubuntu@$1 "echo 'debug: machine up!'"
done

# create gpu xml
template="
<hostdev mode='subsystem' type='pci' managed='yes'>
  <driver name='vfio'/>
  <source>
    <address domain='0x0000' bus='0xaaa' slot='0xbbb' function='0xccc'/>
  </source>
  <alias name='hostdev0'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
</hostdev>
"

pci_bars=$(ssh ubuntu@$1 "lspci -nn | grep -i '3d controller' | awk '{ print \$1 }'")
count=0
echo "pci-bar:"$pci_bars
for bar in $pci_bars
do 
	echo "index: $count"
	bus=$(echo $bar | sed s/:.*//g)
	slot=$(echo $bar | sed s/[0-9].*://g | sed s/[.][0-9]*//g)
	func=$(echo $bar | sed s/.*[.]//g)
	echo $bus,$slot,$func
	count=$(($count + 1))
	echo "$template" | sed s/aaa/$bus/ | sed s/bbb/$slot/ | sed s/ccc/$func/ | ssh ubuntu@$1 "cat > ~/gpu-$bus-$slot-$func.xml"
done
