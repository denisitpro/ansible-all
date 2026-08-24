# HTTP Code Alert Convention

Blackbox exporter scrape jobs use the `expected_code` label to define the expected HTTP response code for a target group.
The label is set via `relabel_configs` at the scrape config level and matched in alert rules instead of the job name.

This decouples alert logic from job naming — renaming or restructuring jobs does not break alerts.

Jobs **without** `expected_code` are intentionally excluded from generic HTTP code alerts
(e.g., auth-gated endpoints or endpoints with dedicated alert rules).

## How to opt a job into HTTP code alerting

Add to `relabel_configs` in `prometheus_scrape_configs`:

```yaml
relabel_configs:
  - source_labels: [__address__]
    target_label: __param_target
  - source_labels: [__param_target]
    target_label: instance
  - target_label: __address__
    replacement: blackbox-exporter:9115
  - target_label: expected_code
    replacement: "200"   # set to the expected HTTP response code: "200", "404", etc.
```

Alert rules match by this label:

```promql
probe_http_status_code{expected_code="200"} != 200
probe_http_status_code{expected_code="404"} != 404
```

---

Job for monitoring other prometheus to endpoint federate

scrape_configs:
  - job_name: 'federate'
    honor_labels: true
    metrics_path: /federate
    params:
      match[]:
      - '{job=~".*."}'
    static_configs:
    - targets:
      - prom-01.example.com:9090

# Enable alert manager
Example 
```yaml
prometheus_alertmanager_config:
   - static_configs:
       - targets: ["127.0.0.1:9093"]
```

# Example alert rules

```yaml
prometheus_alert_rules:
  - alert: Watchdog
    expr: vector(1)
    for: 10m
    labels:
      severity: info
    annotations:
      description: 'This is an alert meant to ensure that the entire alerting pipeline is functional. '
      summary: 'Ensure entire alerting pipeline is functional'
  - alert: InstanceDown
    expr: 'up == 0'
    for: 5m
    labels:
      severity: critical
    annotations:
      description: "{% raw %}{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.{% endraw %}"
      summary: "{% raw %}Instance {{ $labels.instance }} down{% endraw %}"
  - alert: ClockSkewDetected
    expr: 'abs(node_timex_offset_seconds) * 1000 > 5'
    for: 2m
    labels:
      severity: warning
    annotations:
      description: "{% raw %}Clock skew detected on {{ $labels.instance }}. Ensure NTP is configured correctly on this host.{% endraw %}"
      summary: "{% raw %}Instance {{ $labels.instance }} - Clock skew detected{% endraw %}"
```

# Alert rules examples
See: https://monitoring.mixins.dev/node-exporter/