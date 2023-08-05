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


https://www.robustperception.io/debugging-out-of-order-samples


# Example config for alert telegram
```yaml
---
alertmanager_route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: receiver-telegram


alertmanager_receivers:
  - name: "receiver-telegram"
    telegram_configs:
      - bot_token: "bot_token"
        api_url: https://api.telegram.org
        chat_id: -chat_id
        parse_mode: HTML
```