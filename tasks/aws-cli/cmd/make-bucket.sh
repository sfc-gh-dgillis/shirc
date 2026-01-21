#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 BUCKET_NAME [REGION]"
    echo "Example: $0 my-bucket ap-south-1"
    exit 1
fi

# Set bucket name from first argument
BUCKET_NAME="$1"
# Set region from second argument or default to us-east-1
REGION="${2:-us-east-1}"

# Remove s3:// prefix if provided
BUCKET_NAME="${BUCKET_NAME#s3://}"

# Create the bucket
echo "Creating bucket $BUCKET_NAME in region $REGION..."
aws s3 mb "s3://${BUCKET_NAME}" --region "$REGION"

# Check if creation was successful
if [ $? -eq 0 ]; then
    BUCKET_URI="s3://${BUCKET_NAME}"
    BUCKET_ARN="arn:aws:s3:::${BUCKET_NAME}"
    echo "Bucket ${BUCKET_URI} created successfully"

    # Write bucket URI and ARN to log file
    LOG_DIR="$(dirname "$0")/../logs"
    LOG_FILE="${LOG_DIR}/bucket-creation.log"
    mkdir -p "$LOG_DIR"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') | URI: ${BUCKET_URI} | ARN: ${BUCKET_ARN}" >> "$LOG_FILE"
    echo "Bucket URI and ARN written to ${LOG_FILE}"

    # Write bucket config to JSON file
    JSON_DIR="$(dirname "$0")/../json"
    CONFIG_FILE="${JSON_DIR}/config.json"
    cat > "$CONFIG_FILE" << EOF
{
    "bucket_uri": "${BUCKET_URI}",
    "bucket_arn": "${BUCKET_ARN}"
}
EOF
    echo "Bucket config written to ${CONFIG_FILE}"
else
    echo "Failed to create bucket"
    exit 1
fi
