#!/bin/bash
url_node=$1
test1="$(curl -s $1 -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}'  | jq .result | sed 's/[^0-9.a-z]//g')"
echo $(($test1))
