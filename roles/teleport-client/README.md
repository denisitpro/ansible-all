# Teleport Client Role


## Notes
- if `ssh_acl_level` not send - default `ssh_acl_level: 900`

# Important
For proper connection to PostgreSQL through Teleport, PostgreSQL must be running in SSL mode, not in plain text mode. The client does not support connections via plain text.

## Example publish app and SSH access
```yaml
teleport:
  app:
    - name: web-appp
      uri: "http://127.0.0.1:8080"
      public_addr: "web.tp.example.com"
      app_acl_level:
        - 300
        - 500
  ssh_acl_level:
    - 300
    - 500
  databases:
    - { protocol: "postgres", name: "demo-postgres", uri: "127.0.0.1:5432", tls_mode: "insecure" }

```