# TODO
* merge compose
* change ip to support dns name - bind address
* security hardness port manage,en volume nodes
* test failure server data
* test cluste master servers
* check replication status
```
    "Layouts": [
      {
        "replication": "000",
```

# Replication Level Configuration

SeaweedFS supports several levels of replication:

- **000**: No replication (single copy).
- **001**: One additional copy on another volume server.
- **010**: Two copies on different volume servers.
- **100**: One copy within the same rack.
- **110**: Two copies, one within the same rack and another on a different rack.
- 