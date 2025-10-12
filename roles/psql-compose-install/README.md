# Description
need refactore  all role

# Configure replica
For configure replication need set env hosts replica
```
replica: True
pg_master_host: ip master host
pg_replica_slot_name: pgreplica_1 - unique name!
```

Deploy first server master host, init db and create user for replication
createuser -U postgres --replication -P replication  
Create secret in vault replication_user_pass.
Deploy second server slave, connect hosts and check logs docker-compose. If base backup completed, when repeat deploy role to slave.

# Tunning
host_vars for tuning
pg_max_connections: 100
pg_shared_buffers: '128MB'
pg_work_mem: '4MB'
pg_maintenance_work_mem: '64MB'
pg_effective_io_concurrency: 1
pg_max_worker_processes: 8
pg_max_parallel_workers_per_gather: 2
pg_max_parallel_maintenance_workers: 2
pg_max_parallel_workers: 8
pg_wal_buffers: '-1'
pg_checkpoint_completion_target: '0.9'
pg_max_wal_size: '1GB'
pg_min_wal_size: '80MB'
pg_random_page_cost: '4.0'
pg_effective_cache_size: '4GB'
pg_default_statistics_target: '100'

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
