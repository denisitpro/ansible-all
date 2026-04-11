#!/bin/bash
# =============================================================================
# Required variables:
#   TARGET_HOST             — Remote MySQL server IP or hostname
#   MYSQL_ADMIN_USER        — Privileged MySQL user (e.g. root or admin with CREATE USER privilege)
#   MYSQL_ADMIN_PASS        — Password for the admin user
#   APP_MYSQL_USER          — Application username to create/change
#   APP_MYSQL_PASS          — New password for the application user
#
# Optional variables:
#   LOCAL_CONTAINER=mysql   — Name of local Docker container with mysql client (default: mysql)
#   APP_MYSQL_HOST=%        — Allowed host for the user (default: % = any host)
#   APP_MYSQL_DBS           — Comma-separated list of databases to grant access to
#   GRANT_DB_RIGHTS=no      — Set to "yes" to grant privileges on specified databases
#
# Usage examples (run from the server where the script and local MySQL container are located):
# 1. Minimal: just change/create user password (no database grants)
# TARGET_HOST=remote.db.host MYSQL_ADMIN_USER=admin MYSQL_ADMIN_PASS='adminpass' APP_MYSQL_USER=app_user APP_MYSQL_PASS='StrongPass2025!' ./mql-change-pass.sh
#
# 2. Create user and grant access to multiple databases
# TARGET_HOST=remote.db.host MYSQL_ADMIN_USER=admin MYSQL_ADMIN_PASS='adminpass' APP_MYSQL_USER=app_user APP_MYSQL_DBS=db1,db2,db3 GRANT_DB_RIGHTS=yes APP_MYSQL_PASS='StrongPass2025!' ./mql-change-pass.sh
#
# =============================================================================

set -euo pipefail

# Required variables
TARGET_HOST="${TARGET_HOST:?Error: TARGET_HOST not specified}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:?Error: MYSQL_ADMIN_USER not specified}"
MYSQL_ADMIN_PASS="${MYSQL_ADMIN_PASS:?Error: MYSQL_ADMIN_PASS not specified}"
APP_MYSQL_USER="${APP_MYSQL_USER:?Error: APP_MYSQL_USER not specified}"
APP_MYSQL_PASS="${APP_MYSQL_PASS:?Error: APP_MYSQL_PASS not specified}"

# Optional variables
LOCAL_CONTAINER="${LOCAL_CONTAINER:-mysql}"
APP_MYSQL_HOST="${APP_MYSQL_HOST:-%}"
APP_MYSQL_DBS_RAW="${APP_MYSQL_DBS:-}"
GRANT_DB_RIGHTS="${GRANT_DB_RIGHTS:-no}"

echo "=== Changing/creating MySQL application user on $TARGET_HOST (via local container $LOCAL_CONTAINER) ==="
echo "Administrator: $MYSQL_ADMIN_USER"
echo "Application user: '$APP_MYSQL_USER'@'$APP_MYSQL_HOST'"

# Process database list for grants
if [[ -n "$APP_MYSQL_DBS_RAW" && "$GRANT_DB_RIGHTS" == "yes" ]]; then
    IFS=',' read -ra TARGET_DBS <<< "$(echo "$APP_MYSQL_DBS_RAW" | tr -d ' ')"
    echo "Will grant privileges on ${#TARGET_DBS[@]} database(s): ${TARGET_DBS[*]}"
else
    TARGET_DBS=()
    echo "Database grants disabled or no databases specified"
fi

# Escape single quotes in password
ESCAPED_APP_PASS="${APP_MYSQL_PASS//'/\'}"

# Function to run mysql via local Docker container
run_mysql() {
    docker exec -i "$LOCAL_CONTAINER" mysql -h"$TARGET_HOST" -u"$MYSQL_ADMIN_USER" -p"$MYSQL_ADMIN_PASS" --batch --skip-column-names "$@"
}

# Try to change password (if user exists)
echo "Attempting to change password for existing user..."
if run_mysql -e "ALTER USER '$APP_MYSQL_USER'@'$APP_MYSQL_HOST' IDENTIFIED BY '$ESCAPED_APP_PASS'; FLUSH PRIVILEGES;"
then
    echo "Password successfully changed for existing user."
    USER_CREATED=false
else
    echo "User '$APP_MYSQL_USER'@'$APP_MYSQL_HOST' does not exist."
    echo "Creating new user..."
    run_mysql -e "CREATE USER '$APP_MYSQL_USER'@'$APP_MYSQL_HOST' IDENTIFIED BY '$ESCAPED_APP_PASS'; FLUSH PRIVILEGES;"
    echo "User successfully created with new password."
    USER_CREATED=true
fi

# Grant privileges on databases
if [[ ${#TARGET_DBS[@]} -gt 0 ]]; then
    echo "Granting SELECT, INSERT, UPDATE, DELETE privileges on specified databases..."
    for db in "${TARGET_DBS[@]}"; do
        echo " → GRANT on database: $db"
        run_mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE ON \`$db\`.* TO '$APP_MYSQL_USER'@'$APP_MYSQL_HOST';"
    done
    run_mysql -e "FLUSH PRIVILEGES;"
    echo "Privileges successfully granted on ${#TARGET_DBS[@]} database(s)."
fi

echo "=== Operation completed successfully! ==="
if [[ "$USER_CREATED" == true ]]; then
    echo "New user created: $APP_MYSQL_USER@$APP_MYSQL_HOST with password: $APP_MYSQL_PASS"
else
    echo "Password changed for existing user"
fi
[[ ${#TARGET_DBS[@]} -gt 0 ]] && echo "Privileges granted on databases: ${TARGET_DBS[*]}"
echo "New password: $APP_MYSQL_PASS"
echo "Save it securely and update your application config!"