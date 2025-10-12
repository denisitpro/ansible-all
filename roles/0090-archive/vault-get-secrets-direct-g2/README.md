# Vault Get Secrets Direct G2

This role retrieves secrets from HashiCorp Vault using direct HTTP API calls with a flexible secret merging system.

## Overview

The role implements a three-tier secret management approach that allows combining secrets from different sources:
- Global inventory secrets
- Environment-specific secrets  
- Role-specific overrides

## Secret Merging Logic

The role uses a sophisticated merging strategy to combine secrets from multiple sources:

```yaml
vault_sum_g2: "{{ (vault_global_g2 | default([])) + (vault_extend_g2 | default([])) + (vault_g2_role_override | default([])) }}"
```

### Secret Sources

1. **`vault_global_g2`** - Global secrets defined in inventory defaults
   - Applied to all hosts across all environments
   - Defined in `group_vars/all/secrets.yml`

2. **`vault_extend_g2`** - Environment-specific secrets
   - Applied to hosts in specific inventory groups
   - Defined in `group_vars/<inventory_group>/secrets.yml`

3. **`vault_g2_role_override`** - Role-specific secret overrides
   - Applied when role needs specific secrets
   - Use sparingly to avoid complexity

## Configuration Examples

### Global Secrets (group_vars/all/secrets.yml)
```yaml
vault_global_g2:
  - name: consul_encrypt_key
    backend: kv-example
    kv_path: "consul/consul_encrypt_key"
    keys:
      - value
  - name: elastic_token
    backend: kv-example
    kv_path: "sec/elastic_token"
    keys:
      - value
```

### Environment-Specific Secrets (group_vars/vm_mining_g2_c3_infra/secrets.yml)
```yaml
vault_extend_g2:
  - name: prom_stack_mtls_root_ca
    backend: kv-example
    secret_type: angie_mtls
    kv_path: "mtls/pki/ca-root"
    keys:
      - ca_root_cert
  - name: teleport_join_token
    backend: kv-example
    kv_path: "teleport/teleport_join_token"
    keys:
      - value
```

## Secret Structure

Each secret entry must contain:
- `name`: Unique identifier for the secret
- `backend`: Vault KV backend name
- `kv_path`: Path to the secret in Vault
- `keys`: List of keys to retrieve from the secret

## Output Variables

The role creates two main output variables:

- `vault_list_users_secret_g2`: List of secrets with key-value pairs
- `vault_dict_users_secret_g2`: Dictionary of secrets indexed by name

## Important Notes

⚠️ **Complexity Warning**: This merging approach is sophisticated and should be used judiciously. Consider the following:

- **Don't overuse**: Three variables are already quite complex for array operations
- **Debugging complexity**: Merging logic can be difficult to debug and troubleshoot

## Usage

Include this role in your playbook:

```yaml
- name: Get secrets from Vault
  include_role:
    name: vault-get-secrets-direct-g2
```

## Dependencies

- Vault server accessible via HTTP/HTTPS
- Valid Vault token in `vault_token` variable
- Vault URL configured in `vault_url_direct` (defaults to `https://vault.example.com`)

## Tags

- `always`: Role runs on every execution
- `vault`: Specific tag for Vault-related operations
