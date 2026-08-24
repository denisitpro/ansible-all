#!/bin/bash
#
# Loki Log Export Script (logcli backend)
# Export logs from Loki for a specified time range using Grafana logcli.
#
# Why logcli: native client-side pagination via --batch, server never has to
# return huge responses in a single shot, so "response too large" cannot
# happen by construction. Output is JSONL (one log entry per line).
#
# Managed by Ansible - do not edit manually
#

set -euo pipefail

# Defaults
LOKI_URL="{{ loki_dump_url | default('http://127.0.0.1:3100') }}"
APP="{{ loki_dump_default_app | default('nginx-prod') }}"
OUTPUT_DIR="{{ loki_dump_output_dir | default('/tmp/loki-dump') }}"
LOGCLI_BIN="{{ loki_dump_logcli_install_path | default('/usr/local/bin/logcli') }}"
BATCH_SIZE="{{ loki_dump_logcli_batch | default('5000') }}"
PARALLEL_DURATION="{{ loki_dump_logcli_parallel_duration | default('15m') }}"
PARALLEL_WORKERS="{{ loki_dump_logcli_parallel_workers | default('5') }}"
PERIOD=""
START_DATE=""
END_DATE=""
COMPRESS=false

{% raw %}
usage() {
    cat << 'EOF'
Loki Log Export Script (logcli backend)

Usage:
  loki-dump-logcli.sh [OPTIONS]

Options:
  -a APPS         Label app to export. Single app or comma-separated list
                  (e.g. "nginx-prod" or "nginx-prod,grafana,argocd-server")
                  (default: nginx-prod)
  -p PERIOD       Time period: 1h, 6h, 24h, 7d, 30m (default: 1h)
  -s START        Start datetime: "YYYY-MM-DD HH:MM:SS" (local time)
  -e END          End datetime: "YYYY-MM-DD HH:MM:SS" (local time)
  -u URL          Loki URL (default: http://127.0.0.1:3100)
  -o DIR          Output directory (default: /tmp/loki-dump)
  -l BATCH        logcli --batch: entries per HTTP request to Loki
                  (default: 5000; smaller = safer on heavy streams)
  -i DURATION     logcli --parallel-duration: split window into N chunks
                  fetched in parallel (default: 15m, accepts 5m/1h/...)
  -w WORKERS      logcli --parallel-max-workers (default: 5)
  -z              Compress output with gzip
  -h              Show this help

Output format:
  One JSON object per line (JSONL). Each line has timestamp, labels, line.
  Files: <output_dir>/<app>_<start>-<end>.jsonl[.gz]

Examples:
  # Export last hour (default)
  ./loki-dump-logcli.sh

  # Export last 24 hours
  ./loki-dump-logcli.sh -a nginx-prod -p 24h

  # Export several apps at once (one file per app)
  ./loki-dump-logcli.sh -a "nginx-prod,grafana,argocd-server" -p 1h

  # Export specific day
  ./loki-dump-logcli.sh -a nginx-prod -s "2026-01-28 00:00:00" -e "2026-01-28 23:59:59"

  # Export date range with compression and aggressive parallelism
  ./loki-dump-logcli.sh -a nginx-prod -s "2026-01-01 00:00:00" -e "2026-01-31 23:59:59" \
      -i 5m -w 8 -z

EOF
    exit 0
}

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

while getopts "a:p:s:e:u:o:l:i:w:zh" opt; do
    case $opt in
        a) APP="$OPTARG" ;;
        p) PERIOD="$OPTARG" ;;
        s) START_DATE="$OPTARG" ;;
        e) END_DATE="$OPTARG" ;;
        u) LOKI_URL="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        l) BATCH_SIZE="$OPTARG" ;;
        i) PARALLEL_DURATION="$OPTARG" ;;
        w) PARALLEL_WORKERS="$OPTARG" ;;
        z) COMPRESS=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Verify logcli is available
if [ ! -x "$LOGCLI_BIN" ]; then
    log_error "logcli not found or not executable at $LOGCLI_BIN"
    log_info "Install via: ansible-playbook ... -t loki-dumps-logcli"
    exit 1
fi

# Validate Loki connection
log_info "Connecting to Loki: $LOKI_URL"
if ! curl -s --max-time 5 "$LOKI_URL/ready" | grep -q "ready"; then
    log_error "Loki is not responding at $LOKI_URL"
    exit 1
fi

