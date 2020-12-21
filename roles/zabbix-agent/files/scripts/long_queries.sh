#!/bin/bash

MINUTES=5

while [[ $# -gt 0 ]]
  do
  key="$1"

  case $key in
    -u|--user)
      USR="$2"
      CH_USER="--user $2"
      shift
      shift
    ;;
    -p|--password)
      PASS="$2"
      CH_PASS="--password $2"
      shift
      shift
    ;;
    -h|--host)
      CH_HOST="--host $2"
      shift
      shift
    ;;
    -m|--minutes)
      MINUTES=$2
      shift;
      shift;
    ;;
    *)
      echo "Unknown property: $1"
      exit
      shift
    ;;
  esac
  done

clickhouse-client $CH_HOST $CH_USER $CH_PASS -q "select * from system.processes where elapsed > $MINUTES * 60" | wc -l