# Zookeeper Setup Guide

## Introduction
This guide provides instructions for setting up a Zookeeper cluster with configurable parameters. It covers standalone and clustered deployments, metric activation, and server identification.

## Configuration Variables
```yaml
zookeeper_standalone: true
zookeeper_id_group_calculate: zoo_for_kafka_example

zookeeper_servers:
  - id: 1
    hostname: zookeeper-01.example.com
  - id: 2
    hostname: zookeeper-02.example.com
  - id: 3
    hostname: zookeeper-03.example.com
```

### Variable Descriptions

- **`zookeeper_standalone`** - Runs Zookeeper in standalone mode. When enabled, `zookeeper_id_group_calculate` and `zookeeper_servers` have no effect.
- **`zookeeper_id_group_calculate`** - Specifies the group containing Zookeeper servers to automatically compute their IDs. This works only if `zookeeper_servers` and `zookeeper_standalone` are not defined.
- **`zookeeper_servers`** - Explicitly defines the Zookeeper servers and their IDs. This is required when manually setting up a cluster and specifying server IDs. It does not work if `zookeeper_standalone` is enabled.

## Setting Up Zookeeper

### Standalone Mode
To run Zookeeper in standalone mode, set:
```yaml
zookeeper_standalone: true
```
This will disable clustering and run a single-instance Zookeeper.

### Clustered Mode - Automatic
To deploy Zookeeper in a cluster using automatic ID assignment, define the `zookeeper_id_group_calculate` parameter:
```yaml
zookeeper_id_group_calculate: zoo_for_kafka_example
```
Ensure all servers in the group are reachable and properly configured.

### Clustered Mode - Manual
To deploy Zookeeper in a cluster with manually assigned IDs, define the `zookeeper_servers` list:
```yaml
zookeeper_servers:
  - id: 1
    hostname: zookeeper-01.example.com
  - id: 2
    hostname: zookeeper-02.example.com
  - id: 3
    hostname: zookeeper-03.example.com
```
Ensure all servers in the list are reachable and properly configured.