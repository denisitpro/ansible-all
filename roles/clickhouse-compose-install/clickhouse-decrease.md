# Удаление реплик из кластера ClickHouse

## Правильный подход

Удаляем сервер из репликации командой:

```sql
DROP TABLE t SYNC;
```

Где `t` – имя таблицы, для которой сервер является репликой.

В данном примере будем выводить `click-04` и `click-05`.

### Пример текущего файла хостов

```ini
[click_devel]
click-01.example.com
click-02.example.com
click-03.example.com
click-04.example.com
click-05.example.com
```

### Обновляем массив серверов для репликации

```yaml
click_remote_servers:
  - name: "cluster1"
    shards:
      - replicas:
          - host: "click-01.example.com"
          - host: "click-02.example.com"
          - host: "click-03.example.com"
          # - host: "click-04.example.com"
          # - host: "click-05.example.com"
```

### Останавливаем ClickHouse на серверах, которые выводим (04 и 05)

```sh
docker compose -f  /opt/docker/click/docker-compose.yml down
```

## Неправильный подход

Удаление таблицы без `SYNC`, тогда нужно подождать. Далее всё равно необходимо:
- Обновить конфиг для `remote_servers`
- Остановить ClickHouse на удаляемых серверах

# В случае проблем
## Очистка данных в ClickHouse Keeper

Переходим на любой ClickHouse Keeper из кластера:

```sh
docker exec -it keeper clickhouse-keeper-client --host 127.0.0.1 --port 9181
```

Проверяем, что в базе `default`, таблице `t`, шарде `0` остались только нужные серверы:

```sh
ls '/clickhouse/tables/default/t/01/replicas/'
```

Если вывод содержит лишние сервера, например:

```
click-04 click-05 click-01 click-02 click-03
```

Удаляем их:

```sh
rmr "/clickhouse/tables/default/t/01/replicas/click-04"
rmr "/clickhouse/tables/default/t/01/replicas/click-05"
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
SELECT * FROM system.replicas; \G
```

### Принудительная репликации

```sql
SYSTEM SYNC REPLICA t;
```

### Очередь репликации

```sql
SELECT database, table, replica_path, queue_size FROM system.replicas WHERE table = 't';
```

