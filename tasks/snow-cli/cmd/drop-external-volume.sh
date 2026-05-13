#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 EXTERNAL_VOLUME_NAME"
    echo "Example: $0 iceberg_ext_vol"
    exit 1
fi

EXTERNAL_VOLUME_NAME="$1"

# Check if EXTERNAL_VOLUME_NAME is set
if [ -z "$EXTERNAL_VOLUME_NAME" ]; then
    echo "Error: EXTERNAL_VOLUME_NAME not provided"
    exit 1
fi

echo "Dropping Snowflake external volume: $EXTERNAL_VOLUME_NAME"
echo ""

# Run snow CLI with direct query
snow sql --query "DROP EXTERNAL VOLUME IF EXISTS $EXTERNAL_VOLUME_NAME;"

echo ""
echo "External volume dropped successfully: $EXTERNAL_VOLUME_NAME"
