# script check certificate expired day
# used for zabbix
#

SERVER_NAME=$1
PORT=$2
SERVER_IP=$3

if [ -z "$PORT" ]; then
  PORT=443
fi

if [ -z "$SERVER_IP" ]; then
  SERVER_IP=$SERVER_NAME
fi

#!/bin/bash
end_date=`echo | openssl s_client -connect $SERVER_IP:$PORT -servername $SERVER_NAME 2>/dev/null | openssl x509 -noout -enddate`
end=$(cut -d= -f2- <<<"$end_date")
end_date=`date -d "$end" '+%s'`
curr_date=`date '+%s'`
diff=$(( $end_date - $curr_date ))
let "days = $diff / 86400"
echo $days
