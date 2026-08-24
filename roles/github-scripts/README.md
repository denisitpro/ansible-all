# github-scripts

Deploys GitHub App private keys from Vault and renders launcher scripts that obtain a short-lived installation token and trigger `workflow_dispatch` on a repository.

## Prerequisites

- Vault data merged into `vault_dict_users_secret_g2` (via your `vault_extend_g2` wiring). Each PEM is referenced by `gh_pem_vault_group` (the `name` of a `vault_extend_g2` entry) and `gh_pem_vault_key` (one of that entry’s `keys`). The role writes `github_apps_certs_dir/<gh_pem_vault_key>.pem`.
- Target host: `bash`, `openssl`, `curl`, and `python3` available for the generated script.

## Variables

Override in group_vars or host_vars. Main knobs:

| Variable | Purpose |
|----------|---------|
| `github_scripts_dest_dir` | Directory for rendered scripts (default `/opt/scripts`). |
| `github_apps_certs_dir` | Directory for PEM files (default `/opt/github-apps`). |
| `github_scripts_files` | List of dicts: `template`, `dest`, `gh_app_id`, `gh_installation_id`, `gh_repo`, `gh_pem_vault_group`, `gh_pem_vault_key`. |

Example shape (placeholders only):

```yaml
github_scripts_enabled: true
github_scripts_dest_dir: "/opt/scripts"
github_scripts_files:
  - template: "workflow-launch.sh.j2"
    dest: "trigger-example-app.sh"
    gh_app_id: "123456"
    gh_installation_id: "987654321"
    gh_repo: "example-org/example-repo"
    gh_pem_vault_group: "github_apps_keys"
    gh_pem_vault_key: "example_app_dispatcher"
```

Vault extension entry shape (placeholders):

```yaml
vault_extend_g2:
  - name: github_apps_keys
    backend: your_vault_backend
    kv_path: "secret/path/to/github-app-keys"
    keys:
      - example_app_dispatcher
```

## Generated script usage

Each rendered script under `github_scripts_dest_dir` accepts a workflow filename, optional ref, and optional JSON inputs:

```text
/opt/scripts/trigger-example-app.sh build.yml main
/opt/scripts/trigger-example-app.sh deploy.yml v1.0.0 '{"environment":"staging"}'
```

Alternatively set `GH_WORKFLOW`, `GH_REF`, `GH_INPUTS` instead of positional arguments.
