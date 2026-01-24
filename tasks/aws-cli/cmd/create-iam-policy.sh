#!/usr/bin/env bash
set -euo pipefail

# Creates an IAM policy and adds the response to aws-output.json
# Usage: ./create-iam-policy.sh POLICY_NAME POLICY_DOCUMENT

if [ $# -lt 2 ]; then
    echo "Usage: $0 POLICY_NAME POLICY_DOCUMENT"
    echo "Example: $0 my-policy ./policy.json"
    exit 1
fi

POLICY_NAME="$1"
POLICY_DOCUMENT="$2"

# Define output path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AWS_OUTPUT_FILE="$BASE_DIR/json/aws-output.json"

# Create the IAM policy and capture the response
echo "Creating IAM policy '$POLICY_NAME'..."
RESPONSE=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "file://$POLICY_DOCUMENT")

echo "IAM policy created successfully."
echo "$RESPONSE"

# Initialize aws-output.json if it doesn't exist
if [ ! -f "$AWS_OUTPUT_FILE" ]; then
    echo "{}" > "$AWS_OUTPUT_FILE"
fi

# Add the response to aws-output.json under the iam_policy field
UPDATED=$(jq --argjson policy "$RESPONSE" '.iam_policy = $policy' "$AWS_OUTPUT_FILE")
echo "$UPDATED" > "$AWS_OUTPUT_FILE"

echo ""
echo "Policy response saved to '$AWS_OUTPUT_FILE' under 'iam_policy' field."
