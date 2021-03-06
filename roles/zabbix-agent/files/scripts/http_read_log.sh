#!/bin/bash

if [[ $# -eq 3 ]]
then
	URL=$1
	PARAM_NAME=$2
	PARAM_MATCH=$3
	ERR_FILENAME=/tmp/$(echo "${URL}_${PARAM_NAME}_${PARAM_MATCH}.log" | sed -e 's/[^A-Za-z0-9._-]/_/g')
	OUT=$(cat $ERR_FILENAME 2>/dev/null)
	echo $OUT
elif [[ $# -eq 5 ]]
then
	URL=$1
	HOST_PORT=$2
	IPADDR=$3
	PARAM_NAME=$4
	PARAM_MATCH=$5
	ERR_FILENAME=/tmp/$(echo "${URL}_${IPADDR}_${PARAM_NAME}_${PARAM_MATCH}.log" | sed -e 's/[^A-Za-z0-9._-]/_/g')
	OUT=$(cat $ERR_FILENAME 2>/dev/null)
	echo $OUT
else
	echo 0
fi
