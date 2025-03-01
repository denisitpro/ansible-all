# Description

* Dockerfile - https://github.com/ClickHouse/ClickHouse/blob/master/docker/keeper/Dockerfile
* Reference config file - https://github.com/ClickHouse/ClickHouse/blob/master/programs/keeper/keeper_config.xml

# Ansible Role: Keeper ID Configuration

## Overview
This Ansible role is responsible for calculating and assigning the `keeper_id` for servers based on predefined logic. It ensures that each server in the cluster is uniquely identified, whether the configuration is provided via `host_vars` or dynamically computed based on `raft_servers` or a designated inventory group.

## How It Works
The `keeper_id` is assigned using the following logic:

1. If both `keeper_id` and `raft_servers` are defined in `host_vars`, the role **fails** with an error to prevent misconfiguration.
2. If `keeper_id` is explicitly set in `host_vars` and `raft_servers` is **not** defined, this value is used.
3. If neither `keeper_id` nor `raft_servers` are defined:
   - The role dynamically assigns a `keeper_id` based on the index of the host within the `keeper_id_group_calculate` group.
4. If `raft_servers` is defined:
   - The role verifies that all hosts listed in `raft_servers` exist in `keeper_id_group_calculate`.
   - Each host is assigned the corresponding `id` from `raft_servers`.

## Requirements
- Ansible 2.9+
- A defined `keeper_id_group_calculate` variable referencing a valid inventory group
- If using `raft_servers`, it must contain all expected hosts and match `keeper_id_group_calculate`

## Role Variables

| Variable                 | Description                                                | Default       |
|--------------------------|------------------------------------------------------------|--------------|
| `keeper_id`              | Explicitly set `keeper_id` at the host level (highest priority) | `undefined`  |
| `keeper_id_group_calculate` | Group used for dynamic `keeper_id` calculation            | `undefined`  |
| `raft_servers`           | List of servers with manually assigned IDs for Raft       | `undefined`  |

## SSL Support

By default, the Keeper server listens on a **plain text TCP port**. To enable SSL/TLS using **self-signed certificates**, set the boolean variable `keeper_enable_ssl` to `true`.

### How to Enable SSL
To enable SSL, define the following variable in your group or host configuration:

```yaml
keeper_enable_ssl: true
```

By setting `keeper_enable_ssl: true`, Keeper will start listening on a **secure port** and use the certificates located in `keeper_ssl_path`.

## Usage Examples

### **1. Using a Dynamic Calculation Based on Group Membership**
If `keeper_id` is not explicitly set, it is computed dynamically based on the inventory group defined in `keeper_id_group_calculate`:

```yaml
# group_vars/keeper_servers/vars.yml
keeper_id_group_calculate: "keeper_servers"
```

This will automatically assign sequential IDs to hosts in the `keeper_servers` group.

---

### **2. Manually Defining `keeper_id` in `host_vars`**
You can manually set `keeper_id` for a specific host in `host_vars`:

```yaml
# host_vars/server1.yml
keeper_id: 3
```

This takes priority over dynamic calculation.

---

### **3. Using `raft_servers` for Explicit Mapping**
If you want to control `keeper_id` using a predefined list (`raft_servers`), define it as follows:

```yaml
# group_vars/keeper_servers/vars.yml
keeper_id_group_calculate: "keeper_servers"
raft_servers:
  - id: 12
    hostname: zoo-01.example.com
  - id: 22
    hostname: zoo-02.example.com
  - id: 30
    hostname: zoo-03.example.com
```

In this case:
- The role checks that all hosts in `raft_servers` exist in `keeper_id_group_calculate`.
- Each server is assigned the corresponding `id` from `raft_servers`.
---

## Debugging
```yaml
- name: Debug - Display keeper_id assignment
  ansible.builtin.debug:
    msg: "Server {{ inventory_hostname }} has keeper_id {{ keeper_id }}"
```

---

## Notes
- **`keeper_raft_array` has been completely removed**. The role only relies on `keeper_id_group_calculate` for dynamic assignments.
- **Fail-fast mechanism**: If `keeper_id` and `raft_servers` are both defined, execution stops to avoid misconfiguration.
- The role ensures that `raft_servers` is valid and contains only hosts from `keeper_id_group_calculate`.

---

This role helps maintain a **consistent and error-free** `keeper_id` assignment process for ClickHouse Keeper configurations.