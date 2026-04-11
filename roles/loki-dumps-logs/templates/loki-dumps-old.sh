#!/bin/bash
# loki-dumps-old.sh — выгрузка логов из Loki с разбивкой на временные окна
# Использование:
#   ./loki-dumps-old.sh                          # последний час
#   ./loki-dumps-old.sh -s "2026-03-16 10:00" -e "2026-03-16 11:00"
#   ./loki-dumps-old.sh -s "2026-03-16 10:00" -e "2026-03-16 11:00" -i 60 -f 50

set -euo pipefail

# ── Конфигурация ────────────────────────────────────────────────────────────
LOKI_URL="http://127.0.0.1:3100"
APP="nginx-prod"
OUTPUT_DIR="/tmp/dump-prod"
INTERVAL_SEC=60   # размер окна запроса в секундах
LIMIT=50000        # лимит записей на одно окно
FLUSH_EVERY=100     # сбрасывать буфер в файл каждые N итераций с данными

# ── Парсинг аргументов ───────────────────────────────────────────────────────
START_ARG=""
END_ARG=""

usage() {
    echo "Использование: $0 [-s 'YYYY-MM-DD HH:MM'] [-e 'YYYY-MM-DD HH:MM'] [-i INTERVAL_SEC] [-f FLUSH_EVERY]"
    echo "  -s  начало диапазона (по умолчанию: час назад)"
    echo "  -e  конец диапазона  (по умолчанию: сейчас)"
    echo "  -i  размер окна в секундах (по умолчанию: $INTERVAL_SEC)"
    echo "  -f  сброс буфера каждые N итераций с данными (по умолчанию: $FLUSH_EVERY)"
    echo "  -h  справка"
    exit 0
}

while getopts "s:e:i:f:h" opt; do
    case $opt in
        s) START_ARG="$OPTARG" ;;
        e) END_ARG="$OPTARG" ;;
        i) INTERVAL_SEC="$OPTARG" ;;
        f) FLUSH_EVERY="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ── Вычисление временного диапазона ─────────────────────────────────────────
if [ -n "$START_ARG" ]; then
    START_TS=$(date -d "$START_ARG" +%s 2>/dev/null) || {
        echo "ОШИБКА: неверный формат даты начала: '$START_ARG'"
        echo "Пример: '2026-03-16 10:00'"
        exit 1
    }
else
    START_TS=$(( $(date +%s) - 3600 ))
fi

if [ -n "$END_ARG" ]; then
    END_TS=$(date -d "$END_ARG" +%s 2>/dev/null) || {
        echo "ОШИБКА: неверный формат даты конца: '$END_ARG'"
        echo "Пример: '2026-03-16 11:00'"
        exit 1
    }
else
    END_TS=$(date +%s)
fi

if [ "$START_TS" -ge "$END_TS" ]; then
    echo "ОШИБКА: начало диапазона должно быть раньше конца"
    exit 1
fi

DURATION=$(( END_TS - START_TS ))
WINDOWS=$(( (DURATION + INTERVAL_SEC - 1) / INTERVAL_SEC ))

# ── Подготовка файлов ────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
FINAL_FILE="$OUTPUT_DIR/nginx_$(date -d @$START_TS +%Y%m%d_%H%M)-$(date -d @$END_TS +%Y%m%d_%H%M).json"

# Маленький буфер между flush-ами — только текущая пачка из FLUSH_EVERY итераций
FLUSH_BUF=$(mktemp)
TEMP_FILE=$(mktemp)
trap 'rm -f "$FLUSH_BUF" "$TEMP_FILE"' EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Loki dump: $APP"
echo " Диапазон : $(date -d @$START_TS '+%Y-%m-%d %H:%M:%S') → $(date -d @$END_TS '+%Y-%m-%d %H:%M:%S')"
echo " Длительность: ${DURATION}с | Окно: ${INTERVAL_SEC}с | Окон: ${WINDOWS}"
echo " Flush каждые: ${FLUSH_EVERY} итераций с данными"
echo " Файл     : $FINAL_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Открываем JSON сразу при старте ──────────────────────────────────────────
printf '{"data":{"result":[' > "$FINAL_FILE"

# ── Функция сброса буфера в файл ─────────────────────────────────────────────
# Флаг: нужна ли запятая перед следующим объектом в массиве result
NEED_COMMA=false

