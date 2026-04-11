# Ansible Role: vector-install-g3

Ansible role for installing and configuring Vector (https://vector.dev/) - a high-performance observability data pipeline.

## Requirements

- Ansible 2.9+
- For Docker installation: Docker and Docker Compose must be installed

## Installation Mode

**IMPORTANT**: You MUST explicitly set ONE of these variables to `true`:

```yaml
# Install as systemd unit
vector_install_unit: true

# OR install as Docker container
vector_install_docker: true
```

By default both are `false` and the role will not install anything.

## Features

### Automatic Log Format Detection and Routing

The role includes automatic routing for Docker logs based on container labels:

- Set `log_format: "angie_extend_json"` label on container to enable specialized Angie/Nginx JSON log parsing
- All other containers use default JSON parser
- Extensible: easy to add new log format parsers

## Configuration Examples

### Example 1: Docker Logs with Angie Extended JSON Format

This example shows how to parse Angie/Nginx logs with `extend_json` format and send them to Loki with rich labels for filtering.

**Set label in docker-compose.yml:**

```yaml
services:
  angie:
    image: docker.angie.software/angie:1.10.3
    labels:
      log_format: "angie_extend_json"
    # ... rest of config
```

**Vector configuration in group_vars:**

```yaml
vector_install_docker: true

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "cadvisor"
        - "consul"
        - "vector"

vector_transforms:
  # Parse Angie extend_json logs (routed by label log_format: angie_extend_json)
  - name: angie-extend-json-parser
    inputs:
      - docker-logs_route.angie_extend_json
  # Parse default docker logs (all other containers)
  - name: docker-transform-to-json
    inputs:
      - docker-logs_route._unmatched

vector_sinks:
  # Sink for Angie logs with extended labels for filtering without | json
  - name: loki-angie
    type: loki
    endpoint: "https://loki.example.com"
    inputs:
      - angie-extend-json-parser
    labels:
      environment: "production"
      app: myapp
      hostname: "{{ inventory_hostname_short }}"
      # Dynamic labels from parsed Angie fields (low cardinality)
      service: "{{ '{{' }} service {{ '}}' }}"
      container_name: "{{ '{{' }} container_name {{ '}}' }}"
      parser_used: "{{ '{{' }} parser_used {{ '}}' }}"
      status: "{{ '{{' }} status {{ '}}' }}"
      server_name: "{{ '{{' }} server_name {{ '}}' }}"
      request_method: "{{ '{{' }} request_method {{ '}}' }}"
    tls:
      enabled: true

  # Sink for other Docker logs with basic labels
  - name: loki-docker
    type: loki
    endpoint: "https://loki.example.com"
    inputs:
      - docker-transform-to-json
    labels:
      environment: "production"
      app: myapp
      hostname: "{{ inventory_hostname_short }}"
      service: "{{ '{{' }} service {{ '}}' }}"
      parser_used: "{{ '{{' }} parser_used {{ '}}' }}"
    tls:
      enabled: true
```

**Grafana LogQL query examples:**

```logql
# All errors (status 5xx)
{status=~"5.."}

# All 4xx and 5xx errors
{status=~"[45].."}

# All POST requests to specific server
{server_name="api.example.com", request_method="POST"}

# All logs processed by angie parser with errors
{parser_used="angie_extend_json", status=~"[45].."}

# Filter by port (requires | json for numeric comparison)
{server_name="api.example.com"} | server_port == 443

# Search in message content with status filter
{status="200"} |= "health"

# Combine label and content filters
{server_name="api.example.com", request_method="GET"} | status >= 400
```

### Example 2: Simple Docker Logs to Loki

```yaml
vector_install_unit: true

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "cadvisor"
        - "consul"
        - "vector"

vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs

vector_sinks:
  - name: loki-central
    type: loki
    endpoint: "http://loki.example.com:3100"
    inputs:
      - docker-transform-to-json
    labels:
      environment: "production"
      hostname: "{{ inventory_hostname }}"
```

#### Docker Logs to Loki with mTLS

```yaml
vector_install_unit: true
vector_mtls_enabled: true

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "cadvisor"
        - "consul"
        - "vector"

vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs

vector_sinks:
  - name: loki-central
    type: loki
    endpoint: "https://loki.example.com:3100"
    inputs:
      - docker-transform-to-json
    labels:
      environment: "production"
      hostname: "{{ inventory_hostname }}"
    tls:
      enabled: true
```

### File Logs to Loki

```yaml
vector_install_unit: true

vector_sources:
  - name: app-logs
    type: file
    include: "/var/log/myapp/**/*.log"
    exclude: "/var/log/myapp/**/debug.log"

vector_sinks:
  - name: loki-central
    type: loki
    endpoint: "http://loki.example.com:3100"
    inputs:
      - app-logs
    projects_default_labels: true
    labels:
      app: "myapp"
```

### Docker Logs to Elasticsearch

```yaml
vector_install_docker: true

vector_environment:
  ELASTIC_PASSWORD: "secure_password"

vector_environment_compose:
  ELASTIC_PASSWORD: "${ELASTIC_PASSWORD}"

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "vector"

vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs

vector_sinks:
  - name: to-elasticsearch
    type: elasticsearch
    inputs:
      - input: docker-transform-to-json
        index_prefix: "docker-logs-%Y.%m.%d"
    endpoints:
      - "https://es-node1.example.com:9200"
      - "https://es-node2.example.com:9200"
    auth:
      user: "elastic"
      password: "${ELASTIC_PASSWORD}"
    tls:
      enabled: true
      ca_file: "/opt/mtls/base100/ca.pem"
```

### Docker Logs to Syslog/Graylog

```yaml
vector_install_unit: true

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "vector"

vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs

vector_sinks_graylog:
  - name: graylog-prod
    endpoint: "graylog.example.com:514"
    mode: "udp"
    inputs:
      - docker-transform-to-json
```

### Vector Aggregator with mTLS

```yaml
vector_install_unit: true
vector_mtls_enabled: true

vector_sources:
  - name: remote-logs
    type: vector
    address: "[::]:7000"
    tls:
      enabled: true

vector_sinks:
  - name: loki-central
    type: loki
    endpoint: "http://loki.example.com:3100"
    inputs:
      - remote-logs
    labels:
      environment: "production"
```

### Send Logs to Remote Vector

```yaml
vector_install_docker: true
vector_mtls_enabled: true

vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "vector"

vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs

vector_sinks:
  - name: vector-aggregator
    type: vector
    address: "vector.example.com:7000"
    inputs:
      - docker-transform-to-json
    tls:
      enabled: true
```

## Sources Configuration

### Docker Logs
```yaml
vector_sources:
  - name: docker-logs
    type: docker_logs
    containers:
      exclude:
        - "container-name"
      # OR
      include:
        - "container-name"
```

### File Logs
```yaml
vector_sources:
  - name: file-logs
    type: file
    include: "/var/log/app/**/*.log"
    exclude: "/var/log/app/**/debug.log"
```

### Remote Vector Source (with mTLS)
```yaml
vector_sources:
  - name: remote-logs
    type: vector
    address: "[::]:7000"
    tls:
      enabled: true
```

## Transforms

Available transforms:
- `docker-transform-to-json` - Transform Docker logs to JSON
- `projects-json-transform-to-loki` - Parse JSON logs from files
- `pve-transform-to-elk` - Parse Proxmox VE logs for Elasticsearch

```yaml
vector_transforms:
  - name: docker-transform-to-json
    inputs:
      - docker-logs
    docker_platform: "production"  # Optional, default: hostname
```

## Sinks Configuration

### Loki
```yaml
vector_sinks:
  - name: loki-prod
    type: loki
    endpoint: "http://loki.example.com:3100"
    inputs:
      - transform-name
    labels:
      key: "value"
```

#### Loki with mTLS
```yaml
vector_install_unit: true
vector_mtls_enabled: true

vector_sinks:
  - name: loki-prod
    type: loki
    endpoint: "https://loki.example.com:3100"
    inputs:
      - transform-name
    labels:
      key: "value"
    tls:
      enabled: true
```

### Elasticsearch
```yaml
vector_sinks:
  - name: to-elasticsearch
    type: elasticsearch
    inputs:
      - input: transform-name
        index_prefix: "logs-%Y.%m.%d"
    endpoints:
      - "https://es.example.com:9200"
    auth:
      user: "elastic"
      password: "${ELASTIC_PASSWORD}"
    tls:
      enabled: true
      ca_file: "/path/to/ca.pem"
```

### Vector (remote)
```yaml
vector_sinks:
  - name: vector-remote
    type: vector
    address: "vector.example.com:7000"
    inputs:
      - transform-name
    tls:
      enabled: true
```

### Syslog/Graylog
```yaml
vector_sinks_graylog:
  - name: graylog
    endpoint: "graylog.example.com:514"
    mode: "udp"  # or "tcp"
    inputs:
      - transform-name
```

### File
```yaml
vector_sinks:
  - name: to-file
    type: file
    inputs:
      - transform-name
    path: "/var/log/output/{{'{{'}} container_name {{'}}'}}-%Y-%m-%d.log"
```

## mTLS Configuration

```yaml
vector_mtls_enabled: true
vector_mtls_cert_path: "/opt/mtls/base100"
vector_mtls_ca_cert: "{{ vault_dict_users_secret_g2.mtls_base100.mtls_ca }}"
vector_mtls_server_cert: "{{ vault_dict_users_secret_g2.mtls_base100.mtls_cert }}"
vector_mtls_server_key: "{{ vault_dict_users_secret_g2.mtls_base100.mtls_key }}"
```

## Tags

- `vector` - All tasks
- `vector-unit` - Systemd unit tasks
- `vector-docker` - Docker tasks
- `vector-config` - Configuration tasks
- `vector-mtls` - mTLS certificate tasks

## License

MIT
