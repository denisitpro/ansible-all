# Ansible Role: HashiCorp Vault (Single Node)

This Ansible role installs and configures HashiCorp Vault in single-node mode. The default configuration uses Raft as the storage backend.

## Requirements

No specific requirements are needed for this role.

## Role Variables

- **`vault_storage_backend_file`**: Set to `true` to switch the storage backend to `file` instead of the default Raft.
- **`vault_domain`**: Set to `selfsign` to enable HTTPS using a self-signed certificate. By default, the role configures Vault to use HTTP.

### Описание переменных для кластера Vault

- **`vault_cluster`**: Список узлов Vault-кластера с описанием их идентификаторов, адресов и портов.
- **`vault_public_api_addr`**: Публичный адрес Vault, доступный клиентам (используется для `api_addr`).
- **`vault_domain`**: Режим TLS, `selfsign` означает генерацию самоподписанных сертификатов.
- **`ca_selfsign`**: Создавать CA-сертификат локально.
- **`ssl_cls_group`**: Имя группы для генерации сертификатов.
- **`vault_resolv_domain`**: Домен для построения DNS-имен.
- **`vault_cluster_name`**: Имя кластера Vault.
- **`ssl_subject_alt_name`**: Список SAN-записей для TLS-сертификата.

## Default Configuration

- **Protocol**: HTTP
- **Bind Address**: `127.0.0.1`
- **Port**: `8200`

## Dependencies

- **`ssl-selfsigned-cert`**: This role is used to generate self-signed certificates when `vault_domain` is set to `selfsign`.

## mTLS Certificate Requirement for Vault Cluster

For Vault cluster deployment, an mTLS certificate issued by another HCP Vault instance (e.g., infrastructure Vault) is required. This certificate is used for secure communication between Vault cluster nodes and for client authentication.

The mTLS certificate must be obtained before deploying the Vault cluster and should be placed in the appropriate location for the role to use during installation.

## Example Playbook

```yaml
- hosts: vault_example
  become: true
  roles:
    - vault-install
```


# Configure cluster
```yaml
vault_cluster:
  nodes:
    - {id: 1, name: "vault-01.example.com", protocol: "https", port_api: "8200"}
    - {id: 2, name: "vault-02.example.com", protocol: "https", port_api: "8200"}
    - {id: 3, name: "vault-03.example.com", protocol: "https", port_api: "8200"}


vault_public_api_addr: https://vault.example.com

vault_domain: "selfsign"
vault_resolv_domain: "example.com"
vault_cluster_name: "vault-cluster"

# enable if you  restore raft snapshot
# ssl_cls_group: vault_cluster_group
# ssl_ca_init_host: "{{ groups[ssl_cls_group][0] }}"


ssl_subject_alt_name:
  - "IP:127.0.0.1"
  - "DNS:vault.example.com"
  - "DNS:vault-01.example.com"
  - "DNS:vault-02.example.com"
  - "DNS:vault-03.example.com"
```