# Расширение кластера ClickHouse Keeper

## Сценарий

Расширение текущего кластера ClickHouse Keeper до 5 нод.

## Допущения и ограничения

- У вас уже есть 3 рабочих ноды кластера.
- Ноды кластера имеют корректно настроенные `hostname`, например, `keeper-01`, а также корректно настроенный DNS-суффикс `example.com`.
- С серверов кластера корректно резолвятся адреса вида `keeper-02.example.com`.
- Сервера уже корректно настроены, осталось только развернуть Keeper.
- В конфигурации задан параметр:
  ```xml
  <enable_reconfiguration>true</enable_reconfiguration>
  ```

### Пример группы хостов (04 и 05 — новые, которые добавляем)

```ini
[keeper_group]
keeper-01.example.com
keeper-02.example.com
keeper-03.example.com
keeper-04.example.com
keeper-05.example.com
```

## Последовательность шагов

### Порядок действий:

1. **Обновить конфигурацию на существующих нодах**, добавив новые ноды в `server.xml`.
2. **Перезапустить текущие ноды** (по одной), чтобы они подхватили обновлённую конфигурацию.
3. **Запустить новые ноды с той же конфигурацией**.
4. **Проверить консистентность кластера**, убедиться, что новый состав узлов работает корректно.

### Основная проблема

Если запустить роль на всех серверах одновременно, это может привести к сбоям. Нам нужно сначала обновить существующие ноды, а затем добавить новые, то есть последовательно.

Так как в роли вычисляется ID по группе, нам это не подходит, поэтому мы явно зададим массив серверов.

## Выполнение шагов

1. **Смотрим текущие ноды Keeper и их ID**:

   ```bash
   cat /opt/keeper/config/keeper_config.xml
   ```

2. **Формируем массив с текущими и новыми серверами**:

   ```yaml
   keeper_raft_servers:
   - id: 1
     hostname: keeper-01.example.com
   - id: 2
     hostname: keeper-02.example.com
   - id: 3
     hostname: keeper-03.example.com
   - id: 4
     hostname: keeper-04.example.com
   - id: 5
     hostname: keeper-05.example.com
   ```

3. **Включаем `serial: 1` в Ansible-плейбуке**, чтобы текущие серверы обновлялись по очереди:

   ```yaml
   ---
   - hosts: keeper_group
     become: true
     # serial: 1
     roles:
       - clickhouse-keeper-install
   ```

4. **Проверяем файл `hosts`** – в группе должны быть только текущие ноды:

   ```ini
   [keeper_group]
   keeper-01.example.com
   keeper-02.example.com
   keeper-03.example.com
   # keeper-04.example.com
   # keeper-05.example.com
   ```

5. **Запускаем обновление конфигурации**:

   ```bash
   ansible-playbook -i env/devel keeper-cluster.yml -t keeper-config
   ```

6. **Убеждаемся, что кластер работает нормально**.

7. **Закомментируем `serial: 1` в плейбуке** и обновляем файл `hosts`, заменяя активные ноды на новые:

   ```ini
   [keeper_group]
   # keeper-01.example.com
   # keeper-02.example.com
   # keeper-03.example.com
   keeper-04.example.com
   keeper-05.example.com
   ```

8. **Запускаем Ansible-плейбук с тегом `keeper`**:

   ```bash
   ansible-playbook -i env/devel keeper-cluster.yml -t keeper
   ```

9. **Возвращаем `hosts` в нормальное состояние**:

   ```ini
   [keeper_group]
   keeper-01.example.com
   keeper-02.example.com
   keeper-03.example.com
   keeper-04.example.com
   keeper-05.example.com
   ```

10. **Добавляем новые ноды в кластер**:

    - Делаем это на ноде - лидеры кластера
    - Проверяем, что нода — лидер:

      ```bash
      echo srvr | nc 127.0.0.1 9181
      ```

    - Добавляем новую ноду:

      ```bash
      reconfig add "server.4=keeper-04.example.com:9234"
      get "/keeper/config"
      ```

    - Читаем логи на той ноде которую добавили keeper-04:

      ```bash
      tail -f /opt/keeper/logs/clickhouse-keeper.log
      ```
11. **Проверяем статус новых серверов в кластере**:

    ```bash
    curl http://127.0.0.1:9182/ready | jq
    ```

    Ожидаемый ответ:

    ```json
    {
      "details": {
        "hasLeader": true,
        "role": "follower"
      },
      "status": "ok"
    }
    ```


12. **Обновляем конфиг ClickHouse**:

    ```bash
    ansible-playbook -i env/devel keeper-cluster.yml -t click-config
    ```

## Полезные команды

- **Подключение к Keeper**:

  ```bash
  docker exec -it keeper clickhouse-keeper-client --host 127.0.0.1 --port 9181
  ```

- **Проверка режима `srvr`**:

  ```bash
  echo srvr | nc 127.0.0.1 9181
  ```

- **Проверка конфига Keeper**:

  ```bash
  get "/keeper/config"
  ```

- **Проверка статуса ноды**:

  ```bash
  echo stat | nc 127.0.0.1 9181
  ```
