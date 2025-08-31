# Teleport Management Role

## Description

This Ansible role is responsible for generating a structured array of key-value (`kv`) pairs that define user access levels within Teleport. These pairs serve as the foundation for assigning permissions, regulating SSH and application access, and enforcing session time-to-live (`TTL`) policies.

## Requirements

To use this role, you must:
- Be logged into the Teleport console.
- Have permissions to manage roles and users.

## Features

- **Role-based access control (RBAC):** Dynamically assigns access permissions based on predefined roles.
- **Application Access Control:** Uses access level definitions to manage application permissions.
- **SSH Access Control:** Defines SSH access based on specified levels.
- **Session Management:** Configures session duration limits to enforce security policies.

## How It Works

1. The role generates an array of `kv` pairs that encapsulate role definitions.
2. These definitions establish structured access control for both applications and SSH.
3. The system applies these permissions within a Teleport-managed infrastructure, ensuring access governance.

## Requirements

- Ansible
- Teleport
- Configured SSH environment

## Notes

- `max_session_ttl` specifies the maximum duration a session remains active.
- `logins` determines the users permitted to access specific systems.
- `app_acl_level` and `ssh_acl_level` define hierarchical access rights for applications and SSH.
- if `ssh_acl_level` not send - default `ssh_acl_level: 900`

## Example publish app and SSH access
```yaml
```commandline
teleport_roles:
  - name: "company-sso-200"
    logins: ["none"]
    app_acl_level: [200]
    max_session_ttl: "12h0m0s"
  - name: "company-sso-300"
    logins: ["ubuntu"]
    app_acl_level: [300]
    ssh_acl_level: [300]
    # ssh_acl_level: [300, 400]
    max_session_ttl: "12h0m0s"
```