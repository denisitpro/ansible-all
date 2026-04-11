#!/bin/bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/scripts/.env-clone}"
if [[ -f "$ENV_FILE" ]]; then
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
    echo "Loaded: $ENV_FILE"
else
    echo "Warning: .env file not found: $ENV_FILE"
fi

SOURCE_DB="$1"
TARGET_DB="$2"

if [[ -z "${SOURCE_DB:-}" || -z "${TARGET_DB:-}" ]]; then
    echo "Usage: $0 <SOURCE_DB> <TARGET_DB>"
    exit 1
fi

LOCAL_CONTAINER="${LOCAL_CONTAINER:-mysql}"

SSL_CA="/etc/mysql/ssl/ca.pem"
SSL_OPTS="--ssl-mode=REQUIRED --ssl-ca=$SSL_CA"

echo "Secure push via SSL: $SOURCE_DB → $TARGET_DB (to $TARGET_HOST)"


echo "--- 1. Preparing target database $TARGET_DB ---"
docker exec -i "$LOCAL_CONTAINER" mysql \
    -h "$TARGET_HOST" \
    -u "$TARGET_MYSQL_USER" -p"$TARGET_MYSQL_PASS" \
    $SSL_OPTS <<SQL
DROP DATABASE IF EXISTS \`$TARGET_DB\`;
CREATE DATABASE \`$TARGET_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL


echo "--- 2. Creating dump of $SOURCE_DB ---"
TEMP_DUMP="/tmp/clone_${SOURCE_DB}_$$_$RANDOM.sql"
trap 'rm -f "$TEMP_DUMP" 2>/dev/null || true' EXIT

docker exec "$LOCAL_CONTAINER" mysqldump \
    -u "$SOURCE_USER" -p"$SOURCE_PASS" \
    --max-allowed-packet=1G \
    --single-transaction \
    --routines --triggers --events \
    --set-gtid-purged=OFF \
    --hex-blob \
    --order-by-primary \
    --skip-comments \
    --skip-add-drop-table \
    --disable-keys \
    "$SOURCE_DB" > "$TEMP_DUMP"

echo "--- 3. Importing into $TARGET_DB ---"
cat "$TEMP_DUMP" | docker exec -i "$LOCAL_CONTAINER" mysql \
    --binary-mode \
    --compress \
    -h "$TARGET_HOST" \
    -u "$TARGET_MYSQL_USER" -p"$TARGET_MYSQL_PASS" \
    $SSL_OPTS \
    "$TARGET_DB"

echo "--- 4. Cloning completed successfully ---"
echo "$SOURCE_DB → $TARGET_DB"