flush_buffer() {
    [ -s "$FLUSH_BUF" ] || return 0

    local first_in_buf=true
    while IFS= read -r line; do
        if [ "$NEED_COMMA" = true ] || [ "$first_in_buf" = false ]; then
            printf ',' >> "$FINAL_FILE"
        fi
        printf '%s' "$line" >> "$FINAL_FILE"
        first_in_buf=false
        NEED_COMMA=true
    done < "$FLUSH_BUF"

    # Очищаем буфер не пересоздавая файл (экономим inode)
    > "$FLUSH_BUF"
    printf "  ↓ flush [%s]\n" "$(ls -lah "$FINAL_FILE" | awk '{print $5}')"
}

# ── Основной цикл ────────────────────────────────────────────────────────────
CURRENT=$START_TS
WINDOW_NUM=0
TOTAL_ENTRIES=0
TRUNCATED_WINDOWS=0
BUF_COUNT=0

while [ "$CURRENT" -lt "$END_TS" ]; do
    NEXT=$(( CURRENT + INTERVAL_SEC ))
    [ "$NEXT" -gt "$END_TS" ] && NEXT=$END_TS
    WINDOW_NUM=$(( WINDOW_NUM + 1 ))

    printf "  [%3d/%d] %s - %s ... " \
        "$WINDOW_NUM" "$WINDOWS" \
        "$(date -d @$CURRENT +%H:%M:%S)" \
        "$(date -d @$NEXT +%H:%M:%S)"

    HTTP_CODE=$(curl -G -s -w "%{http_code}" \
        "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query={app=\"$APP\"}" \
        --data-urlencode "start=${CURRENT}000000000" \
        --data-urlencode "end=${NEXT}000000000" \
        --data-urlencode "limit=${LIMIT}" \
        -o "$TEMP_FILE")

    # Проверка HTTP-кода
    if [ "$HTTP_CODE" != "200" ]; then
        ERR_MSG=$(jq -r '.message // .error // "неизвестная ошибка"' "$TEMP_FILE" 2>/dev/null || echo "нечитаемый ответ")
        echo "ОШИБКА HTTP $HTTP_CODE: $ERR_MSG"
        CURRENT=$NEXT
        continue
    fi

    # Проверка валидности JSON
    if ! jq empty "$TEMP_FILE" 2>/dev/null; then
        echo "ОШИБКА: невалидный JSON в ответе"
        CURRENT=$NEXT
        continue
    fi

    # Подсчёт записей
    ENTRIES=$(jq '[.data.result[].values | length] | add // 0' "$TEMP_FILE")
    TOTAL_ENTRIES=$(( TOTAL_ENTRIES + ENTRIES ))

    # Предупреждение о достижении лимита
    WARN=""
    if [ "$ENTRIES" -ge "$LIMIT" ]; then
        WARN=" ⚠ лимит ${LIMIT}! Уменьши -i"
        TRUNCATED_WINDOWS=$(( TRUNCATED_WINDOWS + 1 ))
    fi

    echo "${ENTRIES} записей${WARN}"

    # Складываем result-объекты в буфер (один объект — одна строка)
    if [ "$ENTRIES" -gt 0 ]; then
        jq -c '.data.result[]' "$TEMP_FILE" >> "$FLUSH_BUF"
        BUF_COUNT=$(( BUF_COUNT + 1 ))
    fi

    # Сброс буфера каждые FLUSH_EVERY итераций с данными
    if [ "$BUF_COUNT" -ge "$FLUSH_EVERY" ]; then
        flush_buffer
        BUF_COUNT=0
    fi

    CURRENT=$NEXT
done

# ── Финальный сброс остатка ───────────────────────────────────────────────────
flush_buffer

# ── Закрываем JSON ───────────────────────────────────────────────────────────
printf ']},"status":"success"}' >> "$FINAL_FILE"


# ── Итог ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Готово: $FINAL_FILE"
echo " Всего записей : $TOTAL_ENTRIES"
echo " Обработано окон: $WINDOW_NUM"
if [ "$TRUNCATED_WINDOWS" -gt 0 ]; then
    echo " ⚠  Окон с обрезкой (limit hit): $TRUNCATED_WINDOWS — рекомендуется уменьшить -i"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -lah "$FINAL_FILE"
