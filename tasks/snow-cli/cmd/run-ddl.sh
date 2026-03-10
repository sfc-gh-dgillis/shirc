#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE"
    echo "Example: $0 sql/batch-2/001-create-tables.sql"
    exit 1
fi

SQL_FILE="$1"

if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

REQUIRED_VARS=(
    "DEMO_WAREHOUSE_NAME"
    "DEMO_DATABASE_NAME"
    "DEMO_SCHEMA_NAME"
    "DEMO_ENGINEER_ROLE_NAME"
    "INTERNAL_NAMED_STAGE"
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

STAGE_NAME="${INTERNAL_NAMED_STAGE#@}"

echo "Running SQL batch: $SQL_FILE"
echo "  Warehouse:      $DEMO_WAREHOUSE_NAME"
echo "  Database:       $DEMO_DATABASE_NAME"
echo "  Schema:         $DEMO_SCHEMA_NAME"
echo "  Engineer Role:  $DEMO_ENGINEER_ROLE_NAME"
echo "  Stage:          $STAGE_NAME"
echo ""

snow sql -f "$SQL_FILE" \
  --enable-templating JINJA \
  -D demo_warehouse_name="$DEMO_WAREHOUSE_NAME" \
  -D demo_database_name="$DEMO_DATABASE_NAME" \
  -D demo_schema_name="$DEMO_SCHEMA_NAME" \
  -D demo_engineer_role_name="$DEMO_ENGINEER_ROLE_NAME" \
  -D demo_stage_name="$STAGE_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "Completed successfully: $SQL_FILE"
else
    echo ""
    echo "Failed: $SQL_FILE"
    exit 1
fi
