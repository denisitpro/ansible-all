#!/bin/bash
# dump_nginx_logs.sh

LOKI_URL="{{ loki_dump_url | default('http://127.0.0.1:3100') }}"
APP="{{ loki_dump_default_app | default('nginx-prod') }}"
OUTPUT_DIR="{{ loki_dump_output_dir | default('/tmp/loki-dump') }}"
INTERVAL_SEC="{{ loki_dump_interval_sec | default('30') }}"  # окно в секундах

# Временной диапазон: последний час
END_TS=$(date +%s)
START_TS=$((END_TS - 3600))

mkdir -p "$OUTPUT_DIR"
FINAL_FILE="$OUTPUT_DIR/nginx_$(date -d @$START_TS +%Y%m%d_%H%M)-$(date -d @$END_TS +%H%M).json"

echo "Выгрузка логов: $(date -d @$START_TS) -> $(date -d @$END_TS)"
echo "Файл: $FINAL_FILE"

# Начинаем JSON массив
echo '{"data":{"result":[' > "$FINAL_FILE"

CURRENT=$START_TS
FIRST=true
TOTAL_ENTRIES=0

while [ $CURRENT -lt $END_TS ]; do
    NEXT=$((CURRENT + INTERVAL_SEC))
    [ $NEXT -gt $END_TS ] && NEXT=$END_TS

    echo -n "  $(date -d @$CURRENT +%H:%M:%S) - $(date -d @$NEXT +%H:%M:%S) ... "

    TEMP_FILE=$(mktemp)
    curl -G -s "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query={app=\"$APP\"}" \
        --data-urlencode "start=${CURRENT}000000000" \
        --data-urlencode "end=${NEXT}000000000" \
        --data-urlencode "limit=50000" \
        -o "$TEMP_FILE"

    # Проверка на ошибку
    if grep -q "response larger" "$TEMP_FILE" 2>/dev/null; then
        echo "ОШИБКА: слишком большой ответ, уменьши INTERVAL_SEC"
        rm "$TEMP_FILE"
        exit 1
    fi

    # Извлекаем записи и добавляем
    ENTRIES=$(jq '[.data.result[].values | length] | add // 0' "$TEMP_FILE")
    echo "$ENTRIES записей"
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

# Закрываем JSON
echo ']},"status":"success"}' >> "$FINAL_FILE"

echo ""
echo "Готово: $FINAL_FILE"
echo "Всего записей: $TOTAL_ENTRIES"
ls -lah "$FINAL_FILE"