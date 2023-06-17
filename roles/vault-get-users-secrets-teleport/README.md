# Description
To work with the role, the following must be installed on the computer from which the playbook is launched:
* Teleport client (tsh)
* jq - JSON formatting utility

# Limitations
The role is designed for Vault, where we log in using OIDC.

```commandline
tsh app login vault-c1
 
export VAULT_CLIENT_CERT="$(tsh app config --format=cert example-vault)"
export VAULT_CLIENT_KEY="$(tsh app config --format=key example-vault)"
export VAULT_ADDR="https://example-vault.teleport.example.com"
 
vault login -method=oidc role=example-vault-mgmt-rw
```

# Secret Storage
* To work with secrets, they must be located in the expected location with the expected set of fields. There are different approaches to storing secrets, such as storing all secrets under one path or the approach used here - each secret has its own path, with a single record in the format of key: value. This is done intentionally for more granular access control.
* To store a secret in Vault, you must log in to Vault as shown in the example above, and then execute the following command. kv is separated as a separate entity because the API path requires kvname/v1/path/ depending on the version, hence the chosen scheme with three values.

```commandline
vault kv put kvname/store_path/key/ value="value_example"
```

To ensure correct operation, create a file named "vault.secret" in the root of the repository and write your token obtained during the login to Vault (described above in the regular login section) in the following format:

```commandline
vault_token: s.PbWMasdasddTI9vCxxiX
```

For security reasons, the ".gitignore" file excludes "*.secret" files. This means that the file will not be included in the repository and will always remain local to you.