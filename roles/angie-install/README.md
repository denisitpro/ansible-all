# Ansible Role: Angie Installation and Configuration

This Ansible role installs and configures Angie, supporting both HTTP and SSL configurations. SSL can be configured using either self-signed certificates or ACME-based certificates (e.g., Let's Encrypt).

## Features

- **SSL Support**:
  - Self-signed certificates
  - ACME-based certificates for domain validation (e.g., Let's Encrypt)
  - Certificates from the HCP vault

## Configuration Parameters

- **`certbot_cert_usage`**: Set to `true` to enable volume support for Angie in the Docker Compose setup, specifying paths for Certbot.
- **`acme`**: Set to `true` at the site level to enable ACME challenge support for domain validation by Let's Encrypt.

## Default Behavior

By default, the role configures Angie with basic settings and optionally integrates with Certbot for automated certificate management.

## Dependencies

- **`certbot-certbot-docker`**: Required to configure support for ACME challenges and certificate management.

## Example Configuration

To configure Angie with ACME challenge support, use the following parameters:

- **`certbot_cert_usage`**: Enables Certbot integration.
- **`upstream_multi`**: Defines upstream configurations for Angie.
- **`angie.vhosts`**: Configures virtual hosts with ACME challenge enabled.

Refer to your specific configuration needs to adapt the role for your environment.


### Angie support acme challenge certbot
```yaml
certbot_cert_usage: true
upstream_multi:
  upstream:
    - { name: "upstream1", server: "127.0.0.1", port: 6081, fail_timeout: 30, max_fails: 30, conf: "angie-multi-g2.conf.j2" }
angie:
  vhosts:
    - { servername: "app.example.com",
        domain: "app.example.com",
        config_file: "vhost-general-g3.conf.j2",
        upstream_protocol: http,
        upstream_name: "upstream1",
        acme: true
      }
```

### Angie Self-Signed Certificate Support
This role can automatically generate self-signed SSL certificates if any domain in the configuration is specified as `selfsign`. The generated certificate will be applied to the corresponding virtual host.
The following example demonstrates how to configure a virtual host with a self-signed certificate:


```yaml
upstream_multi:
  upstream:
    - { name: "upstream1", server: "127.0.0.1", port: 6081, fail_timeout: 30, max_fails: 30, conf: "angie-multi-g2.conf.j2" }
angie:
  vhosts:
    - { servername: "app.example.com",
        domain: "selfsign",
        config_file: "vhost-general-g3.conf.j2",
        upstream_protocol: http,
        upstream_name: "upstream1"
      }
```
