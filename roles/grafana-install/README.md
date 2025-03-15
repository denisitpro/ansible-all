# Example Work Environment - Base Configuration

Example of configuring Grafana with a basic setup bound to `http://127.0.0.1:3000`

```yaml
gf_server_root_url: https://grafana.example.com
```

## Example Configuration of Grafana Without NGINX Using H2 and Self-Signed Certificate

Below is an example configuration for running Grafana directly, with support for HTTP/2 and a self-signed certificate:

```yaml
gf_server_root_url: https://grafana.example.com
grafana_allowed_origins: "https://grafana.example.com"
grafana_protocol: h2
grafana_domain: selfsign
grafana_bind_addr: '0.0.0.0'
grafana_srv_port: 443
grafana_force_port443: true
```
### Explanation of Parameters:

- **gf_server_root_url**: The public URL where Grafana will be accessible.
- **grafana_allowed_origins**: Specifies the allowed origins for cross-origin requests.
- **grafana_protocol**: Sets the protocol to HTTP/2 (`h2`) for improved performance.
- **grafana_domain**: Indicates the use of a self-signed certificate (`selfsign`).
- **grafana_bind_addr**: Configures Grafana to listen on all network interfaces (`0.0.0.0`).
- **grafana_srv_port**: Sets the port Grafana will listen on (default: `443` for HTTPS).
- **grafana_force_port443**: Forces Grafana to bind to port `443`.


# Configure GitHub Authentication for Grafana

To enable GitHub authentication in Grafana, ensure the following parameters are correctly configured:

```yaml
gf_server_root_url: https://grafana.example.com
grafana_oidc_github: true  
gf_auth_github_client_id: client_id  
gf_auth_github_client_secret: client_token  
gf_auth_github_allowed_organizations: example-org  
gf_auth_github_allow_skip_allow_domain: true  
gf_auth_github_role_attribute_path: example-org/grafana-1  
gf_auth_github_team_ids: 12345678
```
## Retrieve Your GitHub Team ID
Need generate token use page github - https://github.com/settings/tokens

To retrieve your GitHub team ID, you can use the following `curl` command:
```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" https://api.github.com/orgs/ORG_NAME/teams`
```
Replace `YOUR_GITHUB_TOKEN` with your actual GitHub token and `ORG_NAME` with the name of your organization.

## Get Your GitHub Token

To generate or manage your GitHub personal access token, refer to the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

**Classic GitHub Token Usage**
If you are using a classic GitHub token, ensure it has the following scope - `admin:org_hook`


# Example Grafana Provision

Below is an example configuration for provisioning dashboards and datasources in Grafana, demonstrated with Prometheus and Loki.

```yaml
grafana_use_provisioning: true
gf_server_root_url: https://grafana.example.com

grafana_dashboards_provision:
  folders:
    - "exporters"
    - "prometheus"
  dashboards:
    - { folder: exporters, file: "blackbox-exporter-7587_rev3.json" }
    - { folder: exporters, file: "process-exporter-v1.json" }
    - { folder: prometheus, file: "ssl-cert-dash.json" }

grafana_datasources:
  - name: prom-example
    type: prometheus
    access: proxy
    url: "http://localhost:9090"
    isDefault: true
  - name: loki-example
    type: loki
    access: proxy
    url: "https://loki.example.com"
    isDefault: false
    jsonData:
      timeout: 60
      maxLines: 1000
```      

## Example: Install Plugins

To install plugins in Grafana, specify the plugins as a comma-separated list:

```yaml
grafana_plugins: "grafana-clickhouse-datasource,grafana-clock-panel,grafana-piechart-panel"
```

## Delete Datasource
To delete a datasource, set the required variables and use the `grafana-datasource` tag:

Define an array of datasources to remove:
```yaml
grafana_delete_datasources:
  - name: datasource-test
    orgId: 1
```  


# Manually Reload Datasources
To reload datasources manually, use the following curl command:
```bash
curl -u admin:pass -k -X POST https://127.0.0.1:3000/api/admin/provisioning/datasources/reload
```

# Important Options
## grafana_force_port443
**grafana_force_port443**: A boolean variable that allows the Grafana container to bind to port `443`. This option is essential when running Grafana without a reverse proxy (e.g., NGINX or Teleport).
```yaml
grafana_force_port443: true
```