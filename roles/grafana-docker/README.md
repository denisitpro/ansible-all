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
    - { folder: clickhouse, file: "ci-clickhouse-analysis-v1.json"}

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
```
# example install plugins
grafana_plugins: "grafana-clickhouse-datasource,grafana-clock-panel,grafana-piechart-panel"


# delete datasoruce
need set vars and launch use tag grafana-datasource
grafana_delete_datasources: "example"

array for remove datasource
```
grafana_delete_datasources:
  - name: datasource-test
    orgId: 1
```  


# hand relaod datasource
`curl -u admin:pass  -k -X POST  https://127.0.0.1:3000/api/admin/provisioning/datasources/reload`