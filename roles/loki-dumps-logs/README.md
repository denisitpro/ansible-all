# Loki Log Export Role

Ansible role for deploying Loki log export scripts to servers.

## Overview

This role deploys scripts to export logs from Loki for auditing and compliance purposes. Logs are exported in native JSON format, compatible with auditor requirements.

## Scripts

| Script | Description |
|--------|-------------|
| `loki-dump.sh` | Full-featured export with date range support |
| `loki-1h.sh` | Simple export for last hour (legacy) |

## Usage

### Basic Commands

```bash
# Export last hour (default)
./loki-dump.sh

# Export last 24 hours
./loki-dump.sh -p 24h

# Export last 7 days
./loki-dump.sh -p 7d

# Export specific day
./loki-dump.sh -s "2026-01-28 00:00:00" -e "2026-01-28 23:59:59"

# Export date range
./loki-dump.sh -s "2026-01-01 00:00:00" -e "2026-01-31 23:59:59"
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-a APP` | Loki app label to export | `nginx-prod` |
| `-p PERIOD` | Time period (e.g., `1h`, `24h`, `7d`) | `1h` |
| `-s START` | Start datetime (`YYYY-MM-DD HH:MM:SS`) | - |
| `-e END` | End datetime (`YYYY-MM-DD HH:MM:SS`) | - |
| `-u URL` | Loki server URL | `http://127.0.0.1:3100` |
| `-o DIR` | Output directory | `/tmp/loki-dump` |
| `-i SEC` | Pagination interval (seconds) | `30` |
| `-l LIMIT` | Records per request | `50000` |
| `-z` | Compress output with gzip | `false` |
| `-h` | Show help | - |

### Examples for Auditors

```bash
# Export full day for specific date
./loki-dump.sh -a nginx-prod -s "2026-01-15 00:00:00" -e "2026-01-15 23:59:59" -z

# Export week with compression
./loki-dump.sh -a nginx-prod -s "2026-01-08 00:00:00" -e "2026-01-14 23:59:59" -z

# Export month
./loki-dump.sh -a nginx-prod -s "2026-01-01 00:00:00" -e "2026-01-31 23:59:59" -z
```

### Different Apps

```bash
# List available apps
curl -s "http://127.0.0.1:3100/loki/api/v1/label/app/values" | jq .

# Export specific app
./loki-dump.sh -a victoriaMetrics -p 24h
./loki-dump.sh -a ingress-nginx -p 1h
```

## Output Format

Output is native Loki JSON format:

```json
{
  "data": {
    "result": [
      {
        "stream": {
          "app": "nginx-prod",
          "hostname": "prod-web-01",
          "environment": "production"
        },
        "values": [
          ["1706531400000000000", "{\"message\": \"log entry...\"}"],
          ["1706531401000000000", "{\"message\": \"another entry...\"}"]
        ]
      }
    ]
  },
  "status": "success"
}
```

### Output File Naming

Files are named: `{app}_{start_datetime}-{end_datetime}.json[.gz]`

Example: `nginx-prod_20260128_0000-20260128_2359.json.gz`

## Performance

| Period | Entries (approx) | Size (approx) | Time (approx) |
|--------|------------------|---------------|---------------|
| 1 hour | 1M | 3-4 GB | 8 min |
| 24 hours | 24M | 70-100 GB | 3 hours |
| 7 days | 168M | 500-700 GB | 20+ hours |

**Recommendations:**
- Use `-z` compression for exports > 1 hour
- Consider splitting large exports by day
- Run long exports in `screen` or `tmux`

## Troubleshooting

### Error: Response too large

```
ОШИБКА: Response too large. Reduce INTERVAL_SEC
```

**Solution:** Reduce pagination interval:
```bash
./loki-dump.sh -i 15 -p 24h  # 15 seconds instead of 30
```

### Error: App not found

```
app='nginx-prod' not found in Loki
```

**Solution:** Check available apps:
```bash
curl -s "http://127.0.0.1:3100/loki/api/v1/label/app/values" | jq .
```

### Error: Loki not responding

```
Loki is not responding at http://127.0.0.1:3100
```

**Solution:** Check Loki status:
```bash
curl -s "http://127.0.0.1:3100/ready"
systemctl status loki
```

## Ansible Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `loki_dump_url` | Loki server URL | `http://127.0.0.1:3100` |
| `loki_dump_default_app` | Default app label | `nginx-prod` |
| `loki_dump_output_dir` | Output directory | `/tmp/loki-dump` |
| `loki_dump_interval_sec` | Pagination interval | `30` |
| `loki_dump_limit` | Records per request | `50000` |

## Requirements

- `curl` - HTTP requests
- `jq` - JSON processing
- `gzip` - Compression (optional)

## License

Internal use only.
