# Example Usage of Certbot and Nginx

This example demonstrates how to use Certbot with Nginx to enable SSL/TLS for your websites. The provided configurations support automatic ACME challenge handling to obtain certificates from Let's Encrypt.

## Configuration Parameters

- **certbot_cert_usage:** `true` - Enables the volume support for Nginx in the Docker Compose setup, specifying paths for Certbot.
- **acme:** `true` - Enables ACME challenge support at the site level, allowing for domain validation by Let's Encrypt.
- **ssl_path:** `"/opt/certbot/ssl/live"` - Specifies the path to the certificates inside the container.

## Example Configuration

```yaml
certbot_cert_usage: true

upstream_multi:
  upstream:
    - { name: "upstream1", server: "127.0.0.1", port: 6081, fail_timeout: 30, max_fails: 30, conf: "nginx-multi-g2.conf.j2" }

  type: ip_hash

nginx:
  vhosts:
    - { servername: "app.example.com",
        domain: "app.example.com",
        config_file: "vhost-general.conf.j2",
        upstream_protocol: http,
        upstream_name: "upstream1",
        acme: true,
        ssl_path: "/opt/certbot/ssl/live"
      }
  include:
    - "/etc/nginx/include/tls1_2-tls1_3.conf"