# MaaS Admin Tools
Tools for Maas admins.

## Prequisites

Please make sure both jq is installed:

sudo apt-get install jq -y

MaaS commandline utility may fail with 'DependencyWarning', please install requests:

sudo pip3 install requests

## Deployment Instructions

Acquire host as virsh pod. This script will perform updates, create network bridge, pool unpartitioned disks as virsh storage pool, and create a pod out of the machine.
```
./acquire_virsh.sh <ip_address>
./acquire_virsh.sh 172.27.180.29
```

Find GPUs on host and create virsh XML files. This script will find all the gpu nodes, write passthrough settings (VFIO), and generate virsh XML files for the PCI devices at the home directory. 
```
./gpu-passthrough.sh <ip_address>
./gpu-passthrough.sh 172.27.180.29
```

Compose pods based on csv file. This script will find the compute pod specified and compose pods based on the csv file. The csv file has the following fields: hostname,vcpu(# of cores),memory,storage,tags,attachments(room for 1 extra storage attachments).
```
./compose_pods.sh <pod name> <csv filename> 
./compose_pods.sh asus-esc8000gpu-pod mcity_nodes.csv
```
Following this, you probably have to attach the XML for the gpu to the correct nodes using Virsh. The commands are relative simple:
```
ssh ubuntu@<ip endpoint>
virsh shutdown <vm>
# gpu passthrough seems to only work with some cpu models
virt-xml <vm> --edit --cpu Broadwell-IBRS,mode=custom,match=exact
virt-xml <vm> --edit --vcpu sockets=1,cores=8,threads=1
virsh virsh attach-device <vm> --file <xml filename>.xml --config
```
## TODO
# Add automation for GPU passthrough in pod compose
# Add options for multiple disk attachment in pod compose
# Tune CPUs (unfortunately, numad doesn't seem to work on Ubuntu) this should look like:
```
virt-xml kworker-1 --edit --numatune mode=strict
virt-xml kworker-1 --edit --numatune mode=preferred,nodeset=0
virt-xml kworker-1 --edit --vcpu placement=static,cpuset=0-17
```
