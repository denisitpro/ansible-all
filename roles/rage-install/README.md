# Rage Install Role

Ansible role for installing rage encryption tool by downloading binaries from the official GitHub releases.

## Features

- Support for architectures: x86_64, aarch64, i386, armv6, armv7
- Automatic architecture detection
- Download latest rage version
- Install to `/usr/local/bin`
- Install all rage binaries: rage, rage-keygen, rage-mount
- Installation verification

## Variables

- `rage_version`: rage version to install (default: v0.11.1)
- `rage_install_dir`: installation directory (default: /usr/local/bin)
- `rage_base_url`: base URL for downloads
- `rage_binaries`: list of binaries to install (rage, rage-keygen, rage-mount)

## Usage

```yaml
- hosts: servers
  become: true
  roles:
    - rage-install
```

## Requirements

- Ansible 2.9+
- Internet access for downloading rage
- sudo privileges for installation
