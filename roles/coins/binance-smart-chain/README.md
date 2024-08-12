# Docs
* https://github.com/bnb-chain/bsc

# Default launch mode
```commandline
## It runs fullnode with Path-Base Storage Scheme. 
## It will enable inline state prune, keeping the latest 90000 blocks' history state by default.
./geth --config ./config.toml --datadir ./node  --cache 8000 --rpc.allow-unprotected-txs --history.transactions 0 --tries-verify-mode none --state.scheme path

```