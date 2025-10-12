# backup-directory

## Description

This Ansible role deploys a flexible backup script that creates encrypted, compressed archives of specified directories using GPG encryption. The script supports command-line parameters for maximum flexibility and can backup multiple directories with different configurations.

## Features

- GPG encryption using specified recipient key
- Configurable compression (gzip)
- Automatic backup rotation based on retention days
- Detailed logging with timestamps
- Command-line parameter support for flexibility
- Built-in validation and error handling

## Usage

### Script Parameters

The backup script supports the following command-line parameters:

#### Required:
- `--source <path>` - Source directory to backup

#### Optional:
- `--dest <path>` - Destination directory (default: `/mnt/backup`)
- `--prefix <string>` - Backup filename prefix (default: `backup`)
- `--retention <days>` - Backup retention in days (default: `30`)
- `--gpg-recipient <key>` - GPG recipient key ID (default: configured key)
- `--no-encrypt` - Disable GPG encryption
- `--no-compress` - Disable compression
- `--log-file <path>` - Log file path (default: `/var/log/backup.log`)
- `--help` - Show help message

### Examples

#### Basic usage with minimal parameters:
```bash
/opt/scripts/backup-directory.sh --source /opt/backup
```

#### Backup with custom destination and prefix:
```bash
/opt/scripts/backup-directory.sh --source /var/log --dest /backup --prefix logs --retention 7
```

#### Unencrypted backup without compression:
```bash
/opt/scripts/backup-directory.sh --source /home/user --no-encrypt --no-compress
```

#### Multiple directory backups (via cron):
```bash
# Backup application data
35 2 * * * /opt/scripts/backup-directory.sh --source /opt/backup --prefix app_backup --retention 14

# Backup logs
45 2 * * * /opt/scripts/backup-directory.sh --source /var/log --prefix logs --retention 7
```

## Variables

### Default Configuration

- `backup_dest_dir`: Default destination directory (`/mnt/backup`)
- `backup_gpg_recipient`: Default GPG recipient key ID
- `backup_retention_days`: Default retention period in days (`30`)
- `backup_filename_prefix`: Default filename prefix (`backup`)
- `backup_compress`: Enable compression by default (`true`)
- `backup_encrypt`: Enable encryption by default (`true`)
- `backup_log_file`: Default log file location (`/var/log/backup.log`)
- `backup_script_path`: Script installation directory (`/opt/scripts`)

### Rclone Configuration

- `backup_use_rclone`: Enable rclone support (`false`)
- `backup_rclone_targets`: Dictionary of rclone targets configuration
- `backup_rclone_remote_path`: Default remote path (`backups`)
- `backup_rclone_detailed_log_dir`: Rclone logs directory (`/tmp/rclone`)

### Internal Cron Configuration

- `backup_use_internal_cron`: Enable automatic cron job creation (`false`)
- `backup_cron_jobs`: List of backup jobs to schedule

## Configuration Examples

### Complete setup with backup, rclone upload and automatic cron

```yaml
# Enable all features
backup_use_rclone: true
backup_use_internal_cron: true

# Rclone target configuration
backup_rclone_targets:
  wasabi-backup:
    type: s3
    provider: Wasabi
    env_auth: false
    access_key_id: "{{ wasabi_access_key }}"
    secret_access_key: "{{ wasabi_secret_key }}"
    endpoint: "s3.eu-central-2.wasabisys.com"
    region: "eu-central-2"
    acl: "private"

# Automatic cron jobs
backup_cron_jobs:
  - name: "backup-application-data"
    minute: "30"
    hour: "2"
    source: "/opt/backup"
    prefix: "app_backup"
    retention: 14
    upload_after: true
    upload_target: "wasabi-backup:server01/daily/"
    
  - name: "backup-logs"
    minute: "45"
    hour: "1" 
    source: "/var/log"
    prefix: "logs"
    retention: 7
    upload_after: true
    upload_target: "wasabi-backup:server01/logs/"
    
  - name: "backup-config"
    minute: "15"
    hour: "3"
    source: "/etc"
    prefix: "config"
    retention: 30
    upload_after: false  # Only local backup
```

### Manual cron setup (external cron-rules role)

```yaml
# Use external cron role
backup_use_internal_cron: false

# Configure via cron-rules role
cron:
  jobs:
    - name: "backup-and-upload"
      minute: "30"
      hour: "2"
      job: "/opt/scripts/backup-directory.sh --source /opt/backup --prefix app && /opt/scripts/backup-upload.sh --target wasabi-backup:server01/"
```

## Output Files

Backup files are created with the following naming convention:
- Encrypted: `<prefix>_YYYYMMDD_HHMMSS.tar.gz.gpg`
- Unencrypted: `<prefix>_YYYYMMDD_HHMMSS.tar.gz`

## Requirements

- GPG must be installed and configured
- Target GPG public key must be imported
- Sufficient disk space in destination directory
- Write permissions to destination and log directories
