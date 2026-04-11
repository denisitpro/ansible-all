#!/bin/bash
# =============================================================================
#
# BEFORE FIRST RUN YOU MUST:
# 1. Configure rclone remote "backblaze" for Backblaze B2
#    rclone config → New remote → Name: backblaze → Type: b2
#    Введите Account ID (ApplicationKeyId) и Application Key
# 2. docker login (if using private image c4telegraph/percona-xtrabackup)
#
# After that — script runs automatically
#
# =============================================================================

set -e

DOCKER_DIR="/opt/docker/mysql"
DATA_DIR="/opt/mysql/db"
TMP_BACKUP="/tmp/mysql_dump.tar"
TMP_EXTRACT="/tmp/backup"


RCLONE_REMOTE="backblaze:sanctum-7d-15/mysql-cluster-02"

XTRABACKUP_IMAGE="c4telegraph/percona-xtrabackup:2.4.29"
TODAY=$(date +%Y-%m-%d)

echo "=== $(date) === Starting MySQL restore from XtraBackup (Backblaze B2) ==="

cd "$DOCKER_DIR"
docker compose stop mysql || true

echo "Cleaning old data..."
rm -rf "$DATA_DIR"/* "$TMP_BACKUP" "$TMP_EXTRACT" /tmp/mysql_cluster2_*.xtrabackup.tar 2>/dev/null || true
mkdir -p "$DATA_DIR" "$TMP_EXTRACT"

echo "Downloading backup via rclone (with progress)..."
rm -f "$TMP_BACKUP"


if rclone lsf "$RCLONE_REMOTE/mysql_cluster2_${TODAY}.xtrabackup.tar" >/dev/null 2>&1; then
    echo "Found today's backup: mysql_cluster2_${TODAY}.xtrabackup.tar"
    rclone copy -P "$RCLONE_REMOTE/mysql_cluster2_${TODAY}.xtrabackup.tar" /tmp/
else
    echo "Today's backup missing → taking latest available..."
    LATEST=$(rclone lsf "$RCLONE_REMOTE/" | grep 'xtrabackup.tar$' | sort | tail -n1 | awk '{print $NF}')
    if [[ -z "$LATEST" ]]; then
        echo "ERROR: No backup files found in $RCLONE_REMOTE/"
        exit 1
    fi
    rclone copy -P "$RCLONE_REMOTE/$LATEST" /tmp/
    echo "Downloaded latest: $LATEST"
fi


mv /tmp/mysql_cluster2_*.xtrabackup.tar "$TMP_BACKUP" || {
    echo "ERROR: Backup file not found in /tmp!"
    exit 1
}

echo "Extracting archive..."
tar -xf "$TMP_BACKUP" -C "$TMP_EXTRACT" --strip-components=2 --wildcards '*/xtra/*'

echo "Decompressing .qp files..."
docker run --rm -u root -v "$TMP_EXTRACT:/backup" "$XTRABACKUP_IMAGE" \
    xtrabackup --decompress --target-dir=/backup

echo "Removing .qp files..."
find "$TMP_EXTRACT" -name '*.qp' -delete

echo "Preparing backup (apply-log)..."
docker run --rm -u root -v "$TMP_EXTRACT:/backup" "$XTRABACKUP_IMAGE" \
    xtrabackup --prepare --target-dir=/backup

echo "Deploying restored data..."
rm -rf "$DATA_DIR"/*
mv "$TMP_EXTRACT/"* "$DATA_DIR/"
chown -R 999:999 "$DATA_DIR"

echo "Starting MySQL..."
docker compose up -d mysql

echo "Final cleanup..."
rm -f "$TMP_BACKUP"
rm -rf "$TMP_EXTRACT"

echo "=== $(date) === SUCCESS! MySQL fully restored and running ==="

MYSQL_USER="${1:-}"
MYSQL_PASS="${2:-}"

if [[ -z "$MYSQL_USER" || -z "$MYSQL_PASS" ]]; then
    echo ""
    echo "ℹ️  To run mysql_upgrade, provide credentials:"
    echo "Usage: $0 <mysql_user> <mysql_password>"
    echo "Example: $0 root MySecretPass123"
    echo "Skipping mysql_upgrade..."
    exit 0
fi

echo ""
echo "Running mysql_upgrade for user '$MYSQL_USER'..."
docker exec mysql mysql_upgrade -u"$MYSQL_USER" -p"$MYSQL_PASS" --force || {
    echo "Warning: mysql_upgrade failed or not needed (often normal)"
}

echo "Restarting MySQL container..."
cd "$DOCKER_DIR"
docker compose restart mysql

echo "=== All done! MySQL restored and upgraded ==="