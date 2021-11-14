#!/bin/bash
url_node=$1
test2="$(curl -s $1 -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":56}'  | jq .result | sed 's/[^0-9.a-z]//g')"
echo $(($test2))
