# Requirements

## AWS CLI

This role requires `awscli` to be installed on your local system.

### macOS Installation

```bash
brew install awscli
```

After installation, ensure `aws` is available:

```bash
aws --version
```

### AWS Profile Configuration

You must have a valid AWS profile configured. On macOS, profiles are stored in:

- `~/.aws/credentials`
- `~/.aws/config`

#### Example `~/.aws/credentials`

```
[c1_devel_s3_rw]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

#### Example `~/.aws/config`

```
[profile example_ro]
region = eu-central-1
```

Make sure the profile name matches the one used in the playbook or role.