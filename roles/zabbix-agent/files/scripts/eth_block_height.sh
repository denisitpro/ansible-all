#!/bin/bash
url_node=$1
test="$(curl -s --header "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":67}' $1 | jq .result | sed 's/[^0-9.a-z]//g')"
echo $(($test))
