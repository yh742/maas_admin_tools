#!/bin/bash
# compose pods based on csv file
# usage: ./compose_pods.sh <pod name> <node csv file>
# this assumes you are using maas admin profile

if ! [ $# -eq 2 ] 
then
	echo "need to specify both an ip and csv file"
	exit
fi 

pod_id=$(maas admin pods read | jq --arg hostname "$1" '.[] | select (.name==$hostname) | .id')
if [ -z $pod_id ] 
then
	echo "error: couldn't find the pod you specified"
	exit
fi
echo "pod id: "$pod_id

if ! [[ -f $2 ]]
then
	echo "error: the file you specified doesn't exist"
	exit
fi

first_line=true
for line in $(cat $2)
do
	if $first_line; then first_line=false; continue; fi
	name=$(echo "$line" | awk -F "," '{print $1}')
	vcpu=$(echo "$line" | awk -F "," '{print $2}')
	memory=$(echo "$line" | awk -F "," '{print $3}')
	storage=$(echo "$line" | awk -F "," '{print $4}')
	tag=$(echo "$line" | awk -F "," '{print $5}')
	attachment=$(echo "$line" | awk -F "," '{print $6}')
	echo "----------------vm details-------------------"
	echo $name,$vcpu,$memory,$storage,$tag,$attachment
	echo "---------------------------------------------"
	output=$(maas admin pod compose $pod_id hostname=$name cores=$vcpu memory=$memory storage=$storage)
	echo $output
	system_id=$(echo "$output" | jq -r .system_id)
	echo "system id: "$system_id
	maas admin tags create name=$tag
	maas admin tag update-nodes $tag add=$system_id	
done

