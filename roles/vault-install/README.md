# Ansible Role: HashiCorp Vault (Single Node)

This Ansible role installs and configures HashiCorp Vault in single-node mode. The default configuration uses Raft as the storage backend.

## Requirements

No specific requirements are needed for this role.

## Role Variables

- **`vault_storage_backend_file`**: Set to `true` to switch the storage backend to `file` instead of the default Raft.
- **`vault_domain`**: Set to `selfsign` to enable HTTPS using a self-signed certificate. By default, the role configures Vault to use HTTP.

## Default Configuration

- **Protocol**: HTTP
- **Bind Address**: `127.0.0.1`
- **Port**: `8200`

## Dependencies

- **`ssl-selfsigned-cert`**: This role is used to generate self-signed certificates when `vault_domain` is set to `selfsign`.

## Example Playbook

```yaml
- hosts: vault_example
  become: true
  roles:
    - vault-install
```