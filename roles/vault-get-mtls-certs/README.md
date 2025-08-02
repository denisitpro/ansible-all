# Vault Get MTLS Certificates Role

This Ansible role retrieves mTLS certificates from HCP Vault using Teleport authentication and stores them in Vault KV storage.

## Overview

The role performs the following operations:
1. Authenticates to HCP Vault via Teleport
2. Reads CA certificates from Vault PKI engines
3. Issues new mTLS certificates using specified PKI roles
4. Stores certificates in Vault KV storage with proper organization
5. Cleans up temporary local files

## Prerequisites

### Required Software
- **Vault CLI** - Must be installed and accessible
- **Teleport CLI (tsh)** - For authentication
- **jq** - For JSON processing
- **curl** - For API requests

### Required Permissions
- Vault token with `update` and `write` permissions for certificate operations
- Access to Teleport proxy and Vault application

## Authentication Setup

Before running this role, you must authenticate to Teleport and set up Vault access:

```bash
# Login to Teleport
tsh login --proxy=tp.example.com --auth=github

# Login to Vault application
tsh app login vault-example

# Set environment variables
export VAULT_CLIENT_CERT="$(tsh app config --format=cert vault-example)"
export VAULT_CLIENT_KEY="$(tsh app config --format=key vault-example)"
export VAULT_ADDR=https://vault-example.tp.example.com
export VAULT_TOKEN=your_vault_token
export VAULT_ACCESS_TOKEN=your_vault_token
```

## Required Variables

### Core Configuration
- `vault_url_teleport` - HCP Vault URL accessible via Teleport (e.g., `https://vault.tp.example.com`)
- `teleport_vault_app_name` - Teleport application name for Vault (e.g., `vault-example`)
- `vault_token` - Vault authentication token (can be set via `VAULT_TOKEN` environment variable)

### Certificate Configuration
- `mtls_certs_request_list` - List of certificate requests with the following structure:
  ```yaml
  mtls_certs_request_list:
    - cert_pki_path: "pki/auth-engine-ca-01"      # PKI engine path in Vault
      cert_role_name: "auth-engine-ca-01-any"     # PKI role name
      cert_common_name: "example-test-01.example.com"  # Certificate common name
      cert_ttl: "1h"                              # Certificate TTL
  ```

### Storage Configuration
- `vault_mtls_kv_mount` - KV mount point in Vault (default: `kv`)
- `mtls_path_name` - Namespace prefix for certificate storage (default: `mtls`)
- `local_cert_dir` - Temporary directory for certificate processing (default: `/tmp`)

### Optional Variables
- `mtls_certs_common_push_force` - Force certificate re-issuance (default: `false`)
- `cert_bundle_file` - Temporary bundle file name (default: `cert_bundle.json`)
- `cert_file` - Temporary certificate file name (default: `cert.pem`)
- `key_file` - Temporary private key file name (default: `key.pem`)
- `ca_file` - Temporary CA file name (default: `ca.pem`)

## Usage Examples

### Basic Usage
```yaml
- name: Get mTLS certificates from Vault
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    vault_url_teleport: "https://vault.tp.example.com"
    teleport_vault_app_name: "vault-c1-infra"
    mtls_certs_request_list:
      - cert_pki_path: "pki/auth-engine-ca-01"
        cert_role_name: "auth-engine-ca-01-any"
        cert_common_name: "api.example.com"
        cert_ttl: "24h"
  roles:
    - vault-get-mtls-certs
```

### Multiple Certificates
```yaml
- name: Get multiple mTLS certificates
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    vault_url_teleport: "https://vault.tp.example.com"
    teleport_vault_app_name: "vault-c1-infra"
    mtls_certs_request_list:
      - cert_pki_path: "pki/auth-engine-ca-01"
        cert_role_name: "auth-engine-ca-01-any"
        cert_common_name: "api.example.com"
        cert_ttl: "24h"
      - cert_pki_path: "pki/auth-engine-ca-01"
        cert_role_name: "auth-engine-ca-01-any"
        cert_common_name: "web.example.com"
        cert_ttl: "24h"
      - cert_pki_path: "pki/internal-ca"
        cert_role_name: "internal-services"
        cert_common_name: "internal.example.com"
        cert_ttl: "168h"
  roles:
    - vault-get-mtls-certs
```

### Custom Storage Configuration
```yaml
- name: Get certificates with custom storage
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    vault_url_teleport: "https://vault.tp.example.com"
    teleport_vault_app_name: "vault-c1-infra"
    vault_mtls_kv_mount: "secrets"
    mtls_path_name: "certificates"
    local_cert_dir: "/var/tmp"
    mtls_certs_request_list:
      - cert_pki_path: "pki/auth-engine-ca-01"
        cert_role_name: "auth-engine-ca-01-any"
        cert_common_name: "api.example.com"
        cert_ttl: "24h"
  roles:
    - vault-get-mtls-certs
```

## Certificate Storage Structure

Certificates are stored in Vault KV with the following structure:
```
{{ vault_mtls_kv_mount }}/{{ mtls_path_name }}/{{ cert_pki_path }}/{{ cert_common_name }}/{{ cert_role_name }}/
├── mtls_cert      # Certificate file
├── mtls_key       # Private key file
└── mtls_issuing_ca # Issuing CA certificate
```

## Tags

The role supports the following tags for selective execution:
- `vault` - All Vault-related tasks
- `mtls-hcp` - All mTLS HCP tasks
- `mtls-ca` - CA certificate reading tasks
- `mtls-certs` - Certificate issuance tasks

## Error Handling

The role includes comprehensive error handling:
- Validates Teleport authentication before proceeding
- Checks for required environment variables
- Verifies certificate paths and permissions
- Handles API failures gracefully
- Cleans up temporary files even on failure

## Security Considerations

- Temporary certificate files are automatically cleaned up after processing
- Certificates are stored securely in Vault KV with proper access controls
- Teleport mTLS authentication provides secure access to HCP Vault
- No sensitive data is logged or displayed in debug output


