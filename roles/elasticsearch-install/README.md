# elasticsearch-install

Ansible роль для развёртывания Elasticsearch 6.7.2 через Docker Compose.

## ЗАПУСК

**playbook.yml:**
```yaml
# Одиночный узел
- hosts: es1.example.com
  roles:
    - role: elasticsearch-install

# Кластер из трёх узлов
- hosts: es_nodes
  roles:
    - role: elasticsearch-install
      vars:
        es_cluster_name: "es_production"
        es_minimum_master_nodes: 2
        es_discovery_hosts:
          - "es1.example.com"
          - "es2.example.com"
          - "es3.example.com"
```

### Запуск

```bash
ansible-playbook playbook.yml --tags es
```

### Обновление конфигурации

```bash
ansible-playbook playbook.yml --tags es-config
```

### Обновление docker-compose

```bash
ansible-playbook playbook.yml --tags es-compose
```

## Переменные

### Основные

| Переменная | По умолчанию | Описание |
|---|---|---|
| `es_version` | `6.7.2` | Версия Elasticsearch |
| `es_image` | `docker.elastic.co/elasticsearch/elasticsearch` | Docker-образ |
| `es_image_name` | `{{ es_image }}:{{ es_version }}` | Полное имя образа |
| `es_restart` | `always` | Политика перезапуска контейнера |

### Пути

| Переменная | По умолчанию | Описание |
|---|---|---|
| `es_compose_path` | `/opt/docker/elasticsearch` | Каталог docker-compose |
| `es_base_path` | `/opt/elasticsearch` | Корневой каталог |
| `es_data_path` | `{{ es_base_path }}/data` | Каталог данных |
| `es_conf_path` | `{{ es_base_path }}/config` | Каталог конфигурации |
| `es_log_path` | `{{ es_base_path }}/logs` | Каталог логов |
| `es_uid` | `1000` | UID владельца файлов (elasticsearch) |
| `es_gid` | `1000` | GID владельца файлов (elasticsearch) |

### Кластер

| Переменная | По умолчанию | Описание |
|---|---|---|
| `es_cluster_name` | `es_production` | Имя кластера |
| `es_node_name` | `{{ inventory_hostname_short }}` | Имя узла |
| `es_network_host` | `0.0.0.0` | Адрес прослушивания |
| `es_http_port` | `9200` | HTTP-порт |
| `es_transport_port` | `9300` | Транспортный порт |

### Discovery (zen, для 6.x)

| Переменная | По умолчанию | Описание |
|---|---|---|
| `es_discovery_hosts` | `[]` | Список seed-хостов для обнаружения |
| `es_minimum_master_nodes` | `1` | Минимум мастер-узлов (для кластера N/2+1) |

### JVM и X-Pack

| Переменная | По умолчанию | Описание |
|---|---|---|
| `es_java_opts` | `-Xms1g -Xmx1g` | JVM heap (не более 50% RAM) |
| `es_xpack_security_enabled` | `false` | Включить X-Pack Security |
| `es_xpack_monitoring_enabled` | `false` | Включить X-Pack Monitoring |

## Теги

| Тег | Описание |
|---|---|
| `es` | Все задачи роли |
| `es-prefly` | Создание директорий |
| `es-config` | Генерация конфигурационных файлов |
| `es-compose` | Деплой через docker-compose |

## Примеры использования

### Одиночный узел (single-node)

**group_vars/es_hosts.yml:**
```yaml
es_cluster_name: "es_production"
es_java_opts: "-Xms2g -Xmx2g"
```

### Кластер из трёх узлов

**inventory:**
```ini
[es_nodes]
es1.example.com
es2.example.com
es3.example.com
```

**group_vars/es_nodes.yml:**
```yaml
es_cluster_name: "es_production"
es_minimum_master_nodes: 2
es_java_opts: "-Xms4g -Xmx4g"
es_discovery_hosts:
  - "es1.example.com"
  - "es2.example.com"
  - "es3.example.com"
```
