#!/usr/bin/env bash
set -euo pipefail

LOKI_URL="http://127.0.0.1:3100"
QUERY='{namespace=~".+"}'
LIMIT=500000
OUT_DIR="/opt/loki-export"
HOUR=$(date -u +%Y%m%d_%H)

mkdir -p "${OUT_DIR}"
OUT_LOG="${OUT_DIR}/logs_${HOUR}.log"
TMP_JSON="${OUT_DIR}/chunk.json"


START=$(date -u -d '1 hour ago' +%s%N)
END=$(date -u +%s%N)

CURRENT_START=${START}

: > "${OUT_LOG}"

while true; do
  curl -sG "${LOKI_URL}/loki/api/v1/query_range" \
    --data-urlencode "query=${QUERY}" \
    --data-urlencode "start=${CURRENT_START}" \
    --data-urlencode "end=${END}" \
    --data-urlencode "limit=${LIMIT}" \
    --data-urlencode "direction=forward" \
    -o "${TMP_JSON}"

  COUNT=$(jq '.data.result | length' "${TMP_JSON}")
  [ "${COUNT}" -eq 0 ] && break

  jq -r '
    .data.result[]
    | .stream as $labels
    | .values[]
    | "[\(. [0] | tonumber / 1000000000 | todate)] \($labels) \(. [1])"
  ' "${TMP_JSON}" >> "${OUT_LOG}"

  LAST_TS=$(jq -r '
    .data.result[-1].values[-1][0]
  ' "${TMP_JSON}")

  # Safety net to avoid infinite loop
  if [ "${LAST_TS}" -le "${CURRENT_START}" ]; then
    break
  fi

  CURRENT_START="${LAST_TS}"
done