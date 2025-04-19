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
  CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJDQTEWMBQGA1UEBxMNU2FuIEZyYW5jaXNj
  bzEaMBgGA1UECRMRMTAxIFNlY29uZCBTdHJlZXQxDjAMBgNVBBETBTk0MTA1MRcw
  FQYDVQQKEw5IYXNoaUNvcnAgSW5jLjFAMD4GA1UEAxM3Q29uc3VsIEFnZW50IENB
  IDIyODI5ODgzMDExNjI5NTY4MDgxNDg3NzU5OTI2NzA4MTIyMTg0MzAeFw0yNTA0
  MTcxMDMyMTVaFw0zNTA0MTUxMDMyMTVaMIG5MQswCQYDVQQGEwJVUzELMAkGA1UE
  CBMCQ0ExFjAUBgNVBAcTDVNhbiBGcmFuY2lzY28xGjAYBgNVBAkTETEwMSBTZWNv
  bmQgU3RyZWV0MQ4wDAYDVQQREwU5NDEwNTEXMBUGA1UEChMOSGFzaGlDb3JwIElu
  Yy4xQDA+BgNVBAMTN0NvbnN1bCBBZ2VudCBDQSAyMjgyOTg4MzAxMTYyOTU2ODA4
  MTQ4Nzc1OTkyNjcwODEyMjE4NDMwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATE
  9Fjd9DebPxftjdC4SD0GC0bPnbl4jMGKP2qP+0SYTO0DrBiN6VU+YaMzrHdsfcHT
  QKisDfIbYaQU7Oh20XTgo3sweTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUw
  AwEB/zApBgNVHQ4EIgQgfb2wdu+qvX/0q4R7CF1XtBKDJrUivDIg6RRo3s0sDtkw
  KwYDVR0jBCQwIoAgfb2wdu+qvX/0q4R7CF1XtBKDJrUivDIg6RRo3s0sDtkwCgYI
  KoZIzj0EAwIDSAAwRQIgUDvN6XW1XcI+zUIlnF+0GRaVsqvavmXbvqPMZwrIc9MC
  IQCAVHvnm7QXsJkMm9FVponk3htDv+KOQYZOIkv48Takdw==
  -----END CERTIFICATE-----
```