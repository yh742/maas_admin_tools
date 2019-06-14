#!/bin/bash

if [ $# -eq 0 ]
then
	echo "This should be <node name> <tag name>"
	exit 0
fi

sys_id=$(maas admin machines read | jq -j '.[] | .hostname, " ", .system_id, "\n"' | grep -i $1 | awk '{print $2}')

maas admin tags create name=$2
for x in $sys_id
do
	echo $x
	maas admin tag update-nodes $2 add=$x
done


