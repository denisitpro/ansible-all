#!/bin/bash
url_node=$1
test="$(curl -s -H "x-api-key: zabbix" -X POST $1 --header "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq .result | sed 's/[^0-9.a-z]//g')"
echo $(($test))