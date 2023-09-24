# EXAMPLE VARS FOR COPY DASHBOARD

```commandline
grafana_use_provisioning: true

grafana_dashboards_provision:
  folders:
    - "exporters"
    - "clickhouse"
  dashboards:
    - { folder: exporters, file: "node-exporter-1860_rev31.json"}
    - { file: "blackbox-exporter-7587_rev3.json"}

grafana_datasources:
  - name: prom
    type: prometheus
    access: proxy
    url: "http://prom.example.com:9090"
    isDefault: true
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    jsonData:
      defaultDatabase: data
      protocol: http
      port: 8123
      server: 1.2.3.4
      username: user
      tlsSkipVerify: true
    secureJsonData:
      password: "password"
    isDefault: false

# example install plugins
grafana_plugins: "grafana-clickhouse-datasource,grafana-clock-panel,grafana-piechart-panel"


```