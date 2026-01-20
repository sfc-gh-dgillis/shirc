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
    echo "Bucket s3://${BUCKET_NAME} created successfully"
else
    echo "Failed to create bucket"
    exit 1
fi
