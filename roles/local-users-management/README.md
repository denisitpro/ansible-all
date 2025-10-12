# Description
Linux local user management. SSH public key - required

## Array user for create
```commandline
local_users:
  - name: user01
    group: "supr-group"
    public_keys:
      - "ssh-ed25519 aaa user1@local"
  - name: user02
    public_keys:
      - "ssh-ed25519 bbb user2@local"
      - "ssh-ed25519 bbb reserve@key"
  - name: user03
    user_base_access_only: true
    public_keys:
      - "ssh-ed25519 ccc user3@local"
```

## Parameters
- `name` - username (required)
- `group` - user group, defaults to username if not specified
- `public_keys` - array of SSH public keys (required)
- `user_base_access_only` - if set to `true`, user will not get sudo privileges (optional, default: false)

## Array for delete
```commandline
local_users_delete:
  - name: user1
    public_keys:  # optional, for SSH key conflict checking
      - "ssh-ed25519 aaa user1@local"
  - name: user2
```

## SSH Key Management Features

When deleting users, the role automatically removes their SSH keys from all other users' `authorized_keys` files:

### Key Matching Logic
- **Smart Key Matching**: Compares only the public key part (algorithm + key), ignoring comments
- **Example**: If you want to remove `ssh-ed25519 AAAAC3...ha06V user@example.com`, it will also match and remove `ssh-ed25519 AAAAC3...ha06V different-comment@domain.com`
- **Security**: Prevents users from keeping access by just changing the comment part of their SSH key

### Default Behavior (Automatic Key Removal)
- **Automatically removes** SSH keys of deleted users from other users' `authorized_keys` files
- **Creates backups** of modified `authorized_keys` files with timestamp
- **Preserves other keys** in the `authorized_keys` files unchanged
- **Includes root user** checking and cleaning `/root/.ssh/authorized_keys`
- **POSIX compatible** shell commands for maximum compatibility
- **Shows detailed information** about removed keys

### Example Scenario
```
Users: Alice (has her own keys), Bob (added his key to Alice's file)
Bob's key in Alice's file: ssh-ed25519 AAAAC3...ha06V bob@company.com
Someone changed it to: ssh-ed25519 AAAAC3...ha06V different@email.com

When Bob is deleted:
1. Both versions of Bob's key are removed from Alice's authorized_keys
2. Alice's own keys remain intact in her authorized_keys
3. Bob's entire ~/.ssh directory is removed
4. Backup files are created: ~/.ssh/authorized_keys.backup.YYYYMMDD_HHMMSS
```

### Usage
```yaml
local_users_delete:
  - name: bob
    public_keys:  # REQUIRED: specify keys to search and remove
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGz4c4j9DeF406V vasy@examole.com"
  - name: alice  
    public_keys:
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... alice@company.com"
```