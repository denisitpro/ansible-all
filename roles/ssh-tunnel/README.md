# SSH Tunnel Role

Ansible role for creating and managing SSH tunnels as systemd services.

## Features

- Create system user for SSH tunnels
- Generate ed25519 SSH keys
- Automatically create users on remote hosts
- Configure authorized_keys with security restrictions
- Create systemd services for each tunnel
- Monitor tunnel status

## Variables

### Required Variables

- `ssh_tunnels`: List of tunnel configurations

### Optional Variables

- `ssh_tunnel_user`: Username for tunnels (default: `tunnel-<hostname>` where hostname is the server name)
- `ssh_remote_user`: User for connecting to remote hosts (default: `ansible_user`)

### Configuration Example

```yaml
# ssh_tunnel_user will be automatically set as tunnel-<hostname>
# e.g.: tunnel-srv1, tunnel-proxy01, etc.
ssh_remote_user: root  # user for connecting to remote hosts
ssh_tunnels:
  - local_port: 8080
    remote_host: web-server.example.com
    remote_port: 80
  - local_port: 8443
    remote_host: web-server.example.com
    remote_port: 443
  - local_port: 5432
    remote_host: db-server.example.com
    remote_port: 5432
    server_alive_interval: 60
```

### Override Username

If you need to use a specific username:

```yaml
ssh_tunnel_user: my-custom-tunnel-user
ssh_tunnels:
  - local_port: 3306
    remote_host: mysql.internal
    remote_port: 3306
```

## Role Structure

```
ssh-tunnel/
├── defaults/
│   └── main.yml          # Default variables
├── handlers/
│   └── main.yml          # Handlers for service reloads
├── tasks/
│   ├── main.yml          # Main task file
│   ├── 05-preflight.yml  # Preflight checks
│   ├── 10-local-user.yml # Local user creation
│   ├── 15-remote-user.yml # Remote user creation
│   ├── 20-configure.yml  # Tunnel configuration
│   └── 25-cleanup.yml    # Cleanup old tunnels
└── templates/
    ├── ssh-tunnel.service.j2 # systemd service template
    └── ssh_config.j2         # SSH config template
```

## Usage

```yaml
- hosts: tunnel-servers
  roles:
    - ssh-tunnel
  vars:
    # ssh_tunnel_user will automatically be tunnel-<hostname>
    ssh_remote_user: root
    ssh_tunnels:
      - local_port: 3306
        remote_host: mysql.internal
        remote_port: 3306
```

## Tags

- `ssh-tunnel`: All role tasks
- `preflight`: Preflight checks
- `setup`: User creation (local-user + remote-user)
- `tunnels`: Only tunnel configuration
- `cleanup`: Cleanup old tunnels

## State Management

```yaml
# Tunnel service management
ssh_tunnel_state: started    # started, stopped, restarted  
ssh_tunnel_enabled: true     # autostart on boot
ssh_tunnel_cleanup_old: true # remove old unused tunnels
```

## Usage Examples

### User creation only
```bash
ansible-playbook playbook.yml --tags setup
```

### Tunnel configuration only
```bash
ansible-playbook playbook.yml --tags tunnels
```

### Stop all tunnels
```yaml
- hosts: tunnel-servers
  roles:
    - ssh-tunnel
  vars:
    ssh_tunnel_state: stopped
```

## Security

- Creates system user without home directory and with nologin shell
- SSH keys are generated with ed25519 type
- Remote hosts are configured with authorized_keys restrictions:
  - `command="echo 'Port forwarding only';exit"`
  - `no-agent-forwarding`
  - `no-pty`
  - `no-X11-forwarding`

## Requirements

- Ansible 2.9+
- systemd on target hosts
- OpenSSH client on controller and target hosts
- sudo privileges on all hosts (local and remote)
- SSH access from controller to remote hosts (specified in `ssh_tunnels.remote_host`)

## Connection Approach

The role uses direct SSH connection from Ansible controller to remote hosts:
- All operations on remote hosts are performed via SSH from the controller
- Does not require remote hosts to be in Ansible inventory
- Uses `ssh_remote_user` for connecting to remote hosts (defaults to `ansible_user`)
- Pre-checks availability of all remote hosts

## Monitoring

After applying the role, you can check tunnel status:

```bash
# Status of all SSH tunnels
systemctl status ssh-tunnel-*

# Specific tunnel
systemctl status ssh-tunnel-8080

# Tunnel logs
journalctl -u ssh-tunnel-8080 -f
```
