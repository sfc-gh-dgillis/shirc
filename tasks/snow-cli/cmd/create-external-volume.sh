#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 SQL_FILE EXTERNAL_VOLUME_NAME"
    echo "Example: $0 tasks/snow-cli/batch-0/external_volume.sql iceberg_ext_vol"
    exit 1
fi

SQL_FILE="$1"
EXTERNAL_VOLUME_NAME="${2:-}"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

# Path to the JSON output file
JSON_FILE="../../tasks/aws-cli/json/aws-output.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    echo "Please run 'task aws-resources-up' first to create AWS resources."
    exit 1
fi

# Extract IAM role ARN from aws-output.json
IAM_ROLE_ARN=$(jq -r '.iam_role.Role.Arn // empty' "$JSON_FILE")
BUCKET_URI=$(jq -r '.bucket_uri // empty' "$JSON_FILE")

# Check if values were extracted
if [ -z "$IAM_ROLE_ARN" ] || [ "$IAM_ROLE_ARN" = "null" ]; then
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

# Check if TRUST_POLICY_EXTERNAL_ID is set
if [ -z "${TRUST_POLICY_EXTERNAL_ID:-}" ]; then
    echo "Error: TRUST_POLICY_EXTERNAL_ID environment variable not set"
    exit 1
fi

# Check if EXTERNAL_VOLUME_NAME is set
if [ -z "$EXTERNAL_VOLUME_NAME" ]; then
    echo "Error: EXTERNAL_VOLUME_NAME not provided"
    exit 1
fi

echo "Creating Snowflake external volume..."
echo "  External Volume Name: $EXTERNAL_VOLUME_NAME"
echo "  Storage Base URL: $STORAGE_BASE_URL"
echo "  IAM Role ARN: $IAM_ROLE_ARN"
echo "  External ID: $TRUST_POLICY_EXTERNAL_ID"
echo ""

# Run snow CLI with templating
snow sql -f "$SQL_FILE" \
  --enable-templating JINJA \
  -D external_volume_name="$EXTERNAL_VOLUME_NAME" \
  -D storage_base_url="$STORAGE_BASE_URL" \
  -D storage_aws_role_arn="$IAM_ROLE_ARN" \
  -D storage_aws_external_id="$TRUST_POLICY_EXTERNAL_ID"

# Check if creation was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "External volume created successfully: $EXTERNAL_VOLUME_NAME"
else
    echo ""
    echo "Failed to create external volume"
    exit 1
fi
