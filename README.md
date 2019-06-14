# MaaS Admin Tools
Tools for Maas admins.

Add tags to host name
```
./tag.sh <hostname (partial matches work)> <tagname> 
```

Find system id based on host name
```
./systemid.sh <hostname (optional)>
```

Acquire host as virsh pod
```
./acquire_virsh.sh <ip_address>
```

Find GPUs on host and create virsh files
```
./gpu-passthrough.sh <ip_address>
```
