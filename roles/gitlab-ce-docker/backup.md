# GitLab Backup Configuration

This role provides automated GitLab backup functionality with optional encryption and remote storage upload.

## Default Behavior (Backup Only)

By default, the backup script performs local backups without encryption or remote upload:

1. Creates GitLab backup using `gitlab-backup create` command
2. Backs up configuration files (`gitlab.rb` and `gitlab-secrets.json`) as tar.gz archive
3. Stores backups in local directory (default: `/mnt/gitlab-backup`)

### Enable Basic Backup

```yaml
gitlab_backup_enabled: true
gitlab_backup_cron_enabled: true
```

This will:
- Deploy backup script to `/opt/scripts/backup-gitlab.sh`
- Create cron job running at 03:00 daily (configurable)
- Store backups locally in `gitlab_backup_local_dir`

## Optional Features

### 1. Backup Encryption

Encrypts backup files using `rage` before storing locally.

**Requirements:**
- Role: `rage-install` - installs rage encryption tool
- Role: `backup-directory` - provides encryption script

**Configuration:**

```yaml
gitlab_backup_encrypt: true
gitlab_backup_encrypt_dest: /mnt/backup          # Optional, default: /mnt/backup
gitlab_backup_encrypt_retention: 3               # Optional, default: 3
```

When enabled:
- Backups are encrypted using `/opt/scripts/backup-directory.sh`
- Encrypted files stored in `gitlab_backup_encrypt_dest`
- Original unencrypted files are removed
- Retention policy applied (keeps N versions)

### 2. Remote Storage Upload (S3)

Uploads backups to S3-compatible storage (Wasabi, AWS S3, Backblaze B2, etc.).

**Requirements:**
- Role: `rclone-install` - installs rclone for S3 operations
- Configured rclone remote in `/root/.config/rclone/rclone.conf`

**Configuration:**

```yaml
gitlab_backup_s3_upload: true
gitlab_backup_s3_target: wasabi-backup           # Optional, default: b2-backup
gitlab_backup_s3_remote_path: backup-bucket/path # Optional, default: gitlab/
```

When enabled:
- Uploads to S3 using `/opt/scripts/backup-upload.sh`
- If encryption enabled: uploads encrypted files
- If encryption disabled: uploads plain backups
- Local files removed after successful upload (when encryption disabled)

### 3. Combined: Encryption + S3 Upload

For maximum security, combine both features:

```yaml
gitlab_backup_encrypt: true
gitlab_backup_s3_upload: true
gitlab_backup_s3_target: wasabi-backup
gitlab_backup_s3_remote_path: reservo-bucket/gitlab/
```

Flow:
1. Create GitLab backup → `/mnt/gitlab-backup`
2. Encrypt backups → `/mnt/backup` (encrypted)
3. Upload encrypted files to S3 → `s3://wasabi-backup/reservo-bucket/gitlab/`
4. Remove local unencrypted files

## Configuration Variables

### Required Variables

```yaml
gitlab_backup_enabled: false              # Enable backup functionality
gitlab_backup_cron_enabled: false         # Enable cron job
```

### Backup Paths

```yaml
gitlab_backup_path: /mnt/gitlab-backup    # GitLab container backup mount point
gitlab_backup_local_dir: /mnt/gitlab-backup  # Local staging directory (default)
```

### Backup Options

```yaml
gitlab_skip_items: "artifacts,registry,builds"  # Items to skip in backup (optional)
```

### Cron Schedule

```yaml
gitlab_backup_cron_minute: "0"
gitlab_backup_cron_hour: "3"
gitlab_backup_cron_day: "*"
gitlab_backup_cron_month: "*"
gitlab_backup_cron_weekday: "*"
```

### Encryption Settings

```yaml
gitlab_backup_encrypt: false              # Enable encryption (default: false)
gitlab_backup_encrypt_dest: /mnt/backup   # Encryption destination (optional)
gitlab_backup_encrypt_retention: 3        # Keep N versions (optional)
```

### S3 Upload Settings

```yaml
gitlab_backup_s3_upload: false            # Enable S3 upload (default: false)
gitlab_backup_s3_target: b2-backup        # Rclone remote name (optional)
gitlab_backup_s3_remote_path: gitlab/     # Remote path in bucket (optional)
```

## Role Dependencies

This role depends on external roles for optional features:

| Feature | Required Roles | Description |
|---------|---------------|-------------|
| Encryption | `rage-install`<br>`backup-directory` | Installs rage tool and encryption script |
| S3 Upload | `rclone-install` | Installs rclone for S3 operations |

Make sure these roles are included in your playbook **before** `gitlab-ce-docker` role:

```yaml
roles:
  - rclone-install        # For S3 upload
  - rage-install          # For encryption
  - backup-directory      # For encryption script
  - gitlab-ce-docker      # GitLab with backup
```

## Example Configurations

### Minimal (Local Backup Only)

```yaml
gitlab_backup_enabled: true
gitlab_backup_cron_enabled: true
```

### With Encryption

```yaml
gitlab_backup_enabled: true
gitlab_backup_cron_enabled: true
gitlab_backup_encrypt: true
```

### Full Setup (Encryption + S3)

```yaml
gitlab_backup_enabled: true
gitlab_backup_cron_enabled: true
gitlab_backup_encrypt: true
gitlab_backup_s3_upload: true
gitlab_backup_s3_target: wasabi-backup
gitlab_backup_s3_remote_path: "{{ wasabi_bucket }}/gitlab/"
```

## Manual Execution

Run backup manually:

```bash
/opt/scripts/backup-gitlab.sh
```

Check logs:

```bash
tail -f /var/log/gitlab-backup.log
```

## Backup Files

Backup creates following files:

1. **GitLab data backup**: `*_gitlab_backup.tar` (timestamped by GitLab)
2. **Configuration archive**: `gitlab_config_YYYYMMDD_HHMMSS.tar.gz`

Both files stored in `gitlab_backup_local_dir` or encrypted to `gitlab_backup_encrypt_dest`.
