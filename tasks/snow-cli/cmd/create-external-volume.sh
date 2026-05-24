#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE"
    echo "Example: $0 sql/infra-up-external/001-create_external_volume.sql"
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
    "EXTERNAL_VOLUME_NAME"
    "S3_PREFIX"
    "TRUST_POLICY_EXTERNAL_ID"
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

# Path to the JSON output file
JSON_FILE="../../output/aws-output.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    echo "Please run 'task aws-resources-up' first to create AWS resources."
    exit 1
fi

# Extract IAM role ARN from aws-output.json
STORAGE_AWS_ROLE_ARN=$(jq -r '.iam_role.Role.Arn // empty' "$JSON_FILE")
BUCKET_URI=$(jq -r '.bucket_uri // empty' "$JSON_FILE")

# Check if values were extracted
if [ -z "$STORAGE_AWS_ROLE_ARN" ] || [ "$STORAGE_AWS_ROLE_ARN" = "null" ]; then
    echo "Error: No IAM role ARN found in $JSON_FILE"
    exit 1
fi

if [ -z "$BUCKET_URI" ] || [ "$BUCKET_URI" = "null" ]; then
    echo "Error: No bucket URI found in $JSON_FILE"
    exit 1
fi

# Construct storage base URL with S3 prefix
if [ -n "${S3_PREFIX:-}" ]; then
    STORAGE_BASE_URL="${BUCKET_URI}/${S3_PREFIX}/"
else
    STORAGE_BASE_URL="${BUCKET_URI}/"
fi

# Export derived values so Snow CLI can resolve them via ctx.env
export STORAGE_BASE_URL
export STORAGE_AWS_ROLE_ARN

echo "Creating Snowflake external volume..."
echo "  External Volume Name: $EXTERNAL_VOLUME_NAME"
echo "  Storage Base URL: $STORAGE_BASE_URL"
echo "  IAM Role ARN: $STORAGE_AWS_ROLE_ARN"
echo "  External ID: $TRUST_POLICY_EXTERNAL_ID"
echo ""

# Run snow CLI — variables resolved via ctx.env from snowflake.yml + shell env overrides
snow sql -f "$SQL_FILE"

# Check if creation was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "External volume created successfully: $EXTERNAL_VOLUME_NAME"
else
    echo ""
    echo "Failed to create external volume"
    exit 1
fi
