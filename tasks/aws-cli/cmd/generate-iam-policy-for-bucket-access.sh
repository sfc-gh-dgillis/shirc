#!/bin/bash

# Script to add policy to S3 bucket
# Usage: ./create-iam-policy-for-bucket-access.sh BUCKET_NAME TEMPLATE_FILE OUTPUT_FILE [S3_PREFIX]

set -e

# Check if required parameters are provided
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 BUCKET_NAME TEMPLATE_FILE OUTPUT_FILE [S3_PREFIX]"
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket tasks/cmd/json/bucket-policy-template.json bucket-policy.json some/path"
    echo "  $0 my-bucket tasks/cmd/json/bucket-policy-template.json bucket-policy.json"
    exit 1
fi

BUCKET_NAME="$1"
TEMPLATE_FILE="$2"
OUTPUT_FILE="$3"
S3_PREFIX="${4:-}"

# Build the command
CMD="python3 tasks/aws-cli/cmd/generate-iam-policy-for-bucket-access.py \"$BUCKET_NAME\" -t \"$TEMPLATE_FILE\""

# Add prefix flag only if S3_PREFIX is not empty
if [ -n "$S3_PREFIX" ]; then
    CMD="$CMD --prefix \"$S3_PREFIX\""
fi

CMD="$CMD --output \"$OUTPUT_FILE\""

# Execute the command
eval "$CMD"
if [ $? -eq 0 ]; then
    echo "IAM Policy output file '$OUTPUT_FILE' generated successfully."
else
    echo "Failed to generate policy IAM Policy file."
    exit 1
fi