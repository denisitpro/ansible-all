#!/bin/bash

pinghost=$1

ping_results=$(ping $pinghost -c 1 -W 2| awk -F= '{print $4}' | tr -d ' ms' | sed '/^$/d' 2>&1);

if [ -z «$ping_results» ];then
  ping_results="9999"
  echo $ping_results
else
  echo $ping_results
fi