# Description

Role required install
* teleport (brew install teleport)
* jq

# Restrictions
The role is written for hashicorp vault, where we loging  in using OIDC
```commandline
tsh app login example-vault
 
export VAULT_CLIENT_CERT="$(tsh app config --format=cert example-vault )"
export VAULT_CLIENT_KEY="$(tsh app config --format=key example-vault )"
export VAULT_ADDR="https://example-vault.teleport.example.com"
 
vault login -method=oidc role=example-vault-mgmt-ro
```

# Store secrets
* In order for secrets to work, they must be in the expected location with the expected set of fields.
* Each secret has its own path, inside one entry of the format key: value
* In order to put the secret into the vault, you must log into the vault as in the example above, and then put the token values into variable roles - vars/vault.secret  

```commandline
vault kv put kvname/store_path/key/ value="value_example"
```

For correct operation, it is necessary in the folder roles/vault-get-users-secrets-oidc/vars create file **vault.secret** and enter your token in it, which you receive when logging into the vault (described above in the regular login section). File format example below
```commandline
vault_token: s.AsdWMasdasddTI9vCxxiX
```

For convenience, it is recommended to make a symlink to the file at the root of the turnip. 
```commandline
ln -s roles/vault-get-users-secrets-oidc/vars/vault.secret vault.secret
```

For security purposes, .gitignore has an exclusion of *.secret files. That is, it will not get into the repository and will always be with you locally

# Example array variable
```commandline
vault:
  secret:
    - {kv: "kvexample", path: "server/nginx",  key_name: "example_site_cert"}
    - {kv: "kvexample", path: "server/nginx",  key_name: "example_site_key"}
```