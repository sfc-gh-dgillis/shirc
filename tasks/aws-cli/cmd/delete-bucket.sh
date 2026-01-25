#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 BUCKET_NAME [--force]"
    echo "Example: $0 my-bucket --force"
    exit 1
fi

# Set bucket name from first argument
BUCKET_NAME="$1"

# Check for force flag
FORCE_FLAG=""
if [ "${2:-}" = "--force" ]; then
    FORCE_FLAG="--force"
fi

# Remove s3:// prefix if provided
BUCKET_NAME="${BUCKET_NAME#s3://}"

# Check if bucket exists
echo "Checking if bucket s3://${BUCKET_NAME} exists..."
if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "Warning: Bucket s3://${BUCKET_NAME} does not exist or is not accessible"
    echo "Nothing to delete."
    exit 0
fi

# Delete the bucket
echo "Deleting bucket s3://${BUCKET_NAME}..."
if [ -n "$FORCE_FLAG" ]; then
    echo "Force flag detected - will remove all objects in bucket"
fi

aws s3 rb "s3://${BUCKET_NAME}" $FORCE_FLAG

# Check if deletion was successful
if [ $? -eq 0 ]; then
    echo "Bucket s3://${BUCKET_NAME} deleted successfully"
else
    echo "Failed to delete bucket"
    exit 1
fi
