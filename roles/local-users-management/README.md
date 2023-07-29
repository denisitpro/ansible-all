# Description
Linux local user management. SSH public key - required

## Array user for create
```commandline
local_users:
  - {name: user1, group: "test-group" ,public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AA1bCmk user1@local" }
  - {name: user2, public_key: "ssh-ed25519 AAAAC3NzaC1 user2@local" }
```

## Array for delete
```commandline
local_users:
  - {name: user1 }
  - {name: user2}
```