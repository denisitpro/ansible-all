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
```

## Array for delete
```commandline
local_users:
  - {name: user1 }
  - {name: user2}
```