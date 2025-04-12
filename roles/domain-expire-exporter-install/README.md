# Docs
* https://github.com/caarlos0/domain_exporter


# Example prometheus config
```yaml
  - job_name: "domain_expire"
    metrics_path: /probe
    scrape_interval: 300s
    scrape_timeout: 120s
    static_configs:
    - targets:
        - example.net
        - exxample.com
    relabel_configs:
     - source_labels: [__address__]
       target_label: __param_target
     - source_labels: [__param_target]
       target_label: instance
     - target_label: __address__
       replacement: exporters-01.example.org:9222
```       