# Certbot DNS Cloudflare Role

## Description 
Role for issuing SSL certificates using Certbot with Cloudflare DNS challenge validation. Supports multiple zones with separate certificates for each zone.

## Requirements
- Docker and docker-compose installed on target hosts
- Cloudflare API token with DNS edit permissions
- Valid email address for Let's Encrypt registration

## Variables

### Required Variables
- **certbot_email**: Email address for Let's Encrypt registration (e.g., `devops@example.com`)
- **certbot_domains**: List of zone configurations with domains for certificate generation
- **certbot_cf_access_token**: Cloudflare API token with DNS edit permissions

### Domain Configuration
The role now supports zone-based certificate generation. Each zone will get a separate certificate:

```yaml
certbot_domains:
  - zone: example.com
    domains:
      - domain1.example.com
      - "*.domain1.example.com"
  - zone: example.org
    domains:
      - domain2.example.org
      - "*.domain2.example.org"
```

**Important**: All domains within a single zone configuration must belong to the same root domain. You cannot mix domains from different zones (e.g., `one.example.com` and `two.example.io`) in the same zone configuration.

### Optional Variables
- **certbot_force_renewal**: Force certificate renewal even if not expired (default: `false`)
- **certbot_system_post_hook_command**: Command to run on host system after successful certificate renewal (default: `""`)
- **certbot_system_pre_hook_command**: Command to run on host system before certificate renewal (default: `""`)
- **certbot_renewal_hour**: Hour of day for automatic renewal (default: `3`)
- **certbot_renewal_minute**: Minute of hour for automatic renewal (default: `30`)

### Deprecated Variables (use system hooks instead)
- **certbot_post_hook_command**: Command to run inside container after renewal - use `certbot_system_post_hook_command` instead
- **certbot_pre_hook_command**: Command to run inside container before renewal - use `certbot_system_pre_hook_command` instead

### Advanced Variables
- **certbot_image**: Docker image for certbot (default: `certbot/dns-cloudflare`)
- **certbot_version**: Docker image version (default: `v5.0.0`)
- **certbot_path**: Path for certbot data storage (default: `/opt/certbot`)
- **certbot_compose_path**: Path for docker-compose files (default: `/opt/docker/certbot`)

## System Hooks vs Container Hooks

This role now supports **system hooks** that execute commands on the host system instead of inside the Docker container. This is crucial for operations that need to interact with host services (like reloading nginx, restarting services, etc.).

### System Hooks
- **certbot_system_pre_hook_command**: Executed on host before certificate operations
- **certbot_system_post_hook_command**: Executed on host after successful certificate operations
- Works with both manual runs and automatic cron renewals
- Can interact with host services and files

## Tags
- `certbot`: Run all certbot tasks
- `certbot-run`: Run certificate generation
- `certbot-renewal`: Setup automatic renewal cron job

## Features
- ✅ Multiple zone support with separate certificates per zone
- ✅ Multiple domain support including wildcards within each zone
- ✅ Automatic certificate renewal via cron for all zones
- ✅ System-level pre and post hooks (executed on host)
- ✅ Force renewal option
- ✅ Secure credential storage
- ✅ Input validation
- ✅ Works with both manual runs and cron jobs
- ✅ Prevents cross-zone domain mixing for certificate generation

## Example Usage

### Basic Configuration
```yaml
certbot_email: devops@example.com
certbot_domains:
  - zone: example.com
    domains:
      - app.example.com
      - api.example.com
      - "*.app.example.com"
  - zone: example.org
    domains:
      - site.example.org
      - "*.site.example.org"
certbot_cf_access_token: "your_cloudflare_api_token"
```

### With System Hooks for Nginx Reload
```yaml
certbot_email: devops@example.com
certbot_domains:
  - zone: example.com
    domains:
      - www.example.com
      - "*.example.com"
certbot_cf_access_token: "your_cloudflare_api_token"
certbot_system_post_hook_command: "systemctl reload nginx"
certbot_renewal_cron: true
```

### Force Renewal with Multiple Zones
```yaml
certbot_email: devops@example.com
certbot_domains:
  - zone: example.com
    domains:
      - main.example.com
      - "*.main.example.com"
  - zone: testdomain.org
    domains:
      - test.testdomain.org
      - api.testdomain.org
certbot_cf_access_token: "your_cloudflare_api_token"
certbot_force_renewal: true
```

## Certificate Management

Each zone will generate a separate certificate. For example, with the configuration above:
- `example.com` zone will create a certificate in `/opt/certbot/data/live/main.example.com/`
- `testdomain.org` zone will create a certificate in `/opt/certbot/data/live/test.testdomain.org/`

The certificate files for each domain will be available at:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key
- `cert.pem` - Certificate only
- `chain.pem` - Intermediate certificates only