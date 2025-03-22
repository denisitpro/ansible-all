# Удаление ClickHouse Keeper из эксплуатации

## Обновление конфигурации ClickHouse-серверов

Сначала обновляем конфигурацию ClickHouse-серверов, чтобы они смотрели только на те ноды Keeper, которые остаются в эксплуатации.

Так как ClickHouse использует `click_zookeeper_servers: "keeper_devel"`, просто комментируем хосты, которые планируем выводить:

```ini
[keeper_devel]
keeper-01.example.com
keeper-02.example.com
keeper-03.example.com
# keeper-04.example.com
# keeper-05.example.com
```

Запускаем плейбук для применения конфигурации:

```sh
ansible-playbook -i env/devel click-devel.yml -t click-zoo-servers
```

Перезапуск ClickHouse не потребуется — достаточно выполнить reload. Он выполнится автоматически

### Проверка конфигурации на любом сервере ClickHouse

```sh
cat /opt/click/config/config.d/zookeeper.xml
```

Ожидаемый результат:

```xml
<clickhouse>
    <zookeeper>
        <node>
            <host>keeper-01.example.com</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper-02.example.com</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper-03.example.com</host>
            <port>9181</port>
        </node>
    </zookeeper>
</clickhouse>
```

## Обновление конфигурации ClickHouse Keeper

На нодах, которые остаются в кластере, обновляем конфигурацию, удаляя `keeper-04` и `keeper-05` из списка.

Файл хостов:

```ini
[keeper_devel]
keeper-01.example.com
keeper-02.example.com
keeper-03.example.com
# keeper-04.example.com
# keeper-05.example.com
```

Запускаем плейбук:

```sh
ansible-playbook -i env/devel keeper-devel.yml -t keeper-config
```

## Остановка и удаление серверов `keeper-04` и `keeper-05`

```sh
 docker compose -f /opt/docker/keeper/docker-compose.yml down
```
Настоятельно рекомендуется вывести сервера из эксплуатации 

## Удаление узлов из ClickHouse Keeper

Находим лидера Keeper-кластера:

```sh
curl http://127.0.0.1:9182/ready | jq
```

Подключаемся к Keeper:

```sh
docker exec -it keeper clickhouse-keeper-client --host 127.0.0.1 --port 9181
```

Просматриваем текущую конфигурацию:

```sh
get "/keeper/config"
```

Ожидаемый результат перед удалением узлов:

```
server.1=keeper-01.example.com:9234;participant;1
server.2=keeper-02.example.com:9234;participant;1
server.3=keeper-03.example.com:9234;participant;1
server.4=keeper-04.example.com:9234;participant;1
server.5=keeper-05.example.com:9234;participant;1
```

Удаляем серверы `keeper-04` и `keeper-05` из кластера:

```sh
reconfig remove "4,5"
```

После удаления ожидаем такой результат:

```
server.1=keeper-01.example.com:9234;participant;1
server.2=keeper-02.example.com:9234;participant;1
server.3=keeper-03.example.com:9234;participant;1
```

Дополнительно можно проверить конфигурацию через команду:

```sh
get "/keeper/config"
```

## Полезные команды

### Подключение к ClickHouse Keeper

```sh
docker exec -it keeper clickhouse-keeper-client --host 127.0.0.1 --port 9181
```

### Проверка активных узлов в кластере Keeper

```sh
get "/keeper/config"
```

### Документация

[ClickHouse Keeper (clickhouse-keeper)](https://clickhouse.com/docs/guides/sre/keeper/clickhouse-keeper#reconfiguration)

