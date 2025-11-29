# AmneziaWG Install Role

This role installs and configures AmneziaWG server and clients.

## Configuration

Define clients in your inventory or group_vars:

```yaml
amneziawg_clients:
  - name: client1
    ip: 10.9.9.2/32
  - name: client2
    ip: 10.9.9.3/32
```

## Features

- Installs AmneziaWG module and tools.
- Generates server configuration with random obfuscation parameters.
- Generates client configurations and QR codes.
- Idempotent configuration management.