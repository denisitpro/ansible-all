# Backup и восстановление кластера Vault

# Термины и определения (глоссарий)
старый кластер — кластер Vault, с которого производится экспорт резервной копии (snapshot)
новый кластер — кластер Vault, в который выполняется восстановление из резервной копии

# Подготовка окружения для работы с Vault
В типовом сценарии с настроенным mTLS, чтобы избежать ошибок, связанных с недоверенным сертификатом, используйте следующие команды:
``` bash
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/opt/vault/config/ssl/ca.pem
export VAULT_CLIENT_CERT=/opt/vault/config/ssl/fullchain.pem
export VAULT_CLIENT_KEY=/opt/vault/config/ssl/privkey.pem
```

Если расположение сертификатов неизвестно, можно использовать упрощённый вариант без проверки сертификатов:
``` bash
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
```

# Создание резервной копии
Необходимо задать токен и определить текущий лидирующий узел (master), так как бэкап выполняется именно с него. В примерах используется подключение к localhost внутри контейнера, однако это можно делать и удалённо.
``` bash
docker exec -it vault sh
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN=our_root_token
vault operator raft list-peers 
```

После этого на лидере выполняем команду создания снимка. Если Vault был установлен не этой ролью, необходимо откорректировать путь под вашу конфигурацию.
``` bash
docker exec -it vault sh
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN=our_root_token
vault operator raft snapshot save /opt/vault/backup/vault-$(date +%F_%H-%M-%S).snap 
```

# Restore
Предполагается, что кластер установлен с использованием этой роли. В противном случае адаптируйте логику под свою установку.

Для восстановления, нам нужно - все ноды кластера пустые, без старых данных, при необходимости можно через Ansible удалить старую установку используя тег vault-clean  
Так же нам на первом этапе, нужен только один инстанс кластера, который и будет выполнить bootstrap, после чего раскатать остальные узлы  
Пример провиженга одного сервера  
```bash
ansible-playbook -i env/cluster inventory.yml -t vault-install --skip-tag vault --limit vault-01.example.com
```

Восстановление требует чтобы  
1) мы инициализировали пусть даже на одном инстанс кластер и распечатали его  
2) сделали восстановления  
3) снова распечатали кластер старыми ключами  

## Инициализация первой ноды кластера
Произведем инициализацию
```
docker exec -it vault vault operator init \
  -address=https://127.0.0.1:8200 \
  -ca-cert=/opt/vault/config/ssl/ca.pem \
  -client-cert=/opt/vault/config/ssl/fullchain.pem \
  -client-key=/opt/vault/config/ssl/privkey.pem \
  -key-shares=5 \
  -key-threshold=3
```
увидим примерно следующий вывод
``` bash
Unseal Key 1: 569VbCN_____G2rQhH
Unseal Key 2: 23y3zWdcTMTHf______ak4Tn7+kbYEA57
Unseal Key 3: iJfG0pM______CQ31cydXU7UxJqhkJO
Unseal Key 4: NVhY2f______syWTxGhMEbB
Unseal Key 5: 6K6Ygo5QwS____QaE0v1BlVT

Initial Root Token: hvs.example_root_token
```  

Зайдем внутрь контейнера и распечатаем его


``` bash
docker exec -it vault sh

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/opt/vault/config/ssl/ca.pem
export VAULT_CLIENT_CERT=/opt/vault/config/ssl/fullchain.pem
export VAULT_CLIENT_KEY=/opt/vault/config/ssl/privkey.pem
export VAULT_SKIP_VERIFY=true

vault operator unseal key1
vault operator unseal key2
vault operator unseal key3
```

После удачного распечатывания увидим
``` bash
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.19.3
Build Date              2025-04-29T10:34:52Z
Storage Type            raft
Cluster Name            vault-stage
Cluster ID              bf12605b-3d84-fbf8-c782-0b4ced97f900
Removed From Cluster    false
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    32
Raft Applied Index      32
```

