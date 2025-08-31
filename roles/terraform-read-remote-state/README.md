# Terraform Read Remote State Role

This role reads Terraform state from S3 backend and extracts specific resource information from multiple cloud providers.

## Role Variables

### Required Variables

The role uses an array-based configuration format for multiple environments and providers:

```yaml
terraform_states:
  - name: "environment-name"
    terraform_provider: "provider_type"
    s3_bucket: "your-s3-bucket-name"
    s3_key: "path/to/terraform.tfstate"
    s3_region: "aws-region"
    s3_profile: "aws-profile-name"
    resources:
      - type: "resource_type"
        name: "resource_name"
```

### Supported Providers

The role supports multiple cloud providers with different resource structures:

#### TimeWeb Cloud (TWC)
- **Provider**: `twc`
- **Resource Type**: `twc_server`
- **Attributes**: `main_ipv4`, `networks[0].ips` (for IPv6)

#### Hetzner Cloud
- **Provider**: `hetzner`
- **Resource Type**: `hcloud_server`
- **Attributes**: `ipv4_address`, `ipv6_address`

#### DigitalOcean
- **Provider**: `digitalocean`
- **Resource Type**: `digitalocean_droplet`
- **Attributes**: `ipv4_address`, `ipv6_address`

### Example Configuration

```yaml
# In group_vars or playbook vars
terraform_states:
  - name: "prod-twc"
    terraform_provider: "twc"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-twc/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    resources:
      - type: "twc_server"
        name: "vpn_server"
      - type: "twc_server"
        name: "web_server"
  
  - name: "prod-hetzner"
    terraform_provider: "hetzner"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-hetzner/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    resources:
      - type: "hcloud_server"
        name: "mgmt_server"
      - type: "hcloud_server"
        name: "monitoring_server"
  
  - name: "prod-digitalocean"
    terraform_provider: "digitalocean"
    s3_bucket: "my-terraform-backend"
    s3_key: "env/prod-do/terraform.tfstate"
    s3_region: "eu-central-1"
    s3_profile: "prod_s3_ro"
    resources:
      - type: "digitalocean_droplet"
        name: "app_server"
```

## Output Variables

The role creates variables for each resource in the format `srv_{{ resource_name }}` containing:

- `name`: Resource name from Terraform state
- `ipv4`: Primary IPv4 address
- `ipv6`: Primary IPv6 address (if available)

### Example Output Variables

```yaml
# For resource with name "vpn_server"
srv_vpn_server:
  name: "prod-vpn-01"
  ipv4: "192.168.1.100"
  ipv6: "2001:db8::100"

# For resource with name "mgmt_server"
srv_mgmt_server:
  name: "prod-mgmt-01"
  ipv4: "10.0.1.100"
  ipv6: "2001:db8:1::100"
```

## Usage Examples

### Basic Usage
```yaml
---
- name: Read Terraform State
  hosts: localhost
  connection: local
  gather_facts: false
  
  tasks:
    - name: Read Terraform remote state
      ansible.builtin.include_role:
        name: terraform-read-remote-state
      tags:
        - tf
        - tf-data

    - name: Use extracted data
      ansible.builtin.debug:
        msg: "VPN Server {{ srv_vpn_server.name }} has IP {{ srv_vpn_server.ipv4 }}"
      when: srv_vpn_server is defined
```

### Multiple Environments
```yaml
---
- name: Extract Data from Multiple Environments
  hosts: localhost
  connection: local
  gather_facts: false
  
  tasks:
    - name: Read Terraform remote state
      ansible.builtin.include_role:
        name: terraform-read-remote-state
      tags:
        - tf
        - tf-data

    - name: Display all extracted servers
      ansible.builtin.debug:
        msg: |
          TWC VPN: {{ srv_vpn_server.name }} ({{ srv_vpn_server.ipv4 }})
          Hetzner MGMT: {{ srv_mgmt_server.name }} ({{ srv_mgmt_server.ipv4 }})
          DO App: {{ srv_app_server.name }} ({{ srv_app_server.ipv4 }})
      when: srv_vpn_server is defined or srv_mgmt_server is defined or srv_app_server is defined
```

## Task Structure

The role uses a modular approach with provider-specific tasks:

- `05-read-state.yml` - Main orchestrator that routes to provider-specific tasks
- `15-loop-state-twc.yml` - TimeWeb Cloud provider processing
- `20-loop-state-hetzner.yml` - Hetzner Cloud provider processing  
- `25-loop-state-digitalocean.yml` - DigitalOcean provider processing

## Tags

The role supports the following tags:
- `tf`: General Terraform operations
- `tf-data`: Data extraction operations

# Requirements

## AWS CLI

This role requires `awscli` to be installed on your local system.

### macOS Installation

```bash
brew install awscli
```

After installation, ensure `aws` is available:

```bash
aws --version
```

### AWS Profile Configuration

You must have a valid AWS profile configured. On macOS, profiles are stored in:

- `~/.aws/credentials`
- `~/.aws/config`

#### Example `~/.aws/credentials`

```
[prod_s3_ro]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

#### Example `~/.aws/config`

```
[profile prod_s3_ro]
region = eu-central-1
```

Make sure the profile name matches the one used in the playbook or role.

## Terraform State Access

Ensure your AWS profile has read permissions for the S3 bucket containing Terraform state files.