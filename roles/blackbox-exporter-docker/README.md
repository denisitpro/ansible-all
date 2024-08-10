# Description
для работы с blackbox exporter, надо в конфиг прометея добавить массив что хотим мониторить и где находится экспортер
blackbox.example.com:9115

```yaml
prometheus_scrape_configs:
  - job_name: "blackbox_200x"
    metrics_path: /probe
    params:
      module:
       - http_200_module
       - icmp
    static_configs:
    - targets:
        - https://tonstakers.com
        - https://tp.ton-tech.org/
#        - https://api.tonstakers.com
    relabel_configs:
     - source_labels: [__address__]
       target_label: __param_target
     - source_labels: [__param_target]
       target_label: instance
     - target_label: __address__
       replacement: localhost:9115
  - job_name: "blackbox_404"
    metrics_path: /probe
    params:
      module:
       - http_404_module
       - icmp
    static_configs:
    - targets:
        - https://api.tonstakers.com
    relabel_configs:
     - source_labels: [__address__]
       target_label: __param_target
     - source_labels: [__param_target]
       target_label: instance
     - target_label: __address__
       replacement: localhost:9115
```