# Prometheus External Labels Configuration

## Overview
This document describes how to configure external labels for Prometheus deployed via Helm in Kubernetes, providing the same flexibility as the Docker Compose version.

## Configuration

### Helm Prometheus (Kubernetes)
Use the `k8s_prometheus_external_labels` variable in your group_vars to define external labels:

```yaml
# Example: env/c1-p2p/group_vars/k8s_worker_c1_p2p/prometheus.yml
k8s_prometheus_external_labels:
  environment: "{{ ansible_fqdn | default(ansible_host) | default(inventory_hostname) }}"
  monitoring: monitoring
  replica: "{{ ansible_hostname | default(inventory_hostname) }}"
  datacenter: "{{ ansible_datacenter | default('unknown') }}"
  region: "{{ ansible_region | default('unknown') }}"
```

### Docker Compose Prometheus
Use the `prometheus_external_labels` variable (existing functionality):

```yaml
# Example: env/c1-infra/group_vars/exporters_c1_infra/prom.yml
prometheus_external_labels:
  environment: "{{ ansible_fqdn | default(ansible_host) | default(inventory_hostname) }}"
  monitoring: monitoring
  cluster: prom-c1-infra-scraper
  replica: "{{ ansible_hostname | default(inventory_hostname) }}"
```

## Template Changes

### Helm Template (prometheus-values.yaml.j2)
The template now supports dynamic external labels:

```yaml
prometheusSpec:
  externalLabels:
    cluster: {{ k8s_prom_cluster_id | default('k8s-cluster.example') }}
{% if k8s_prometheus_external_labels is defined %}
{% for k, v in k8s_prometheus_external_labels.items() %}
    {{ k }}: "{{ v }}"
{% endfor %}
{% endif %}
```

### Compose Template (prometheus.yml.j2)
Existing functionality remains unchanged:

```yaml
global:
  external_labels:
    {{ prometheus_external_labels | to_nice_yaml(indent=2) | indent(4, False) }}
```

## Benefits

1. **Unified Configuration**: Both deployment methods now support the same external labels format
2. **Dynamic Values**: Support for Ansible variables and templating
3. **Flexibility**: Easy to add/remove labels without template changes
4. **Consistency**: Same labeling strategy across different deployment methods

## Usage Examples

### Basic Configuration
```yaml
k8s_prometheus_external_labels:
  environment: production
  monitoring: prometheus
  cluster: k8s-cluster-1
```

### Dynamic Configuration with Ansible Variables
```yaml
k8s_prometheus_external_labels:
  environment: "{{ ansible_fqdn | default(ansible_host) | default(inventory_hostname) }}"
  monitoring: monitoring
  replica: "{{ ansible_hostname | default(inventory_hostname) }}"
  datacenter: "{{ ansible_datacenter | default('unknown') }}"
  region: "{{ ansible_region | default('unknown') }}"
  zone: "{{ ansible_zone | default('unknown') }}"
```

### Conditional Configuration
```yaml
{% if ansible_os_family == "RedHat" %}
k8s_prometheus_external_labels:
  os_family: redhat
  os_version: "{{ ansible_distribution_major_version }}"
{% elif ansible_os_family == "Debian" %}
k8s_prometheus_external_labels:
  os_family: debian
  os_version: "{{ ansible_distribution_major_version }}"
{% endif %}
```

## Migration from Compose to Helm

If you're migrating from Docker Compose to Helm deployment, you can reuse your existing external labels configuration by simply changing the variable name:

**Before (Compose):**
```yaml
prometheus_external_labels:
  environment: "{{ ansible_fqdn }}"
  monitoring: monitoring
```

**After (Helm):**
```yaml
k8s_prometheus_external_labels:
  environment: "{{ ansible_fqdn }}"
  monitoring: monitoring
```

## Notes

- The `cluster` label is automatically set from `k8s_prom_cluster_id` and cannot be overridden via `k8s_prometheus_external_labels`
- All label values are automatically quoted in the template
- The configuration is optional - if `k8s_prometheus_external_labels` is not defined, only the default `cluster` label will be set 