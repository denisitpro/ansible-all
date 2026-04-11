# Nginx S3 Gateway Role

Ansible role for deploying nginx-s3-gateway to provide HTTP access to private AWS S3 buckets with AWS Signature v4 authentication.

## Overview

This role deploys the official nginxinc/nginx-s3-gateway container with NJS modules that act as a gateway to private S3 buckets. It automatically signs requests using AWS Signature v4, allowing secure access to S3 objects through a standard HTTP interface with optional directory listing.

## Features

- **AWS Signature v4 authentication** - Automatic request signing for S3 API
- **Private bucket support** - Works with fully private S3 buckets
- **Directory listing** - Browse S3 bucket contents like a file server
- **Caching** - Optional proxy caching for improved performance
- **Docker-based deployment** - Runs in container for easy management
- **Vault integration** - S3 credentials stored securely in Vault

## Requirements

- Docker and docker-compose installed on target host
- Official nginxinc/nginx-s3-gateway image
- AWS S3 bucket with IAM credentials
- Vault with S3 credentials stored

## Role Variables

### Required Variables

```yaml
nginx_s3_bucket_name: "my-bucket"
nginx_s3_access_key_id: "AKIAIOSFODNN7EXAMPLE"
nginx_s3_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
nginx_s3_region: "us-east-1"
nginx_s3_server: "s3.us-east-1.amazonaws.com"
```

### Optional Variables

See [`defaults/main.yml`](defaults/main.yml) for full list of configurable options.

Key options:
- `nginx_s3_cache_enabled: true` - Enable proxy caching
- `nginx_s3_debug: false` - Enable debug logging
- `nginx_s3_allow_directory_list: true` - Enable directory listing
- `nginx_s3_ssl_enabled: false` - Enable HTTPS

## Dependencies

- `vault-get-secrets-teleport-g3` - For retrieving S3 credentials from Vault

## Example Playbook

```yaml
---
- hosts: s3_gateway_servers
  become: true
  roles:
    - vault-get-secrets-teleport-g3
    - nginx-s3-gateway
```

## Example Group Variables

```yaml
# group_vars/my_server/nginx-s3.yml
nginx_s3_bucket_name: "{{ vault_dict_users_secret_g2.aws_qa_artifcats_ro.bucket }}"
nginx_s3_access_key_id: "{{ vault_dict_users_secret_g2.aws_qa_artifcats_ro.access_key_id }}"
nginx_s3_secret_key: "{{ vault_dict_users_secret_g2.aws_qa_artifcats_ro.secret_access_key }}"
nginx_s3_region: "{{ vault_dict_users_secret_g2.aws_qa_artifcats_ro.region }}"
nginx_s3_server: "s3.{{ vault_dict_users_secret_g2.aws_qa_artifcats_ro.region }}.amazonaws.com"
nginx_s3_server_port: 443
nginx_s3_server_proto: https
nginx_s3_allow_directory_list: true
nginx_s3_cache_enabled: true
```

## S3 Bucket Requirements

The S3 bucket should have:
1. IAM user with read permissions (`s3:GetObject`, `s3:ListBucket`)
2. Bucket can be fully private (no public access needed)
3. Block Public Access can be enabled

See [S3_BUCKET_SETUP.md](S3_BUCKET_SETUP.md) for detailed S3 configuration.

## Architecture

```
Client Request → Nginx S3 Gateway → NJS Module (AWS Sig v4) → Private S3 Bucket
                      ↓
                  Cache (optional)
```

The NJS module intercepts requests and adds AWS Signature v4 authentication headers before proxying to S3.

## Files Structure

```
nginx-s3-gateway/
├── files/
│   └── njs/              # NJS scripts for AWS Signature
│       ├── awssig4.js    # AWS Signature v4 implementation
│       ├── utils.js      # Utility functions
│       └── s3gateway.js  # Main gateway logic
├── templates/
│   ├── nginx-s3-gateway.conf.j2         # Main nginx configuration
│   └── docker-compose.nginx-s3.yml.j2   # Docker compose file
├── tasks/
│   ├── main.yml                   # Main task orchestration
│   ├── 05-prefly.yml             # Pre-flight checks
│   ├── 20-base-configure.yml     # Base configuration
│   ├── 35-compose.yml            # Docker compose deployment
│   ├── 43-http-base.yml          # HTTP configuration
│   ├── 55-configs-check.yml      # Configuration validation
│   └── 99-clean.yml              # Cleanup tasks
└── defaults/
    └── main.yml                   # Default variables
```

## Usage

### Accessing S3 Objects

```bash
# Get object
curl http://your-server/path/to/file.txt

# List directory (if enabled)
curl http://your-server/path/to/directory/
```

### Health Check

```bash
curl http://your-server/health
```

### Metrics

```bash
curl http://your-server/nginx_status
```

## Troubleshooting

### Enable Debug Mode

Set `nginx_s3_debug: true` in group_vars to see detailed AWS Signature logs.

### Check Container Logs

```bash
docker logs nginx-s3-gateway
```

### Validate Configuration

```bash
docker exec nginx-s3-gateway nginx -t
```

## License

Internal use only.

## Author

DevOps Team
