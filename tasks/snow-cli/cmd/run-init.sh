#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE"
    echo "Example: $0 tasks/snow-cli/sql/batch-1/001-init.sql"
    exit 1
fi

SQL_FILE="$1"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

# Check if required environment variables are set
# These override the defaults in snowflake.yml via Snow CLI ctx.env resolution.
REQUIRED_VARS=(
    "DEMO_WAREHOUSE_NAME"
    "DEMO_DATABASE_NAME"
    "DEMO_DATABASE_DDL_COMMENT"
    "DEMO_SCHEMA_NAME"
    "DEMO_INTERNAL_NAMED_STAGE"
    "DEMO_ENGINEER_ROLE_NAME"
    "DEMO_ENGINEER_USER_NAME"
    "EXTERNAL_VOLUME_NAME"
)

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

echo "Running Snowflake initialization script..."
echo "  Warehouse: $DEMO_WAREHOUSE_NAME"
echo "  External Volume: $EXTERNAL_VOLUME_NAME"
echo "  Stage Name: $DEMO_INTERNAL_NAMED_STAGE"
echo "  Engineer Role: $DEMO_ENGINEER_ROLE_NAME"
echo "  Engineer User: $DEMO_ENGINEER_USER_NAME"
echo "  Setup User: $DEMO_SETUP_USER (auto-detected)"
echo ""

# Run snow CLI — variables resolved via ctx.env from snowflake.yml + shell env overrides
snow sql -f "$SQL_FILE"

# Check if command was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "Initialization completed successfully"
    echo "Database: $DEMO_DATABASE_NAME"
    echo "Role: $DEMO_ENGINEER_ROLE_NAME"
    echo "User: $DEMO_ENGINEER_USER_NAME"
else
    echo ""
    echo "Initialization failed"
    exit 1
fi
