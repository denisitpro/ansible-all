# autors

exporter used

https://github.com/jvstein/bitcoin-prometheus-exporter

# example
```version: "3.7"
services:
  btcexporter:
    image: jvstein/bitcoin-prometheus-exporter:v0.5.0
    ports:
      - "8334:8334"
    environment:
      - BITCOIN_RPC_HOST=btnet-dev.example.com
      - BITCOIN_RPC_PORT=18332
      - BITCOIN_RPC_USER=user
      - BITCOIN_RPC_PASSWORD=password
    logging:
      driver: json-file
      options:
        max-size: 100m
        max-file: '3'```