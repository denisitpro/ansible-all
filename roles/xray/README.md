# XRay Server Configuration Guide

This guide explains how to configure the XRay server, including changing attributes, generating UUIDs, setting domain information, and working with keys.

## Configure XRay

### 1. Change Client ID

To change the client ID, update the `setgins->clients->id` parameter in your configuration file.

You can generate a new UUID using the following command:

```bash
docker run --rm ghcr.io/xtls/xray-core:latest uuid
```

### 2. Configure Reality Settings

#### a. Set Destination and Server Names

Update the `streamSettings -> realitySettings -> dest` and `serverNames` fields. For example, you can use `microsoft.com` as a server name.

#### b. Set Domain

Set the domain by following the instructions in [this Habr article](https://habr.com/ru/articles/731608/). Section [Настройка сервера XRay] -> RealiTLScanner

#### c. Generate and Set x25519 Keys

Generate a new private and public key pair for x25519 with the following command:

```bash
docker run --rm ghcr.io/xtls/xray-core:latest x25519
```

The output will look like this:

```plaintext
Private key: aHdpK1iz2z9swp6eb_eweliEasXm80EqPQQRW7X3BBQ
Public key: QWUsa5JpdGKhrNHg98ewAZbdTgyZRDiwMMBc0uOJZk4
```

Store the private key in your secure storage and set the `streamSettings -> realitySettings -> key` with the public key in your configuration file.

### 3. Set Short IDs

Generate a short ID using the following command:

```bash
openssl rand -hex 8
```

Use this ID to set the `shortIds` parameter in your configuration file.

## Additional Documentation
* For more detailed instructions, please refer to the [Habr article on XRay server setup](https://habr.com/ru/articles/731608/).
* GitHub Xray-core - https://github.com/XTLS/Xray-core
