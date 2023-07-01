# Example configuration

generate preshared key `head -c 24 /dev/urandom | base64`

Store secret to vault, read secret preshared, role vault-get-users-secrets-teleport or set secret how variable preshared
```yaml

vault:
  secret:
    - {kv: "kv-example", path: "strongswan/s2s-example", key_name: "preshared"}

strongswan:
  peers:
    - { name: "example-peer",  ip_src: 1.2.3.4, ip_dst: 5.6.7.8, left_subnet: "10.10.0.0/16", right_subnet: "10.50.0.0/16" }

```