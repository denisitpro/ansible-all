# ClickHouse Alerts Configuration

## Overview

ClickHouse алерты поддерживают исключение инстансов как по конкретным именам, так и по тегам, аналогично алертам для дисков.

## Available Alerts

1. **HighClickHouseTCPConnections** - алерт на высокое количество TCP соединений
2. **HighClickHouseHTTPConnections** - алерт на высокое количество HTTP соединений  
3. **ClickHouseTCPConnectionsBelow1** - алерт на количество TCP соединений ниже 1

## Configuration Variables

### Исключение по инстансам

```yaml
# Исключить конкретные инстансы из алерта на высокие соединения
excld_inst_high_click_connections: 
  - "clickhouse-prod-1.example.com"
  - "clickhouse-prod-2.example.com"

# Исключить конкретные инстансы из алерта на соединения ниже 1
excld_instance_click_below_1_inst:
  - "clickhouse-dev-1.example.com"
  - "clickhouse-test-1.example.com"
```

### Исключение по тегам

```yaml
# Исключить инстансы с определенными тегами из алерта на высокие соединения
excld_tags_high_click_connections:
  - "dev"
  - "test"
  - "high-load"

# Исключить инстансы с определенными тегами из алерта на соединения ниже 1
excld_tags_click_below_1:
  - "dev"
  - "test"
```

## Пример использования

В вашем inventory или group_vars:

```yaml
# Исключить все dev и test инстансы из всех ClickHouse алертов
excld_tags_high_click_connections: ["dev", "test"]
excld_tags_click_below_1: ["dev", "test"]

# Исключить конкретные продакшн инстансы из алертов на высокие соединения
excld_inst_high_click_connections:
  - "clickhouse-prod-1.example.com"
  - "clickhouse-prod-2.example.com"
```

## Принцип работы

- **Исключение по инстансам**: точное совпадение имени инстанса
- **Исключение по тегам**: регулярное выражение `.*tag.*` для поиска тега в строке тегов

Теги работают аналогично алертам для дисков, используя тот же механизм фильтрации.
