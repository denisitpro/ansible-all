# Vault Role - Quick Start Guide

This guide provides a straightforward setup for interacting with Vault using OIDC authentication. Follow the instructions below to configure and use the role effectively.

## Prerequisites

Ensure the following are installed on the system where the playbook is executed:

- **Teleport client** (`tsh`)
- **jq** - A utility for formatting JSON

## Role Limitations

This role is specifically designed for use with Vault instances that require OIDC for login.

## Token Management

To enable this role to work correctly, create a file named `vault.secret` in the root of the repository. This file will store your Vault token.

1. After logging in to Vault, obtain your token and store it in the `vault.secret` file in the following format:

    ```yaml
    vault_token: s.PbWMasdasddTI9vCxxiX
    ```

2. For security reasons, all `*.secret` files are excluded from the repository via `.gitignore`, ensuring that sensitive data remains local.

## Getting Started

To interact with Vault, follow these steps:

1. Log in to the Vault application using Teleport:

    ```bash
    tsh app login vault-c1
    ```

2. Export the necessary environment variables for Vault:

     You can either:

     - Set the `teleport_vault_app_name` variable to the name of the Vault application in Teleport (e.g., `vault-example-app`). To list available applications, use:

       ```bash
       teleport app ls
       ```

     **OR**

     - Manually export the required environment variables:

       ```bash
       tsh login --proxy=tp.example.com --auth=github
       tsh app login vault-example-app
       export VAULT_CLIENT_CERT="$(tsh app config --format=cert vault-example-app)"
       export VAULT_CLIENT_KEY="$(tsh app config --format=key vault-example-app)"
       export VAULT_ADDR="https://vault-example-app.teleport.example.com"
       ```

3. **OR** Log in to Vault using OIDC:

    ```bash
    vault login -method=oidc role=example-vault-mgmt-rw
    ```

## Consul Integration

This role supports variable configuration, allowing for simultaneous login to multiple applications.

To log in to Consul, follow these steps:

1. Log in via Teleport using GitHub authentication:

    ```bash
    tsh login --proxy=tp.example.com --auth=github
    ```

2. Log in to the Consul application:

    ```bash
    tsh app login consul-01
    ```

3. Export the necessary environment variables for Consul:

    ```bash
    export CONSUL_CLIENT_CERT="$(tsh app config --format=cert consul-01)"
    export CONSUL_CLIENT_KEY="$(tsh app config --format=key consul-01)"
    export CONSUL_HTTP_ADDR=https://consul-01.tp.glorytech.bet
    export CONSUL_HTTP_TOKEN=our_token
    ```

## Secret Management in Vault

Vault stores secrets under unique paths for better access control. Each secret is stored as a single key-value pair in its own path.

### Storing a Secret in Vault

1. Log in to Vault as described in the [Getting Started](#getting-started) section.
2. Use the following command to store a secret in Vault:

    ```bash
    vault kv put kvname/store_path/key/ value="value_example"
    ```

   - Note: The `kvname` is separated as its own entity due to the Vault API's path structure, which may vary based on version (`kvname/v1/path/`).