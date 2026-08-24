# Loki Log Export Role

Ansible role for deploying Loki log export scripts to servers.

## Overview

This role deploys scripts to export logs from Loki for auditing and compliance purposes. The recommended tool is `loki-dump-logcli.sh`, a wrapper around Grafana's official `logcli` binary. The role also installs `logcli` itself.

## Scripts

| Script | Status | Description |
|--------|--------|-------------|
| `loki-dump-logcli.sh` | **Recommended** | Export via `logcli` with native pagination. Output: JSONL. |
| `loki-dump.sh` | **Deprecated** | Hand-rolled `curl` loop over `query_range`. Hits `response too large` on heavy streams. Kept for legacy/compat only. |
| `loki-1h.sh` | Legacy | Simple last-hour export, kept for backwards compatibility. |

> Use `loki-dump-logcli.sh` for all new exports. `loki-dump.sh` will be removed once downstream consumers migrate to JSONL.

## Quick Start

```bash
# Export last hour of ingress-nginx logs
loki-dump-logcli.sh -a ingress-nginx -p 1h

# Export last 24 hours of ingress-nginx logs (compressed)
loki-dump-logcli.sh -a ingress-nginx -p 24h -z
```

Output goes to `/tmp/loki-dump/` by default, named `<app>_<start>-<end>.jsonl[.gz]`.

## `loki-dump-logcli.sh` (Recommended)

Wraps `logcli query` with the same external CLI we used before. Internally it makes one `logcli` call per app, with native client-side pagination via `--batch` and parallel fetching via `--parallel-duration` × `--parallel-max-workers`. By construction this never trips the `response too large` server-side limit.

### Common workflows

```bash
# 1 hour, single app
loki-dump-logcli.sh -a ingress-nginx -p 1h

# 24 hours, single app, gzipped
loki-dump-logcli.sh -a ingress-nginx -p 24h -z

# Several apps at once (one file per app)
loki-dump-logcli.sh -a "ingress-nginx,grafana,argocd-server" -p 1h

# Specific day for an auditor
loki-dump-logcli.sh -a ingress-nginx \
    -s "2026-01-15 00:00:00" -e "2026-01-15 23:59:59" -z

# Heavy day with aggressive parallelism
loki-dump-logcli.sh -a ingress-nginx -p 24h \
    -i 5m -w 8 -z
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-a APPS` | App label. Single app or comma-separated list (`a1,a2,a3`) | `nginx-prod` |
| `-p PERIOD` | Time period: `30m`, `1h`, `24h`, `7d` | `1h` |
| `-s START` | Start datetime (`YYYY-MM-DD HH:MM:SS`, local time) | - |
| `-e END` | End datetime (`YYYY-MM-DD HH:MM:SS`, local time) | - |
| `-u URL` | Loki URL | `http://127.0.0.1:3100` |
| `-o DIR` | Output directory | `/tmp/loki-dump` |
| `-l BATCH` | `logcli --batch`: entries per HTTP request | `5000` |
| `-i DURATION` | `logcli --parallel-duration`: parallel sub-window size | `15m` |
| `-w WORKERS` | `logcli --parallel-max-workers` | `5` |
| `-z` | Compress output with gzip | `false` |
| `-h` | Show help | - |

> Either `-p` or the `-s`/`-e` pair must be set. If neither is given, the script defaults to the last hour.

### Output format

JSONL — one JSON object per line. Each object has `timestamp`, `labels`, and `line`:

```json
{"labels":{"detected_level":"unknown","environment":"example-prod","k8s_cluster":"k8s-example-prod"},"line":"{\"app_name\":\"ingress-nginx\",\"status\":200,...}","timestamp":"2026-04-28T11:04:03.041895276Z"}
```

Notes for downstream consumers:

- `labels` contains only labels that vary across streams in this export — labels common to every record (e.g. `app` when filtering by `{app="X"}`) are collapsed by `logcli` to save space. The full identifying info is still inside the parsed JSON in `line`.
- File naming: `<app>_<start>-<end>.jsonl[.gz]` (e.g. `ingress-nginx_20260128_0000-20260128_2359.jsonl.gz`).
- One file per app even when `-a` lists several.

### Verifying output

```bash
# Pretty-print first record
head -n 1 /tmp/loki-dump/ingress-nginx_*.jsonl | jq

# Count records
wc -l /tmp/loki-dump/ingress-nginx_*.jsonl

# Filter by status code (the JSON log line is in .line as a string — parse it)
jq -r 'select(.line | fromjson | .status >= 500) | .line' \
    /tmp/loki-dump/ingress-nginx_*.jsonl
```

