# Example usage Alpine PSQL 18 + Users + DB + Replication
```
psql_main_version: 18
psql_version: 18.1-alpine3.23
psql_node_data_path: "{{ psql_base_path }}/db/{{ psql_main_version }}"
psql_docker_data_path: "/var/lib/postgresql/{{ psql_main_version }}/docker"
psql_docker_conf_dir: "/etc"

psql_docker_user_uid: 70
psql_docker_user_gid: 70

psql_bind_addr: "*"
psql_default_db_name:
psql_default_db_password: "{{ vault_dict_users_secret_g2.psql_db_pass.postgres_default_pass }}"

psql_tls: true

# For 32 CPU 128 RAM
psql_shared_buffers: "32GB"
psql_effective_cache_size: "96GB"
psql_maintenance_work_mem: "2GB"
psql_checkpoint_completion_target: "0.9"
psql_wal_buffers: "16MB"
psql_default_statistics_target: "100"
psql_random_page_cost: "1.1"
psql_effective_io_concurrency: "300"
psql_work_mem: "8134kB"
psql_min_wal_size: "2GB"
psql_max_wal_size: "8GB"
psql_max_worker_processes: "32"
psql_max_parallel_workers_per_gather: "4"
psql_max_parallel_workers: "32"
psql_max_parallel_maintenance_workers: "4"
psql_max_connections: "2048"

# Replication settings
psql_replication_hosts: "{{ (resolved_psql_hosts_ipv4 | default([]) | map('regex_replace', '$', '/32') | list) + (resolved_psql_hosts_ipv6 | default([]) | map('regex_replace', '$', '/128') | list) }}"

psql_replication: true
psql_create_replica: true
psql_max_wal_senders: "{{ (psql_replica_nodes | length) + 5 }}"
psql_master_node: "{{ groups['psql_hosts'] | first }}"
psql_replica_nodes: "{{ groups['psql_hosts'] | difference([psql_master_node]) }}"

# HBA settings
psql_backend_hosts: "{{ (resolved_backend_workers_ipv4 | default([]) | map('regex_replace', '$', '/32') | list) + (resolved_backend_workers_ipv6 | default([]) | map('regex_replace', '$', '/128') | list) }}"

psql_hba_acl_allow_all: false

psql_hba_acl:
  - user: "devops"
    database: "all"
    address: ["{{ vpn_01_ipv4 }}/32", "{{ vpn_01_ipv6 }}/128" ]
  - user: "backend"
    database: "backend"
    address: "{{ psql_backend_hosts }}"

psql_users:
  - name: "replication"
    password: "{{ psql_pgpassword }}"
    is_replication: true
  - name: "migrator"
    password: "{{ vault_dict_users_secret_g2.psql_db_pass.migrator_pass }}"
    member_of:
      - "pg_read_all_data"
      - "pg_write_all_data"
  - name: "backend"
    password: "{{ vault_dict_users_secret_g2.psql_db_pass.backend_pass }}"
    member_of:
      - "migrator"

psql_db:
  - name: "backend"
    owner: "migrator"
```


# Configure replica
For configure replication need set env hosts replica
```
replica: True
pg_master_host: ip master host
psql_replica_slot_name: pgreplica_1 - unique name!
```

Deploy first server master host, init db and create user for replication
createuser -U postgres --replication -P replication  
Create secret in vault replication_user_pass.
Deploy second server slave, connect hosts and check logs docker-compose. If base backup completed, when repeat deploy role to slave.

# Tunning
host_vars for tuning
pg_max_connections: 100
psql_shared_buffers: '128MB'
psql_work_mem: '4MB'
psql_maintenance_work_mem: '64MB'
psql_effective_io_concurrency: 1
psql_max_worker_processes: 8
psql_max_parallel_workers_per_gather: 2
psql_max_parallel_maintenance_workers: 2
psql_max_parallel_workers: 8
psql_wal_buffers: '-1'
psql_checkpoint_completion_target: '0.9'
psql_max_wal_size: '1GB'
psql_min_wal_size: '80MB'
psql_random_page_cost: '4.0'
psql_effective_cache_size: '4GB'
psql_default_statistics_target: '100'

# TLS Check 
```
psql -U postgres -h bind_ip -c 'SELECT datname,usename, ssl, client_addr;'
  FROM pg_stat_ssl
  JOIN pg_stat_activity
    ON pg_stat_ssl.pid = pg_stat_activity.pid;
 datname  | usename  | ssl | client_addr
----------+----------+-----+-------------
 postgres | postgres | t   | 127.0.0.1
(1 row)
```

```
psql "user=postgres host=bind_ip sslmode=disable" -c 'SELECT datname,usename, ssl, client_addr;'
  FROM pg_stat_ssl
  JOIN pg_stat_activity
    ON pg_stat_ssl.pid = pg_stat_activity.pid;
 datname  | usename  | ssl | client_addr
----------+----------+-----+-------------
 postgres | postgres | f   | 127.0.0.1
```
