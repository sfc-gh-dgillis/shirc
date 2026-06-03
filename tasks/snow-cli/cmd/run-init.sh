#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_DIR"
    echo "Example: $0 sql/init"
    exit 1
fi

SQL_DIR="$1"
SQL_FILE="$SQL_DIR/init.sql"

# Determine mode-specific SQL file
if [ "${STORAGE_MODE:-managed}" = "external" ]; then
    STORAGE_SQL_FILE="$SQL_DIR/init_storage_external.sql"
else
    STORAGE_SQL_FILE="$SQL_DIR/init_storage_managed.sql"
fi

# Check if SQL files exist
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi
if [ ! -f "$STORAGE_SQL_FILE" ]; then
    echo "Error: Storage mode SQL file not found at $STORAGE_SQL_FILE"
    exit 1
fi

# Check if required environment variables are set
# These override the defaults in snowflake.yml via Snow CLI ctx.env resolution.
REQUIRED_VARS=(
    "STORAGE_MODE"
    "DEMO_WAREHOUSE_NAME"
    "DEMO_DATABASE_NAME"
    "DEMO_DATABASE_DDL_COMMENT"
    "DEMO_SCHEMA_NAME_BRONZE"
    "DEMO_SCHEMA_NAME_SILVER"
    "DEMO_SCHEMA_NAME_GOLD"
    "DEMO_INTERNAL_NAMED_STAGE"
    "DEMO_ENGINEER_ROLE_NAME"
)

# External mode requires additional vars
if [ "$STORAGE_MODE" = "external" ]; then
    REQUIRED_VARS+=("EXTERNAL_VOLUME_NAME")
fi

MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        MISSING_VARS+=("$VAR")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "Error: Missing required environment variables:"
    for VAR in "${MISSING_VARS[@]}"; do
        echo "  - $VAR"
    done
    exit 1
fi

# Resolve the authenticated Snowflake user dynamically
DEMO_SETUP_USER=$(snow sql -q "SELECT CURRENT_USER()" --format JSON 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['CURRENT_USER()'])")

if [ -z "$DEMO_SETUP_USER" ]; then
    echo "Error: Could not resolve current Snowflake user"
    exit 1
fi
export DEMO_SETUP_USER

echo "Running Snowflake initialization..."
echo "  Storage Mode:  $STORAGE_MODE"
echo "  Warehouse:     $DEMO_WAREHOUSE_NAME"
if [ "$STORAGE_MODE" = "external" ]; then
echo "  Ext Volume:    $EXTERNAL_VOLUME_NAME"
else
echo "  Ext Volume:    SNOWFLAKE_MANAGED"
fi
echo "  Database:      $DEMO_DATABASE_NAME"
echo "  Schemas:       $DEMO_SCHEMA_NAME_BRONZE / $DEMO_SCHEMA_NAME_SILVER / $DEMO_SCHEMA_NAME_GOLD"
echo "  Stage:         $DEMO_INTERNAL_NAMED_STAGE"
echo "  Engineer Role: $DEMO_ENGINEER_ROLE_NAME"
echo "  Setup User:    $DEMO_SETUP_USER (auto-detected)"
echo ""

# Run shared init (warehouse, roles, users, database, schemas, grants, stage)
echo "==> Running: $SQL_FILE"
snow sql -f "$SQL_FILE"

# Run mode-specific storage configuration
echo ""
echo "==> Running: $STORAGE_SQL_FILE"
snow sql -f "$STORAGE_SQL_FILE"

echo ""
echo "Initialization completed successfully"
