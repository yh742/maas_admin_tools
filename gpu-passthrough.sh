#!/bin/bash 

# setup GPU passthrough for VM
ssh ubuntu@$1 <<EOF
if ! [[ \$(ls /sys/class/iommu/) ]]
then 
	echo "error: iommu not supported"
	exit
fi
lspci -nn | grep -i "3d controller"
EOF


