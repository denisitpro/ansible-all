# Kafka UI Configuration for Ansible

This repository provides configuration management for deploying [Kafka UI](https://github.com/provectus/kafka-ui) via Docker Compose using Ansible.  
It supports managing multiple Kafka clusters via a structured list of variables.

## Variable Format

To define Kafka clusters, use the following format in your group or host variables:

```yaml
kafka_ui_clusters:
  - name: "example-cluster-1"
    bootstrapServers: "kafka-01.example.com:9092"
    zookeeper: "kafka-01.example.com:9093"
  - name: "example-cluster-2"
    bootstrapServers: "kafka-02.example.com:9092"
    zookeeper: "kafka-02.example.com:9093"
```

## Defaults

The following values are used by default unless explicitly overridden:

- `security.protocol`: `PLAINTEXT`
- `sasl.mechanism`: `PLAIN`
- `metrics.type`: `PROMETHEUS`
- `metrics.port`: `9308`

## Dynamic Config - disable

The dynamic configuration wizard in Kafka UI is enabled by default:

```yaml
dynamic.config:
  enabled: true
```

This allows runtime changes to cluster configurations directly from the web interface.
