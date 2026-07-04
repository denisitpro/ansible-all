# Infisical Get Secrets Direct G1

This role retrieves secrets from Infisical using direct HTTP API calls (Universal Auth machine identity) with a flexible secret merging system.

## Overview

The role implements a three-tier secret management approach that allows combining secrets from different sources:
- Global inventory secrets
- Environment-specific secrets
- Role-specific overrides

## Secret Merging Logic

The role uses a sophisticated merging strategy to combine secrets from multiple sources:

```yaml
infisical_sum_g1: "{{ (infisical_global_g1 | default([])) + (infisical_extend_g1 | default([])) + (infisical_g1_role_override | default([])) }}"
```

### Secret Sources

1. **`infisical_global_g1`** - Global secrets defined in inventory defaults
   - Applied to all hosts across all environments
   - Defined in `group_vars/all/secrets.yml`

2. **`infisical_extend_g1`** - Environment-specific secrets
   - Applied to hosts in specific inventory groups
   - Defined in `group_vars/<inventory_group>/secrets.yml`

3. **`infisical_g1_role_override`** - Role-specific secret overrides
   - Applied when role needs specific secrets
   - Use sparingly to avoid complexity

## Configuration Examples

### Global Secrets (group_vars/all/secrets.yml)
```yaml
infisical_global_g1:
  - name: consul_encrypt_key
    secret_path: "/consul"
    secret_name: "CONSUL_ENCRYPT_KEY"
  - name: elastic_token
    secret_path: "/elastic"
    secret_name: "ELASTIC_TOKEN"
```

### Environment-Specific Secrets (group_vars/vm_mining_g1_c3_infra/secrets.yml)
```yaml
infisical_extend_g1:
  - name: prom_stack_mtls_root_ca
    secret_path: "/mtls/pki"
    secret_name: "CA_ROOT_CERT"
  - name: teleport_join_token
    secret_path: "/teleport"
    secret_name: "TELEPORT_JOIN_TOKEN"
```

## Secret Structure

Each secret entry must contain:
- `name`: Unique identifier for the output secret (logical output key)
- `secret_path`: Infisical folder path where the secret lives (e.g. `/consul`)
- `secret_name`: The actual secret name/key in Infisical

## Output Variables

The role creates two main output variables:

- `infisical_list_users_secret_g1`: List of secrets with key-value pairs
- `infisical_dict_users_secret_g1`: Dictionary of secrets indexed by name

## Important Notes

⚠️ **Complexity Warning**: This merging approach is sophisticated and should be used judiciously. Consider the following:

- **Don't overuse**: Three variables are already quite complex for array operations
- **Debugging complexity**: Merging logic can be difficult to debug and troubleshoot

## Usage

Include this role in your playbook:

```yaml
- name: Get secrets from Infisical
  include_role:
    name: infisical-get-secrets-direct-g1
```

## Dependencies

- Infisical project with a Machine Identity configured for Universal Auth
- `INFISICAL_CLIENT_ID` and `INFISICAL_CLIENT_SECRET` environment variables set on the control node
- `infisical_project_id` set (defaults to empty string, must be overridden)
- Infisical API accessible via HTTP/HTTPS, configured in `infisical_api_url` (defaults to `https://app.infisical.com`, use `https://eu.infisical.com` for the EU region)

## Tags

- `always`: Role runs on every execution
- `infisical`: Specific tag for Infisical-related operations
- `infisical-check`: Tag for the Universal Auth login check (doubles as the reachability check)
