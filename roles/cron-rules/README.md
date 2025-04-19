# Example task

```yaml
cron:
  jobs:
    - {name: "backup_rotation", minute: "35", hour: "2", job: 'find /opt/backup -name "*.gpg" -type f -mtime +3 -delete' }
```