# Parse APP into a deduplicated list (single app or "app1,app2,app3")
IFS=',' read -r -a APPS_RAW <<< "$APP"
APPS_LIST=()
declare -A SEEN_APP
for a in "${APPS_RAW[@]}"; do
    # Trim leading/trailing whitespace
    a="${a#"${a%%[![:space:]]*}"}"
    a="${a%"${a##*[![:space:]]}"}"
    [ -z "$a" ] && continue
    if [ -z "${SEEN_APP[$a]:-}" ]; then
        SEEN_APP[$a]=1
        APPS_LIST+=("$a")
    fi
done

if [ ${#APPS_LIST[@]} -eq 0 ]; then
    log_error "No app provided (use -a APP or -a 'app1,app2')"
    exit 1
fi

# Validate every requested app exists as a label value in Loki
APPS_AVAILABLE=$(curl -s "$LOKI_URL/loki/api/v1/label/app/values" | jq -r '.data[] | select(. != null and . != "")' 2>/dev/null)
MISSING=()
for a in "${APPS_LIST[@]}"; do
    if ! echo "$APPS_AVAILABLE" | grep -qx "$a"; then
        MISSING+=("$a")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    log_error "Apps not found in Loki: ${MISSING[*]}"
    log_info "Available apps:"
    echo "$APPS_AVAILABLE" | sed 's/^/  - /'
    exit 1
fi

# Calculate time range
if [ -n "$START_DATE" ] && [ -n "$END_DATE" ]; then
    START_TS=$(date -d "$START_DATE" +%s)
    END_TS=$(date -d "$END_DATE" +%s)
elif [ -n "$PERIOD" ]; then
    END_TS=$(date +%s)
    case "$PERIOD" in
        *h) HOURS="${PERIOD%h}"; START_TS=$((END_TS - HOURS * 3600)) ;;
        *d) DAYS="${PERIOD%d}"; START_TS=$((END_TS - DAYS * 86400)) ;;
        *m) MINS="${PERIOD%m}"; START_TS=$((END_TS - MINS * 60)) ;;
        *) log_error "Invalid period format: $PERIOD (use: 1h, 24h, 7d, 30m)"; exit 1 ;;
    esac
else
    # Default: last hour
    END_TS=$(date +%s)
    START_TS=$((END_TS - 3600))
fi

# logcli expects RFC3339 UTC; build both ISO and short form for filenames
START_ISO=$(date -u -d @"$START_TS" +%Y-%m-%dT%H:%M:%SZ)
END_ISO=$(date -u -d @"$END_TS" +%Y-%m-%dT%H:%M:%SZ)
START_FMT=$(date -d @"$START_TS" +%Y%m%d_%H%M)
END_FMT=$(date -d @"$END_TS" +%Y%m%d_%H%M)

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Global header (once for the whole run)
echo ""
echo "=========================================="
echo "Loki Log Export (logcli)"
echo "=========================================="
echo "  Apps:          ${APPS_LIST[*]} (${#APPS_LIST[@]} app(s))"
echo "  Period:        $(date -d @$START_TS '+%Y-%m-%d %H:%M:%S') -> $(date -d @$END_TS '+%Y-%m-%d %H:%M:%S')"
echo "  Loki URL:      $LOKI_URL"
echo "  Batch:         $BATCH_SIZE entries / request"
echo "  Parallel win:  $PARALLEL_DURATION"
echo "  Parallel wkrs: $PARALLEL_WORKERS"
echo "  Output dir:    $OUTPUT_DIR"
echo "=========================================="

# Per-app dump loop
RESULTS=()
GRAND_TOTAL_ENTRIES=0
APP_NUM=0

# Export LOKI_ADDR so logcli picks it up by default
export LOKI_ADDR="$LOKI_URL"

for APP in "${APPS_LIST[@]}"; do
    APP_NUM=$((APP_NUM + 1))
    FINAL_FILE="$OUTPUT_DIR/${APP}_${START_FMT}-${END_FMT}.jsonl"

    echo ""
    echo "------------------------------------------"
    echo "[$APP_NUM/${#APPS_LIST[@]}] App: $APP"
    echo "  Output: $FINAL_FILE"
    echo "------------------------------------------"

    # One logcli call per app. logcli paginates internally via --batch and
    # parallelises by --parallel-duration window. JSONL goes to stdout, its
    # progress logs go to stderr — keep stderr visible so the user sees pulse.
    "$LOGCLI_BIN" query \
        --addr="$LOKI_URL" \
        --from="$START_ISO" \
        --to="$END_ISO" \
        --output=jsonl \
        --limit=0 \
        --batch="$BATCH_SIZE" \
        --parallel-duration="$PARALLEL_DURATION" \
        --parallel-max-workers="$PARALLEL_WORKERS" \
        --forward \
        "{app=\"$APP\"}" > "$FINAL_FILE"

    ENTRIES=$(wc -l < "$FINAL_FILE")

    # Compress if requested
    if [ "$COMPRESS" = true ]; then
        gzip -f "$FINAL_FILE"
        FINAL_FILE="${FINAL_FILE}.gz"
    fi

    SIZE=$(ls -lh "$FINAL_FILE" | awk '{print $5}')
    echo "  -> $ENTRIES entries, $SIZE"

    RESULTS+=("$APP|$ENTRIES|$SIZE|$FINAL_FILE")
    GRAND_TOTAL_ENTRIES=$((GRAND_TOTAL_ENTRIES + ENTRIES))
done

# Final summary across all apps
echo ""
echo "=========================================="
echo "Export Summary"
echo "=========================================="
echo "  Apps:          ${#APPS_LIST[@]}"
echo "  Total entries: $GRAND_TOTAL_ENTRIES"
echo "  Files:"
for r in "${RESULTS[@]}"; do
    IFS='|' read -r r_app r_entries r_size r_file <<< "$r"
    printf "    %-40s  %12s entries  %8s  %s\n" "$r_app" "$r_entries" "$r_size" "$r_file"
done
echo "=========================================="
{% endraw %}
