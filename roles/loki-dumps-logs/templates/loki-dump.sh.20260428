#!/bin/bash
#
# Loki Log Export Script
# Export logs from Loki for a specified time range
#
# Managed by Ansible - do not edit manually
#

set -e

# Defaults
LOKI_URL="{{ loki_dump_url | default('http://127.0.0.1:3100') }}"
APP="{{ loki_dump_default_app | default('nginx-prod') }}"
OUTPUT_DIR="{{ loki_dump_output_dir | default('/tmp/loki-dump') }}"
INTERVAL_SEC="{{ loki_dump_interval_sec | default('30') }}"
LIMIT="{{ loki_dump_limit | default('50000') }}"
PERIOD=""
START_DATE=""
END_DATE=""
COMPRESS=false

usage() {
    cat << 'EOF'
Loki Log Export Script

Usage:
  loki-dump.sh [OPTIONS]

Options:
  -a APP          Label app to export (default: nginx-prod)
  -p PERIOD       Time period: 1h, 6h, 24h, 7d, etc. (default: 1h)
  -s START        Start datetime: "YYYY-MM-DD HH:MM:SS"
  -e END          End datetime: "YYYY-MM-DD HH:MM:SS"
  -u URL          Loki URL (default: http://127.0.0.1:3100)
  -o DIR          Output directory (default: /tmp/loki-dump)
  -i INTERVAL     Pagination interval in seconds (default: 30)
  -l LIMIT        Records limit per request (default: 50000)
  -z              Compress output with gzip
  -h              Show this help

Examples:
  # Export last hour (default)
  ./loki-dump.sh

  # Export last 24 hours
  ./loki-dump.sh -a nginx-prod -p 24h

  # Export specific day
  ./loki-dump.sh -a nginx-prod -s "2026-01-28 00:00:00" -e "2026-01-28 23:59:59"

  # Export date range with compression
  ./loki-dump.sh -a nginx-prod -s "2026-01-01 00:00:00" -e "2026-01-31 23:59:59" -z

  # Export different app
  ./loki-dump.sh -a victoriaMetrics -p 1h

EOF
    exit 0
}

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

while getopts "a:p:s:e:u:o:i:l:zh" opt; do
    case $opt in
        a) APP="$OPTARG" ;;
        p) PERIOD="$OPTARG" ;;
        s) START_DATE="$OPTARG" ;;
        e) END_DATE="$OPTARG" ;;
        u) LOKI_URL="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        i) INTERVAL_SEC="$OPTARG" ;;
        l) LIMIT="$OPTARG" ;;
        z) COMPRESS=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate Loki connection
log_info "Connecting to Loki: $LOKI_URL"
if ! curl -s --max-time 5 "$LOKI_URL/ready" | grep -q "ready"; then
    log_error "Loki is not responding at $LOKI_URL"
    exit 1
fi

# Validate app label exists
APPS=$(curl -s "$LOKI_URL/loki/api/v1/label/app/values" | jq -r '.data[]' 2>/dev/null)
if ! echo "$APPS" | grep -qx "$APP"; then
    log_error "app='$APP' not found in Loki"
    log_info "Available apps:"
    echo "$APPS" | sed 's/^/  - /'
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

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate output filename
START_FMT=$(date -d @$START_TS +%Y%m%d_%H%M)
END_FMT=$(date -d @$END_TS +%Y%m%d_%H%M)
FINAL_FILE="$OUTPUT_DIR/${APP}_${START_FMT}-${END_FMT}.json"

echo ""
echo "=========================================="
echo "Loki Log Export"
echo "=========================================="
echo "  App:        $APP"
echo "  Period:     $(date -d @$START_TS '+%Y-%m-%d %H:%M:%S') -> $(date -d @$END_TS '+%Y-%m-%d %H:%M:%S')"
echo "  Interval:   ${INTERVAL_SEC}s"
echo "  Limit:      $LIMIT"
echo "  Output:     $FINAL_FILE"
echo "=========================================="
echo ""

# Estimate work
TOTAL_SEC=$((END_TS - START_TS))
TOTAL_INTERVALS=$(( (TOTAL_SEC + INTERVAL_SEC - 1) / INTERVAL_SEC ))
log_info "Total intervals: $TOTAL_INTERVALS (estimated time: $((TOTAL_INTERVALS * 3 / 60)) min)"
echo ""

# Initialize JSON file
echo '{"data":{"result":[' > "$FINAL_FILE"

CURRENT=$START_TS
FIRST=true
TOTAL_ENTRIES=0
INTERVAL_NUM=0

while [ $CURRENT -lt $END_TS ]; do
    NEXT=$((CURRENT + INTERVAL_SEC))
    [ $NEXT -gt $END_TS ] && NEXT=$END_TS
    
    INTERVAL_NUM=$((INTERVAL_NUM + 1))
    printf "  [%d/%d] %s - %s ... " "$INTERVAL_NUM" "$TOTAL_INTERVALS" \
        "$(date -d @$CURRENT +%H:%M:%S)" "$(date -d @$NEXT +%H:%M:%S)"
    
    TEMP_FILE=$(mktemp)
    
    HTTP_CODE=$(curl -G -s -w "%{http_code}" -o "$TEMP_FILE" "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query={app=\"$APP\"}" \
        --data-urlencode "start=${CURRENT}000000000" \
        --data-urlencode "end=${NEXT}000000000" \
        --data-urlencode "limit=$LIMIT")
    
    # Check HTTP errors
    if [ "$HTTP_CODE" != "200" ]; then
        echo "HTTP ERROR $HTTP_CODE"
        cat "$TEMP_FILE"
        rm "$TEMP_FILE"
        exit 1
    fi
    
    # Check response size error
    if grep -q "response larger" "$TEMP_FILE" 2>/dev/null; then
        log_error "Response too large. Reduce INTERVAL_SEC (current: $INTERVAL_SEC)"
        rm "$TEMP_FILE"
        exit 1
    fi
    
    # Extract and append entries
    ENTRIES=$(jq '[.data.result[].values | length] | add // 0' "$TEMP_FILE")
    echo "$ENTRIES entries"
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES))
    
    if [ "$ENTRIES" -gt 0 ]; then
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ',' >> "$FINAL_FILE"
        fi
        jq -c '.data.result[]' "$TEMP_FILE" | paste -sd ',' >> "$FINAL_FILE"
    fi
    
    rm "$TEMP_FILE"
    CURRENT=$NEXT
done

# Close JSON structure
echo ']},"status":"success"}' >> "$FINAL_FILE"

echo ""
echo "=========================================="
echo "Export Complete"
echo "=========================================="
echo "  File:       $FINAL_FILE"
echo "  Entries:    $TOTAL_ENTRIES"
echo "  Size:       $(ls -lh "$FINAL_FILE" | awk '{print $5}')"

# Compress if requested
if [ "$COMPRESS" = true ]; then
    log_info "Compressing..."
    gzip -f "$FINAL_FILE"
    FINAL_FILE="${FINAL_FILE}.gz"
    echo "  Compressed: $FINAL_FILE"
    echo "  Size:       $(ls -lh "$FINAL_FILE" | awk '{print $5}')"
fi

echo "=========================================="
