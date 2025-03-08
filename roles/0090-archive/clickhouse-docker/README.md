# Role description
* Role install and configure clickhouse server
* user create only use IaC - ansible if need create user SQL query need set vars clickhouse_access_management = 1
* Role support self sign certificate for SSL port http, need create dhparam - read file files/README.md 
* Create user not required restart

# Example config 

```commandline
clickhouse:
  users:
    - { name: default, ip: { "::1/128" } }
    - { name: user_exporter, ip: { "::1/128"}, profile: "readonly" }
    - { name: admin1, ip: { "::1/128", "127.0.0.1", "10.10.1.0/24" } }
    - { name: app_user, ip: { "10.20.2.0/24", "10.20.3.0/24" }, allow_databases: ["db1", "db2"] }
```

need set user password, example set use role vault
```commandline

vault:
  secret:
   
    - {kv: "c1-infra", path: "clickhouse/example1",  key_name: "default"}
    - {kv: "c1-infra", path: "clickhouse/example1",  key_name: "user_exporter"}
    - {kv: "c1-infra", path: "clickhouse/example1",  key_name: "admin1,"}
    - {kv: "c1-infra", path: "clickhouse/example1",  key_name: "app_user"}
```