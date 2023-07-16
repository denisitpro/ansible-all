#!/bin/bash
url_node=$3
test3="$(curl -s $1  -H "Content-Type: application/json" -X POST --data '{ "jsonrpc":"2.0", "method":"chain_getBlock", "params":[],"id":1}'  | jq .result.block.header.number | sed 's/[^0-9.a-z]//g')"
echo $(($test3))
