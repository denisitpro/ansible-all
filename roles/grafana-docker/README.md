# Description

## Get GitHub Team ID

To retrieve your GitHub team ID, you can use the following `curl` command:

```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" https://api.github.com/orgs/ORG_NAME/teams
```

Replace `YOUR_GITHUB_TOKEN` with your actual GitHub token and `ORG_NAME` with the name of your organization.

## Get Your GitHub Token

To generate or manage your GitHub personal access token, refer to the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

### Classic GitHub Token Usage

If you are using a classic GitHub token, ensure it has the following scope:
- `admin:org_hook`
---

todo:
Need to refactore
# Example work env - base
```commandline
grafana_restart: true
gf_server_root_url: https://grafana.example.com
grafana_allowed_origins: "https://localhost:3000"
ssl_key_app_path: "{{grafana_ssl_path}}"
grafana_protocol: h2

grafana_ssl_enabled: true
grafana_self_sign_used: true

#grafana_use_provisioning: true
```


# Example work env - provision

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