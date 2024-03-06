array example

```commandline
vector:
  - {
    name: appname,
    type: loki,
    log_path: "/var/log/appname/*.log",
    endpoint: "https://loki-server.example.com"
  }

```