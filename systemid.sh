#!/bin/bash

if [ $# -eq 0 ]
then
	maas admin machines read | jq -j '.[] | .hostname, " ", .system_id, "\n"'
	exit 0
fi

maas admin machines read | jq -j '.[] | .hostname, " ", .system_id, "\n"' | grep -i $1 | awk '{print $2}'
