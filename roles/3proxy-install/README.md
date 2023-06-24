# Description
* 3proxy need launch only host mode
* for work need open port

# example array config
Option `-64` - priority ipv6

Option ` -i[::]` - bind to all interface (ipv4 and ipv6)

```commandline
proxy_users:
  - name: 'username'
    pass: "SupperPasword"

proxies:
  - name: "socks"
    type: "socks"
    port: "14481"
    params: "-n -a1 -64 -i[::]"
    users:
      - "username"
  - name: "http"
    type: "proxy"
    port: "14482"
    params: "-n -a1 -64 -i[::]"
    users:
      - "username"

```