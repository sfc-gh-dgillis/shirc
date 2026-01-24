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

# Define output paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/bucket.log"
AWS_OUTPUT_FILE="$BASE_DIR/json/aws-output.json"

# Create the bucket
echo "Creating bucket $BUCKET_NAME in region $REGION..."
aws s3 mb "s3://${BUCKET_NAME}" --region "$REGION"

# Check if creation was successful
if [ $? -eq 0 ]; then
    echo "Bucket s3://${BUCKET_NAME} created successfully"

    # Capture URI and ARN
    BUCKET_URI="s3://${BUCKET_NAME}"
    BUCKET_ARN="arn:aws:s3:::${BUCKET_NAME}"

    # Write to log file
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - Bucket created" >> "$LOG_FILE"
    echo "URI: $BUCKET_URI" >> "$LOG_FILE"
    echo "ARN: $BUCKET_ARN" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"

    echo "Logged bucket info to $LOG_FILE"

    # Write to aws-output.json
    cat > "$AWS_OUTPUT_FILE" << EOF
{
  "bucket_uri": "$BUCKET_URI",
  "bucket_arn": "$BUCKET_ARN"
}
EOF

    echo "Wrote output to $AWS_OUTPUT_FILE"
else
    echo "Failed to create bucket"
    exit 1
fi
