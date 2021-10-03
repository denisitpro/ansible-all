# zabbix install role
Limits

* test only ubuntu 20.04
* database postgresql
* web server - nginx

# example config
```LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_server.pid
SocketDir=/run/zabbix
DBHost=db.example.com
DBName=zabbixdb
DBUser=zabbix
DBPassword=password
StartPollers=10
StartPollersUnreachable=100
StartPingers=20
StartDiscoverers=5
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
ListenIP=127.0.0.1, 10.1.2.3
HousekeepingFrequency=4
CacheSize=2G
Timeout=30
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1```