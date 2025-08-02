
# Ansible Role: HCP Vault Secrets Retrieval

This role securely retrieves secrets from HashiCorp Vault using native Ansible modules. It is lightweight, requiring no external dependencies.

## Features

- Securely fetch secrets from HashiCorp Vault (HCP Vault).
- Leverages native Ansible modules for seamless integration.
- Simple and reliable setup with no external dependencies.

## Prerequisites

1. **Environment Variable**:  
   Ensure the `VAULT_ACCESS_TOKEN` environment variable is set with a valid Vault token:  
   ```bash
   export VAULT_ACCESS_TOKEN=your-token
   ```

2. **Vault Server Address**:  
   Define the Vault server address using the `vault_url_direct` variable. It is recommended to configure this in `group_vars/all` for consistency.

## Role Variables

| Variable           | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `vault.secret`     | Array of secrets to retrieve, specifying the KV path and key.              |
| `vault_url_direct` | URL of the Vault server.                                                   |

## Example Configuration

### Inventory Configuration

Define the secrets in your inventory file. Secrets should already exist in HCP Vault at the specified paths.

```yaml
vault_url_direct: https://vault.example.com
vault:
  secret:
    - {kv: "example-kv", path: "dockerhub", key_name: "example_access_username"}
    - {kv: "example-kv", path: "dockerhub", key_name: "example_access_token"}

docker_registry_username: "{{ vault_dict_users_secret.example_access_username }}"
docker_registry_password: "{{ vault_dict_users_secret.example_access_token }}"
```

### Environment Setup

Before running the playbook, ensure the Vault token is exported to the environment:

```bash
export VAULT_ACCESS_TOKEN=your-token
```

### Usage Example

Run the playbook with the `vault-get` tag to retrieve secrets:

```bash
ansible-playbook -i env/example vault-demo.yml -t vault-get
```

This setup will fetch secrets and allow their use in subsequent Ansible tasks.
