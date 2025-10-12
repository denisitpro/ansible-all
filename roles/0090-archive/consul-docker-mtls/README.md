# Description

# generate key
`consul keygen`

To launch a Consul server, you need to set the following options:

* `consul_mode`: The mode of the Consul server, e.g., `server`.
* `consul_ui`: Enables or disables the Consul web UI, e.g., `"true"`.
* `consul_cls_group`: The name of the group of Consul nodes, e.g., `name_our_cluster group`.

# Example Variables

### Group File: `hosts`

In the group file, define your Consul nodes like this:

```ini
[consul_cls_location1]

consul-01.example.com
consul-02.example.com
consul-03.example.com
```

In your configuration, you would then set the variables as follows:

```yaml
consul_ui: "true"
consul_mode: server
consul_cls_group: consul_cls_location1
```

This configuration ensures that the Consul server will run in `server` mode, with the web UI enabled, and will be associated with the group `consul_cls_location1`, which contains the nodes `consul-01.example.com`, `consul-02.example.com`, and `consul-03.example.com`.


# Example set variable consul_agent_ca

```yaml
consul_agent_ca: |
  -----BEGIN CERTIFICATE-----
  MIIC7jCCApSgAwIBAgIRAKvAwVyVQRBJsbmjhPl89tMwCgYIKoZIzj0EAwIwgbkx
  -----END CERTIFICATE-----
```