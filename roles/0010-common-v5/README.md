# Role: 0010-common-v5

Base role for configuring common Ubuntu system components.

## Description

This role performs basic Ubuntu system configuration, including package installation, DNS setup, time configuration, security settings, and other system components.

## Main Tasks

### DNS Management (50-55)
- **50-config-systemd-resolved.yml** - Configure systemd-resolved
- **55-resolv-conf.yml** - Configure resolv.conf

### Updates and Packages (70-90)
- **70-update-installed-packages.yml** - Update installed packages
- **80-install-base-packages.yml** - Install base packages (Ubuntu only)
- **90-qemu.yml** - Install QEMU packages (PMX only)

### Time and Logs (150-170)
- **150-time.yml** - Configure time and NTP
- **160-rsyslog.yml** - Configure rsyslog
- **170-hosts-and-hostname-notag.yml** - Configure hostname and hosts (except AWS)

### /etc/hosts Generation (180)
- **180-etc-hosts.yml** - Create /etc/hosts file from template

#### Task 180 Description

Task `180-etc-hosts.yml` creates the `/etc/hosts` file from the `etc_hosts.j2` template with basic Ubuntu configuration.

**Execution Condition:** Runs only when the `force_create_etc_hosts` variable is defined

**What it does:**
- Generates `/etc/hosts` file from `etc_hosts.j2` template
- Sets file permissions to `644`
- Sets owner to `root:root`

**Generated file content:**
```
127.0.0.1    localhost
127.0.1.1    {{ ansible_hostname }}

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

**Usage:**
To activate the task, define the variable in the playbook or inventory:
```yaml
force_create_etc_hosts: true
```

**Tags:**
- `base`
- `common-base`
- `hosts`
- `etc-hosts`

### Security (301-305)
- **301-security.yml** - Configure security and SSH
- **305-ipv6-bind-only.yml** - Configure bind for IPv6 only (when needed)

### Reboot (900)
- **900-reboot.yml** - System reboot ('never' tag)

## Variables

### Required for some tasks:
- `dns_management` - DNS management type ("apply" or "resolv.conf")
- `cloud_provider` - Cloud provider ("pmx", "aws", etc.)
- `force_create_etc_hosts` - Force creation of /etc/hosts from template
- `bind_ipv6_only_force` - Force bind configuration for IPv6 only

## Tags

- `base` - Basic settings
- `common-base` - Common basic settings
- `dns` - DNS settings
- `os-update`, `update-os` - OS updates
- `base-packages` - Base packages
- `qemu-packages` - QEMU packages
- `ntp`, `time` - Time settings
- `rsyslog` - Logging settings
- `hostname`, `hosts` - Hostname and hosts settings
- `etc-hosts` - Specific for /etc/hosts generation
- `sshd` - SSH settings
- `ipv6-only` - IPv6-only settings
- `never`, `reboot` - Reboot (only when explicitly specified)

## Usage Examples

### Basic role application:
```yaml
- hosts: all
  roles:
    - 0010-common-v5
```

### With forced /etc/hosts creation:
```yaml
- hosts: all
  vars:
    force_create_etc_hosts: true
  roles:
    - 0010-common-v5
```

### Running only specific tasks:
```yaml
- hosts: all
  roles:
    - 0010-common-v5
  tags:
    - etc-hosts
```