# Валидация бекапа
Предполагается, что у вас бекап лежит по пути (который доступен внутри контейнера), если вы устанавливали Vault этой ролью. В противном случае скорректируйте путь в соответствии с вашей конфигурацией.  
`/opt/vault/backup/vault-2025-06-16_11-41-56.snap`

Теперь мы про валидируем наш бекап, для чего в контейнере выполним команды ниже и важно, задать свой токен с предыдущего этапа 
``` bash
docker exec -it vault sh

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/opt/vault/config/ssl/ca.pem
export VAULT_CLIENT_CERT=/opt/vault/config/ssl/fullchain.pem
export VAULT_CLIENT_KEY=/opt/vault/config/ssl/privkey.pem

export VAULT_TOKEN=our_root_token
vault operator raft snapshot  inspect /opt/vault/backup/vault-2025-06-16_11-41-56.snap

```

увидим такой вывод
``` bash
ID           bolt-snapshot
 Size         767467
 Index        99964575
 Term         2273
 Version      1


 Key Name                                          Count      Size
 ----                                              ----       ----
 sys/token                                         571        263.6KB
 sys/expire                                        178        279.5KB
 logical/7c377830-670a-2222-f89a-51eb01d55672      139        58.9KB
 logical/c5040917-347d-1232-0feb-703abfeeece2      86         45KB
 logical/ba321fbc-ss21-8c99-d334-0d6e8f06f3b7      40         23.5KB
 ...
 Total Size                                                XXX.XKB
 ```

# Восстановление снапшота
Теперь мы восстановим снапшот. Ещё раз подчеркнём: важно, чтобы на момент восстановления кластер (состоящий из одной ноды) был инициализирован и распечатан.

Приступим. Ключ `-force` обязателен.
 ``` bash
docker exec -it vault sh

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/opt/vault/config/ssl/ca.pem
export VAULT_CLIENT_CERT=/opt/vault/config/ssl/fullchain.pem
export VAULT_CLIENT_KEY=/opt/vault/config/ssl/privkey.pem

export VAULT_TOKEN=our_root_token

vault operator raft snapshot restore -force /opt/vault/backup/vault-*.snap
vault status
```

В статусе мы увидим, что кластер снова находится в запечатанном состоянии.
``` bash
/ # vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  true
Total Shares            5
Threshold               3
Unseal Progress         0/3
Unseal Nonce            n/a
Version                 1.19.3
Build Date              2025-04-29T10:34:52Z
Storage Type            raft
Removed From Cluster    false
HA Enabled              true
```

Распечатаем его. Очень важно: у вас должны быть ключи от *старого* кластера — того, с которого был сделан снапшот.
``` bash
vault operator unseal old_key1
vault operator unseal old_key2
vault operator unseal old_key3
```

После успешной распаковки мы должны увидеть статус "Sealed: false", что подтверждает успешную инициализацию. Также обратите внимание на значение "Raft Committed Index" — оно должно быть высоким, так как отражает восстановленные данные.
``` bash
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.19.3
Build Date              2025-04-29T10:34:52Z
Storage Type            raft
Cluster Name            vault-stage
Cluster ID              090d9a23-91c0-7831-b51b-aeea25935078
Removed From Cluster    false
HA Enabled              true
HA Cluster              https://10.73.2.102:8211
HA Mode                 standby
Active Node Address     https:/127.0.0.1:8200
Raft Committed Index    99964579
Raft Applied Index      99964579
```

# Добавление новых нод в кластер
Теперь катим плейбук на оставшиеся ноды, рекомендую по одному, распаковывать новые ноды так же нужно старыми unseal ключами, так как кластер продолжит использовать их

```bash
ansible-playbook -i env/cluster inventory.yml -t vault-install --skip-tag vault --limit vault-02.example.com
```

Затем — третью ноду:
```bash
ansible-playbook -i env/cluster inventory.yml -t vault-install --skip-tag vault --limit vault-03.example.com
```