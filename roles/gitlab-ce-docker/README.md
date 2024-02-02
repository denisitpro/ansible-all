# Description
Role install gitlab-ce use docker

# Example config
example config for deploy gitlab to internal networks

* Role support self signed certificate, vars disable nginx status, prometheus monitoring, alert manager and bind all service to specific address
* Vars disabled lets encrypt - usage internal networks
* example configure backup to AWS S3
* add example google SSO - docs https://docs.gitlab.com/ee/integration/google.html
* add example github SSO - docs https://docs.gitlab.com/ee/integration/github.html

example vars
```commandline
gitlab_external_url: "https://gitlab.example.com"
gitlab_ssh_host: "gitlab.example.com"
gitlab_support_ssl: true # need for support SSL
gitlab_bind_addr: "{{ ansible_default_ipv4.address}}"
gitlab_ssh_port: 2222 # port for clone repo gitlab use ssh
gitlab_ssh_listen_addr: "{{ ansible_default_ipv4.address}}:{{gitlab_ssh_port}}"


gitlab_settings:
   - external_url '{{gitlab_external_url}}'
   - gitlab_rails['gitlab_ssh_host'] = '{{gitlab_ssh_host}}'
   - gitlab_sshd['enable'] = true
   - gitlab_sshd['listen_address'] = '{{gitlab_ssh_listen_addr}}'
   - gitlab_rails['gitlab_shell_ssh_port'] = {{gitlab_ssh_port}}
   - letsencrypt['enable'] = false
   - nginx['enable'] = true
   - nginx['redirect_http_to_https'] = true
   - nginx['client_max_body_size'] = '100m'
   - nginx['listen_https'] = true
   - nginx['listen_addresses'] = ['127.0.0.1', '{{gitlab_bind_addr}}']
   - nginx['status'] = {"enable" => false,}
   - nginx['ssl_certificate'] = "{{gitlab_ssl_path}}/{{gitlab_ssl_cert_name}}"
   - nginx['ssl_certificate_key'] = "{{gitlab_ssl_path}}/{{gitlab_ssl_key_name}}"
   - prometheus_monitoring['enable'] = false
   - alertmanager['enable'] = false
   - gitlab_rails['backup_upload_connection'] = {'provider' => 'AWS','region' => 'eu-central-1','aws_access_key_id' => 'exmple_access_key','aws_secret_access_key' => 'example_secret_key }}'}
   - gitlab_rails['backup_upload_remote_directory'] = 'giatlab-backup-example'
   - gitlab_rails['backup_encryption'] = 'AES256'
   - 'gitlab_rails[''omniauth_providers''] = [{name: "google_oauth2", app_id: "app_id", app_secret: "secret", args: { access_type: "offline", approval_prompt: "" }}]'
#   - 'gitlab_rails[''omniauth_providers''] = [{ name: "github", app_id: "app_id",app_secret: "secret",args: { scope: "user:email"} }]'

   ```
