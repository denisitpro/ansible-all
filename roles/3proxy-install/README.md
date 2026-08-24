# 3proxy Role

This role installs and configures 3proxy - a lightweight multi-protocol proxy server that supports HTTP, HTTPS, and SOCKS5 protocols.

## Features

- Installs 3proxy from source (latest version)
- Configures HTTP proxy on port 3128 (default)
- Configures SOCKS5 proxy on port 1080 (default)
- Systemd service management
- Firewall rules configuration
- Logging and rotation
- Optional authentication support

## Requirements

- Ubuntu/Debian-based system
- root or sudo access
- Internet connectivity for building from source

## Role Variables

### Default Variables

```yaml
proxy_http_port: 3128              # HTTP proxy port
proxy_https_port: 3129             # HTTPS proxy port
proxy_socks5_port: 1080            # SOCKS5 proxy port
enable_http_proxy: true            # Enable HTTP proxy
enable_socks5_proxy: true          # Enable SOCKS5 proxy
proxy_http_auth_required: false    # Require HTTP auth
proxy_socks5_auth_required: false  # Require SOCKS5 auth
proxy_users: "test:test"           # Default user:password
dns_server: "8.8.8.8"              # Primary DNS
secondary_dns: "8.8.4.4"           # Secondary DNS
```

## Usage

### Basic Usage (both HTTP and SOCKS5 without authentication)

```yaml
- hosts: sproxy_servers
  roles:
    - 3proxy-install
    - 3proxy-configure
```

### With Custom Ports

```yaml
- hosts: sproxy_servers
  vars:
    proxy_http_port: 8080
    proxy_socks5_port: 9090
  roles:
    - 3proxy-install
    - 3proxy-configure
```

### With Authentication

```yaml
- hosts: sproxy_servers
  vars:
    proxy_http_auth_required: true
    proxy_socks5_auth_required: true
    proxy_users: "user1:pass1"
  roles:
    - 3proxy-install
    - 3proxy-configure
```

### Only HTTP Proxy

```yaml
- hosts: sproxy_servers
  vars:
    enable_socks5_proxy: false
  roles:
    - 3proxy-install
    - 3proxy-configure
```

## Tags

- `3proxy` - All 3proxy tasks
- `3proxy-install` - Installation tasks only
- `3proxy-configure` - Configuration tasks only
- `3proxy-firewall` - Firewall configuration only
- `3proxy-health` - Health check tasks

## Testing the Proxy

### Test SOCKS5 proxy
```bash
curl -x socks5://localhost:1080 https://example.com
```

### Test HTTP proxy
```bash
curl -x http://localhost:3128 https://example.com
```

### Check service status
```bash
systemctl status 3proxy
journalctl -u 3proxy -f
```

## Files

- `/opt/3proxy/3proxy` - Main binary
- `/etc/3proxy/3proxy.cfg` - Configuration file
- `/var/log/3proxy/` - Log directory
- `/etc/systemd/system/3proxy.service` - Systemd service file

## Performance Tuning

Default maxconn: 1000 connections per port
Default maxconnip: 50 connections per IP

Adjust in group_vars or playbook as needed.

## Security Considerations

- The role configures firewall rules for proxy ports
- Authentication is optional (disabled by default for testing)
- Consider enabling authentication in production
- Monitor logs at `/var/log/3proxy/3proxy.log`

## Troubleshooting

### Check if 3proxy is listening
```bash
netstat -tlnp | grep 3proxy
```

### View logs
```bash
tail -f /var/log/3proxy/3proxy.log
```

### Reload configuration
```bash
systemctl reload 3proxy
# or
systemctl restart 3proxy
```

## Author

DevOps Team - Managed by Ansible
