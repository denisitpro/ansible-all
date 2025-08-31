# Kubernetes Components Installation Role

This Ansible role installs and configures various Kubernetes components including Prometheus monitoring stack.

## Prometheus Monitoring Configuration

### Overview

The role configures Prometheus to monitor Kubernetes pods and services using annotations. Prometheus automatically discovers targets based on configured selectors and scrapes metrics from them.

### Monitoring Logic

#### 1. Service Monitoring (applications-monitor)
- **Target**: Kubernetes services with `prometheus.io/scrape: "true"` annotation
- **Discovery**: Uses `kubernetes_sd_configs` with `role: endpoints`
- **Scope**: All namespaces (configurable via `namespaces.names`)

#### 2. Pod Monitoring (kubernetes-pods)
- **Target**: Kubernetes pods with `prometheus.io/scrape: "true"` annotation
- **Discovery**: Uses `kubernetes_sd_configs` with `role: pod`
- **Scope**: All namespaces (configurable via `k8s_pod_monitoring_config`)
- **Conditional**: Only enabled when `k8s_pod_monitoring_enabled: true`

### Required Annotations

To enable monitoring for your pods/services, add these annotations:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"        # Enable scraping
    prometheus.io/port: "8080"          # Port for metrics
    prometheus.io/path: "/metrics"      # Metrics endpoint path
    prometheus.io/scheme: "http"        # Protocol (http/https)
```

### Configuration Variables

#### Default Values (roles/k8s-components-install/defaults/main.yml)

```yaml
# Enable/disable pod monitoring
k8s_pod_monitoring_enabled: true

# Pod monitoring configuration
k8s_pod_monitoring_config:
  # Pod selector configuration
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  
  # Namespace selector (empty = all namespaces)
  namespaceSelector: {}

# Default port for pod monitoring (fallback)
k8s_pod_monitoring_default_port: 8080
```

#### Cluster-Specific Override (env/<cluster>/group_vars/k8s_worker_<cluster>/prometheus.yml)

```yaml
# Override default pod monitoring settings
k8s_pod_monitoring_enabled: true

# Custom pod monitoring configuration
k8s_pod_monitoring_config:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
      # Add custom labels if needed
      app_type: "monitored"
  
  namespaceSelector:
    # Monitor specific namespaces only
    matchExpressions:
      - key: name
        operator: NotIn
        values:
          - kube-system
          - monitoring
          - default

# Custom default port
k8s_pod_monitoring_default_port: 9090
```

### Loki Monitoring Configuration

Enable ServiceMonitor for Loki to allow prometheus-operator to scrape Loki metrics:

```yaml
# Enable Loki monitoring (default: false)
k8s_loki_monitoring_enabled: true
```

When enabled, this configuration:
- Creates ServiceMonitor resources for all Loki components
- Adds Grafana dashboards for Loki monitoring
- Sets up Prometheus alerting rules for Loki
- Uses standard prometheus-operator labels for discovery

### Advanced Configuration

#### Custom Selectors

You can customize which pods are monitored by modifying the selector:

```yaml
k8s_pod_monitoring_config:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
      environment: "production"
      team: "platform"
```

#### Namespace Filtering

To monitor only specific namespaces:

```yaml
k8s_pod_monitoring_config:
  namespaceSelector:
    matchExpressions:
      - key: name
        operator: In
        values:
          - app-namespace
          - monitoring-namespace
```

To exclude specific namespaces:

```yaml
k8s_pod_monitoring_config:
  namespaceSelector:
    matchExpressions:
      - key: name
        operator: NotIn
        values:
          - kube-system
          - monitoring
          - default
```

### Monitoring Features

#### Automatic Discovery
- Prometheus automatically discovers new pods/services with required annotations
- No manual configuration needed for new deployments
- Dynamic namespace support

#### Relabeling Rules
- **Service Labels**: Automatically mapped to Prometheus labels
- **Pod Labels**: Automatically mapped to Prometheus labels
- **Custom Labels**: Configurable via `k8s_prometheus_external_labels`
- **Instance Label**: Automatically set to pod/service address

#### Health Checks
- **Pod Phase Filtering**: Failed and Succeeded pods are automatically dropped
- **Port Fallback**: Uses named container port "metrics" if annotation port is not set
- **Scheme Support**: HTTP/HTTPS protocol detection via annotations

### Example Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
        prometheus.io/scheme: "http"
    spec:
      containers:
      - name: app
        ports:
        - name: metrics
          containerPort: 8080
```

### Troubleshooting

#### Pod Not Appearing in Targets
1. Check if `k8s_pod_monitoring_enabled: true`
2. Verify pod has `prometheus.io/scrape: "true"` annotation
3. Ensure pod is in Running state
4. Check if pod is in excluded namespace

#### Metrics Not Scraping
1. Verify port annotation matches container port
2. Check if metrics endpoint is accessible
3. Ensure scheme (http/https) is correct
4. Verify metrics path exists

#### Configuration Issues
1. Check Prometheus logs for YAML parsing errors
2. Verify variable syntax in group_vars
3. Ensure proper indentation in templates
4. Check for missing required variables

### Security Considerations

- **Network Policies**: Ensure Prometheus can reach pod metrics endpoints
- **RBAC**: Verify Prometheus has necessary permissions to discover pods
- **TLS**: Use `prometheus.io/scheme: "https"` for secure endpoints
- **Authentication**: Consider implementing basic auth for sensitive metrics

### Performance Tuning

- **Scrape Interval**: Default 30s, adjust based on metrics update frequency
- **Scrape Timeout**: Default 10s, increase for slow-responding endpoints
- **Target Limits**: Monitor number of active targets to prevent overload
- **Memory Usage**: Large number of targets may increase Prometheus memory usage
