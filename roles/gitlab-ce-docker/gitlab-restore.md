# GitLab Backup and Restore Guide (Docker)

This guide covers backup creation and restoration procedures for GitLab running in Docker container.

## Official Documentation

For comprehensive information about GitLab backup and restore procedures, refer to:
- [GitLab Official Restore Documentation](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/)

## Important: Pre-Restore Initialization

**CRITICAL**: Before restoring a backup, GitLab must be started at least once to initialize.

**First-time restore steps:**
1. Start GitLab container
2. Wait for full initialization (check: `docker logs -f gitlab`)
3. Verify all services running: `docker exec gitlab gitlab-ctl status`
4. Proceed with restore

## Prerequisites

- GitLab instance running in Docker container named `gitlab`
- Access to Docker host with sufficient permissions
- For restore: exact same GitLab version as backup was created from

## Creating Backup

### Full Backup

Create complete backup including all data:

```bash
docker exec -t gitlab gitlab-backup create
```

### Selective Backup (Excluding Artifacts and Registry)

Create backup without CI artifacts and container registry (reduces backup size):

```bash
docker exec -t gitlab gitlab-backup create SKIP=artifacts,registry
```

**Note**: Backup file will be created in `/var/opt/gitlab/backups` inside container with name format: `<timestamp>_<version>_gitlab_backup.tar`

### Backup GitLab Secrets

**Critical**: Always backup secrets file separately. Without this file, the backup cannot be restored properly.

```bash
# Copy secrets from container to host
docker cp gitlab:/etc/gitlab/gitlab-secrets.json /path/to/safe/location/gitlab-secrets.json
```

## Preparing New Instance

### Get Initial Root Password

On a fresh GitLab installation, retrieve the initial root password:

```bash
docker exec -it gitlab cat /etc/gitlab/initial_root_password
```

**Note**: This file is automatically deleted 24 hours after first reconfigure.

## Restore Procedure

### Step 1: Transfer Backup File

Copy backup file to the backup directory inside container:

```bash
# From host to host location mounted to container
cp /source/path/<timestamp>_<version>_gitlab_backup.tar /opt/gitlab/backups/

# Set proper permissions for the backup file on host
chmod 0644 /opt/gitlab/backups/<timestamp>_<version>_gitlab_backup.tar
```

**Important**: The backup file must be accessible inside container at `/var/opt/gitlab/backups/`

### Step 2: Stop GitLab Services

Stop Puma and Sidekiq processes (keep rest of GitLab running):

```bash
docker exec -it gitlab gitlab-ctl stop puma
docker exec -it gitlab gitlab-ctl stop sidekiq
```

Verify services are stopped:

```bash
docker exec -it gitlab gitlab-ctl status
```

### Step 3: Restore GitLab Secrets

**Critical**: Must be done before restore. Copy secrets file to host location mounted to container:

```bash
# Copy to host location (adjust paths according to your docker-compose volumes)
cp /source/path/gitlab-secrets.json /opt/gitlab/conf/gitlab-secrets.json
```

Set proper permissions inside container:

```bash
docker exec -it gitlab chmod 0600 /etc/gitlab/gitlab-secrets.json
docker exec -it gitlab chown root:root /etc/gitlab/gitlab-secrets.json
```

### Step 4: Restore Backup

Run restore command with backup timestamp (without `_gitlab_backup.tar` suffix):

```bash
docker exec -it gitlab gitlab-backup restore BACKUP=<timestamp>_<version>
```

Example:
```bash
docker exec -it gitlab gitlab-backup restore BACKUP=1770184600_2026_02_04_18.7.2
```

**Warning**: This command will overwrite the contents of your GitLab database!

When prompted, confirm the restore operation by typing `yes`.

### Step 5: Reconfigure GitLab

Apply configuration after restore:

```bash
docker exec -it gitlab gitlab-ctl reconfigure
```

### Step 6: Restart GitLab

Restart the container to start all services:

```bash
docker restart gitlab
```

Or start services manually:

```bash
docker exec -it gitlab gitlab-ctl start
```

### Step 7: Verify Restore

Check GitLab status:

```bash
docker exec -it gitlab gitlab-rake gitlab:check SANITIZE=true
```

Verify database secrets can be decrypted:

```bash
docker exec -it gitlab gitlab-rake gitlab:doctor:secrets
```

Optional integrity checks for uploaded files:

```bash
docker exec -it gitlab gitlab-rake gitlab:artifacts:check
docker exec -it gitlab gitlab-rake gitlab:lfs:check
docker exec -it gitlab gitlab-rake gitlab:uploads:check
```

## Important Notes

### Version Compatibility

- Restore must be performed on **exactly the same GitLab version** (including CE/EE type)
- If versions differ, upgrade/downgrade target instance before restore
- Version mismatch will abort restore with error message

### Permissions and Ownership

- Backup files must be readable by `git` user inside container
- Secrets file must have `0600` permissions and be owned by `root:root`
- Backup directory: `/var/opt/gitlab/backups` (inside container)

### Data Overwrite Warning

Restore process will:
- **Erase all PostgreSQL data** automatically
- **Fail if Git repositories with same names exist** - use fresh instance
- **Not clear object storage** - manual cleanup required if using object storage

### Secrets File Critical

Without `gitlab-secrets.json`:
- Users with 2FA cannot login
- GitLab Runners cannot authenticate
- CI/CD variables are lost
- Database encryption keys are missing

### WebAuthn Devices

When restoring to different FQDN, all WebAuthn devices (YubiKeys, etc.) will be disabled. Users must re-register them.

## Troubleshooting

### Warning Messages During Restore

```plaintext
ERROR: must be owner of extension pg_trgm
WARNING: no privileges could be revoked for "public"
```

These warnings are **normal** and can be safely ignored. Restore completes successfully despite these messages.

### Repositories Show as Empty After Restore

If using `fapolicyd` for security, check Gitaly configuration and `fapolicyd` rules.

### Restore Hangs or Times Out

- Verify backup file is not corrupted
- Check disk space on target system
- Ensure all services are properly stopped before restore

## Quick Reference

```bash
# Backup
docker exec -t gitlab gitlab-backup create SKIP=artifacts,registry
docker cp gitlab:/etc/gitlab/gitlab-secrets.json ./gitlab-secrets.json

# Restore
cp backup.tar /opt/gitlab/backups/
cp gitlab-secrets.json /opt/gitlab/conf/
docker exec -it gitlab gitlab-ctl stop puma
docker exec -it gitlab gitlab-ctl stop sidekiq
docker exec -it gitlab chmod 0600 /etc/gitlab/gitlab-secrets.json
docker exec -it gitlab chown root:root /etc/gitlab/gitlab-secrets.json
docker exec -it gitlab gitlab-backup restore BACKUP=<timestamp>_<version>
docker exec -it gitlab gitlab-ctl reconfigure
docker restart gitlab
docker exec -it gitlab gitlab-rake gitlab:check SANITIZE=true
```

## References

- [Official GitLab Restore Documentation](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/)
- [GitLab Backup Configuration](https://docs.gitlab.com/administration/backup_restore/)