## Tuning for heavy apps

Defaults are tuned for typical k8s-component apps. If you hit timeouts or want faster exports for traffic-heavy services (`ingress-nginx`, `nginx-prod`), reach for these flags in order:

1. **Smaller `--batch`** (`-l 1000`) — keeps each Loki response light, useful when single-stream rate is very high.
2. **Smaller `--parallel-duration`** (`-i 5m` or `-i 1m`) — splits the time range into more sub-windows.
3. **More workers** (`-w 8` or `-w 16`) — parallelism for those sub-windows. Be careful: this multiplies load on Loki.
4. **Run it in `screen`/`tmux`** for multi-hour exports.

If `logcli` complains about a label-matcher returning too many series, narrow the query (e.g. shard by `pod`).

## Auditor workflow

```bash
# Day-level dump for compliance, gzipped
loki-dump-logcli.sh -a ingress-nginx \
    -s "2026-01-15 00:00:00" -e "2026-01-15 23:59:59" -z

# Multi-app day-level dump
loki-dump-logcli.sh -a "ingress-nginx,payload-front,payload-back" \
    -s "2026-01-15 00:00:00" -e "2026-01-15 23:59:59" -z
```

For periods longer than a day, prefer day-by-day exports (one file per app per day) — easier to deliver, partially recover, and verify.

## Troubleshooting

### `logcli not found or not executable`

`logcli` is installed by this role. Re-run with the role tag:

```bash
ansible-playbook ... -t loki-dumps-logcli
```

### `Apps not found in Loki`

The script lists currently available apps when validation fails. If your app is recent, it may not yet have any logs in Loki's retention window — confirm via:

```bash
curl -s "http://127.0.0.1:3100/loki/api/v1/label/app/values" | jq .
```

### `Loki is not responding at <URL>`

```bash
curl -s http://127.0.0.1:3100/ready
docker compose -f /opt/docker/loki/docker-compose.loki.yml ps
```

## `loki-dump.sh` (Deprecated)

> **Deprecated.** Kept only because some downstream consumers still parse the legacy wrapped-JSON format. Do not use for new exports — it hits `response too large` on traffic-heavy apps such as `ingress-nginx` and `nginx-prod`. Use `loki-dump-logcli.sh` instead.

If you absolutely need the legacy format, the CLI is the same as `loki-dump-logcli.sh`, but `-i` is in seconds (pagination window), `-l` is the per-request entry limit, and the output file is `.json` with a `{"data":{"result":[...]}}` wrapper.

## Ansible Variables

### Common

| Variable | Description | Default |
|----------|-------------|---------|
| `loki_dump_url` | Loki server URL | `http://127.0.0.1:3100` |
| `loki_dump_default_app` | Default app label baked into scripts | `nginx-prod` |
| `loki_dump_output_dir` | Output directory | `/tmp/loki-dump` |
| `loki_dump_script_dir` | Where to install scripts | `/usr/local/bin` |

### `loki-dump-logcli.sh`

| Variable | Description | Default |
|----------|-------------|---------|
| `loki_dump_install_logcli` | Install `logcli` binary | `true` |
| `loki_dump_logcli_version` | Pin `logcli` version (match Loki server) | `3.7.1` |
| `loki_dump_logcli_install_path` | Where to install the binary | `/usr/local/bin/logcli` |
| `loki_dump_logcli_batch` | Default `--batch` baked into script | `5000` |
| `loki_dump_logcli_parallel_duration` | Default `--parallel-duration` | `15m` |
| `loki_dump_logcli_parallel_workers` | Default `--parallel-max-workers` | `5` |

### `loki-dump.sh` (legacy)

| Variable | Description | Default |
|----------|-------------|---------|
| `loki_dump_interval_sec` | Pagination interval (seconds) | `30` |
| `loki_dump_limit` | Records per request | `50000` |

## Tags

| Tag | Effect |
|-----|--------|
| `loki-dumps` | Run the entire role |
| `loki-dumps-prefly` | Pre-flight only (script directory) |
| `loki-dumps-logcli` | Install `logcli` only |
| `loki-dumps-files` | Deploy script templates only |

## Requirements

- `curl`, `jq`, `gzip` — for both scripts
- `unzip` — installed by the role itself for `logcli` extraction
- `logcli` — installed by the role (pinned via `loki_dump_logcli_version`)

## License

Internal use only.
