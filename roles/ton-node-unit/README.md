# Description
Install ton node use script mytonctl

# Compatibility
testing only for ubuntu 22.04

# Docs
* https://docs.ton.org/participate/run-nodes/full-node

# Compare
**mytonctrl** - use fork Tonstakers https://github.com/tonstakers/mytonctrl-v2

## Changes
- **Added network support**: Configuration is based on network.
- **TON Node version:** Added support for TON Node version
- **Added support for different branches from mytonctl**: Ensures mytonctl works correctly when executing commands when the repo is not default
- **Resource Validation:** Added support for different values ​​for testnet and mainnet.


# Options
* `ton_node_force_install: true` - set force install ton node and remove mytonctrl-v2