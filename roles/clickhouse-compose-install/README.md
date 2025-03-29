# Description

* Dockerfile - https://github.com/ClickHouse/ClickHouse/blob/master/docker/server/Dockerfile.ubuntu
* Reference config file - https://github.com/ClickHouse/ClickHouse/blob/master/programs/server/config.xml
* Users.xml https://github.com/ClickHouse/ClickHouse/blob/master/programs/server/users.xml
* file config-default-example.xml - only for example and fast check parametrs


# C1 company cluster example config
```yaml
# Support SSL ports
click_enable_ssl: true

# set array replicas for cluster1 shard
click_remote_servers:
  - name: "cluster1"
    shards:
      - replicas:
          - host: "click-01.example.com"
          - host: "click-02.example.com"
          - host: "click-03.example.com"

# Set clickhouse keeper group name inventory
click_zookeeper_servers: "keeper_example_group"

# compability old LTS config
click_access_control_improvements: true

# if need support cold disk storage
click_storage_disk_cold_data_path: "{{ click_base_path }}/cold/"

# C1 set macro
click_macros:
  shard: "01"
  replica: "{{ inventory_hostname_short }}"
```

# Remote server description
# Ansible Role: ClickHouse Remote Servers

This Ansible role generates a `remote_servers.xml` configuration file for ClickHouse based on dynamic input variables.

## 📌 Features
- Supports multiple **server clusters** (`remote_servers`).
- Defines multiple **shards** within each cluster.
- Allows **multiple replicas** per shard.
- Customizable **port** for each replica (defaults to `9000`).
- Uses **Jinja2 templating** for dynamic configuration generation.

---

## 🚀 Usage

### **1. Define Remote Servers in Your Inventory**
Set up `click_remote_servers` as an Ansible variable:

```yaml
click_remote_servers:
  - name: "server42"
    shards:
      - replicas:
          - host: "server1"
          - host: "server2"
      - replicas:
          - host: "server3"
          - host: "server4"
  - name: "server49"
    shards:
      - replicas:
          - host: "server9"
          - host: "server10"
```

### **2. Example Playbook**
Include this role in your Ansible playbook:

```yaml
- name: Deploy ClickHouse Remote Servers Config
  hosts: clickhouse_nodes
  roles:
    - clickhouse_remote_servers
```

---

## 🎯 Customization

### **Change Default Port**
By default, the template sets all replica ports to `9000`.  
To override the port, modify your inventory:

```yaml
click_remote_servers:
  - name: "server42"
    shards:
      - replicas:
          - host: "server1"
            port: "9001"
          - host: "server2"
            port: "9002"
```

---

## 📉 Role Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `click_remote_servers` | List of ClickHouse server clusters | **Required** |
| `name` | Name of the ClickHouse cluster | **Required** |
| `shards` | List of shards within the cluster | **Required** |
| `replicas` | List of replicas per shard | **Required** |
| `internal_replication` | Enable internal replication for shards | `true` |
| `port` | ClickHouse server port | `9000` |

---



# ClickHouse Zookeeper Configuration Role

This Ansible role configures ClickHouse to use Zookeeper for distributed coordination.  
The `click_zookeeper_servers` variable can be defined in three ways:
The role will automatically extract hosts from this group.

## 1. **As an Ansible inventory group**  
```yaml
   click_zookeeper_servers: "zoo_example"
```   
## 2.	As a list of dictionaries (manual configuration)
```yaml
click_zookeeper_servers:
  - { hostname: "zoo-01.example.com", port "2181" }
  - { hostname: "zoo-02.example.com" }
  - { hostname: "zoo-03.example.com" }
```    
## 3. By default, Zookeeper is disabled
If click_zookeeper_servers is not set or an empty list ([]), the role will skip Zookeeper configurat

##  zoo variables

| Variable | Description | Default |
|----------|-------------|---------|
| `hostname` | List of zookeeper servers | **Required** |
| `port` | ClickHouse server port | `9000` |

---
