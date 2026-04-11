#!/bin/bash
# Usage:
# DB_USER= DB_PASS='' ORIGINAL_DB=exampledb TABLES_TO_TRUNCATE="new_posts_history,failed_jobs" ./shrink-db.sh

# DB_USER= DB_PASS='' ORIGINAL_DB=exampledb_stats TABLES_TO_TRUNCATE="facebook_stat, twitter_stat, linkedin_stat, reddit_stat, gplus_stat" ./shrink-db.sh
set -euo pipefail

CONTAINER_NAME="mysql" 
DB_USER="${DB_USER:?Set DB_USER}"
DB_PASS="${DB_PASS:?Set DB_PASS}"
ORIGINAL_DB="${ORIGINAL_DB:?Set ORIGINAL_DB}"
SMALL_DB="small_${ORIGINAL_DB}"
TEMP_DUMP="/tmp/shrink_dump_$$.sql"

trap 'rm -f "$TEMP_DUMP"' EXIT


TABLES_TO_TRUNCATE_RAW="${TABLES_TO_TRUNCATE:-}"
if [[ -z "$TABLES_TO_TRUNCATE_RAW" ]]; then
    echo "TABLES_TO_TRUNCATE is not set — no tables will be truncated"
    TABLES_TO_TRUNCATE=()
else
    IFS=',' read -ra TABLES_TO_TRUNCATE <<< "$(echo "$TABLES_TO_TRUNCATE_RAW" | tr -d ' ')"
fi

echo "Creating small version of database $ORIGINAL_DB → $SMALL_DB"
[[ ${#TABLES_TO_TRUNCATE[@]} -gt 0 ]] && echo "Tables to be truncated (cleared): ${TABLES_TO_TRUNCATE[*]}"

# 1. Full database dump
echo "Dumping database $ORIGINAL_DB..."
docker exec -i "$CONTAINER_NAME" mysqldump -u"$DB_USER" -p"$DB_PASS" \
    --max-allowed-packet=1G \
    --single-transaction --quick \
    --routines --events --triggers \
    "$ORIGINAL_DB" > "$TEMP_DUMP"

# 2. Drop and create small database
echo "Dropping and creating database $SMALL_DB..."
docker exec "$CONTAINER_NAME" mysql -u"$DB_USER" -p"$DB_PASS" -e \
    "DROP DATABASE IF EXISTS \`$SMALL_DB\`; CREATE DATABASE \`$SMALL_DB\`;"

# 3. Restore dump
echo "Restoring dump into $SMALL_DB..."
cat "$TEMP_DUMP" | docker exec -i "$CONTAINER_NAME" mysql -u"$DB_USER" -p"$DB_PASS" "$SMALL_DB"

# 4. Truncate specified tables (clear data, keep table)
if [[ ${#TABLES_TO_TRUNCATE[@]} -gt 0 ]]; then
    echo "Truncating ${#TABLES_TO_TRUNCATE[@]} tables (removing all rows)..."
    for table in "${TABLES_TO_TRUNCATE[@]}"; do
        echo " → TRUNCATE TABLE $table"
        docker exec "$CONTAINER_NAME" mysql -u"$DB_USER" -p"$DB_PASS" "$SMALL_DB" -e \
            "TRUNCATE TABLE \`$table\`;"
    done
fi

echo "Done! Database $SMALL_DB has been created and specified tables are empty."