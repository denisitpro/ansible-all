# Global description
A set of playbooks and roles focused on solving immediately applied problems

# Use role hasicrop vault

for use hashicorp vault role requirements

- Install and configure hasicrop vault
- Vault enable LDAP access
- Vault configure policy ACL for ldap group
- Ldap account use role has access to a secret

example vars
```vault:
  secret:
    - {kv: "dev", appname: clickhouse, server: "ch-001", key_name: "default" }
    - {kv: "dev", appname: clickhouse, server: "ch-001", key_name: "user1" }``