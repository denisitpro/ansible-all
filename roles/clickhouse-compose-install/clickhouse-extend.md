# ClickHouse Cluster Extend

## Добавление реплик к шарду в кластере ClickHouse

Лучше обновлять конфигурацию **поэтапно**: сначала НОВЫЕ серверы, а затем старые.

### Обновление конфигурации

Комментируем существующие ноды кластера и добавляем новые:

```ini
[click_devel]
# click-01.example.com
# click-02.example.com
# click-03.example.com
click-04.example.com
click-05.example.com
```

Ваш массив в inventory должен выглядеть так:

```yaml
click_remote_servers:
  - name: "cluster1"
    shards:
      - replicas:
          - host: "click-01.example.com"
          - host: "click-02.example.com"
          - host: "click-03.example.com"
          - host: "click-04.example.com"
          - host: "click-05.example.com"
```

Запускаем Ansible с тегом `click`, чтобы настроить все роли:

```sh
ansible-playbook -i env/devel click-devel.yml -t click
```

### Обновляем конфигурацию на существующих серверах (click-01, 02, 03)

Комментируем новые в файле хостов:

```ini
[click_devel]
click-01.example.com
click-02.example.com
click-03.example.com
# click-04.example.com
# click-05.example.com
```

Запускаем Ansible:

```sh
ansible-playbook -i env/devel click-devel.yml -t click-remote-server
```

## Включение репликации

Для теста я ранее ДО расширения кластера создал таблицу такой командой:

```sql
CREATE TABLE t ON CLUSTER cluster1 (
    a UInt64
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/default/t/{shard}', '{replica}')
ORDER BY a;
```

Проверяем путь до таблицы на старой реплике:

```sql
SHOW CREATE TABLE t;
```

На основе неё исправляем запрос и выполняем его на новых нодах:

```sql
CREATE TABLE default.t (
    a UInt64
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/default/t/{shard}', '{replica}')
ORDER BY a;
```

### Если возникает ошибка существования таблицы:

На **НОВОМ** сервере в примере он 04:

```sh
rm -rf /opt/click/data/data/default/t/
rm -rf /opt/click/data/metadata/default/t.sql
rm -rf /opt/click/data/metadata_dropped/default/t.sql
```

На сервере ClickHouse Keeper правим путь:

```sh
rmr "/clickhouse/tables/default/t/01/replicas/click-04"
```

Затем снова создаем таблицу.

### Если репликация не включается

На **новом сервере**:

```sql
SYSTEM SYNC REPLICA t;
```

Если не помогает:

```sql
SYSTEM STOP REPLICATION QUEUES t;
SYSTEM RESTORE REPLICA t;
SYSTEM START REPLICATION QUEUES t;
```

Проверяем, что кластер работает:

```sql
SELECT * FROM system.clusters;
```

### Проверка состояния

Проверяем лидерство:

```sql
SELECT is_leader FROM system.replicas;
```

Ожидаемый результат (1 - всё в порядке):

```
┌─is_leader─┐
│         1 │
└───────────┘
```

Финальная проверка реплик:

```sql
SELECT * FROM system.replicas; \G
```

## Полезные команды

### Работа с ClickHouse в контейнере

```sh
docker exec -it click clickhouse-client
```

### Список таблиц

```sql
SHOW TABLES;
```

### Проверка узлов кластера

```sql
SELECT * FROM system.clusters;
```

### Проверка реплик

```sql
SELECT * FROM system.replicas; \\G
```

### Принудительная репликации

```sql
SYSTEM SYNC REPLICA t;
```

### Очередь репликации

```sql
SELECT database, table, replica_path, queue_size FROM system.replicas WHERE table = 't';
```

