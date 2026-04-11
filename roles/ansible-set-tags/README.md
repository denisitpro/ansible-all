# Роль ansible-set-tags

Универсальная роль для динамического определения хостов по тегам и резолвинга их IP адресов (IPv4 и IPv6).

## Назначение

Роль позволяет автоматически формировать списки хостов на основе тегов из inventory файла и резолвить их IP адреса. Это полезно для динамической настройки правил firewall (UFW), когда состав хостов может меняться.

## Требования

**ВАЖНО:** Все хосты, которые должны быть обработаны ролью, должны иметь тег `ansible_fw_role` в inventory файле.

## Использование

### 1. Добавление тегов в inventory

В файле `hosts` добавьте тег `ansible_fw_role` к каждому хосту:

```ini
[k8s_master_c1_p2p]
server-01.example.com ansible_fw_role=k8s_master_p2p
server-02.example.com ansible_fw_role=k8s_master_p2p

[dkron_servers]
dkron-01.example.com ansible_fw_role=dkron_agent
dkron-02.example.com ansible_fw_role=dkron_agent
```

### 2. Конфигурация в group_vars

В файле `group_vars/<group>/ufw-tags-ansible.yml` определите конфигурацию:

```yaml
k8s_hosts_tag_configs:
  - tags:
      ansible_fw_role: k8s_master_p2p
    output_var_name: k8s_master_p2p_atag
  - tags:
      ansible_fw_role: k8s_worker_p2p
    output_var_name: k8s_worker_p2p_atag
```

### 3. Использование в правилах UFW

После выполнения роли, созданные переменные можно использовать в правилах:

```yaml
ufw_k8s_g1:
  ipv4:
    - name: "etcd-server-client"
      protocol: "tcp"
      port: "2379"
      source: "{{ k8s_master_p2p_atag | map(attribute='ipv4') | list }}"
```

## Примеры использования

### Kubernetes кластер

**Inventory:**
```ini
server-01.example.com ansible_fw_role=k8s_master_p2p
server-02.example.com ansible_fw_role=k8s_worker_p2p
```

**Конфигурация:**
```yaml
k8s_hosts_tag_configs:
  - tags:
      ansible_fw_role: k8s_master_p2p
    output_var_name: k8s_master_nodes
  - tags:
      ansible_fw_role: k8s_worker_p2p
    output_var_name: k8s_worker_nodes
```

### Dkron кластер

**Inventory:**
```ini
dkron-01.example.com ansible_fw_role=dkron_agent
dkron-02.example.com ansible_fw_role=dkron_agent
```

**Конфигурация:**
```yaml
k8s_hosts_tag_configs:
  - tags:
      ansible_fw_role: dkron_agent
    output_var_name: dkron_agent_atag
```

## Выходные данные

Роль создаёт переменные в формате:

```yaml
<output_var_name>:
  - name: "hostname.example.com"
    ipv4: "192.168.1.10"
    ipv6: "2001:db8::1"
  - name: "hostname2.example.com"
    ipv4: "192.168.1.11"
    ipv6: ""
```

Если у хоста нет IPv6 адреса, поле `ipv6` будет пустой строкой.

## Параметры роли

### k8s_hosts_tag_configs (обязательный)

Список конфигураций тегов для обработки.

**Структура:**
- `tags` - словарь с тегами для фильтрации (обязательно должен содержать `ansible_fw_role`)
- `output_var_name` - имя переменной, в которую будут сохранены результаты

### k8s_hosts_resolution_host (опциональный)

Хост, на котором будет выполняться резолвинг DNS. По умолчанию: `{{ ansible_play_hosts_all[0] }}`

## Примечания

- Роль использует `getent ahosts` для резолвинга DNS
- Резолвинг выполняется один раз и результаты распространяются на все хосты в play
- Роль автоматически определяет IPv4 и IPv6 адреса
- Если хост не резолвится, он будет пропущен

