#!/usr/bin/env bash
set -euo pipefail

# Creates an IAM role and adds the response to aws-output.json
# Usage: ./create-iam-role.sh ROLE_NAME TRUST_POLICY_DOCUMENT

if [ $# -lt 2 ]; then
    echo "Usage: $0 ROLE_NAME TRUST_POLICY_DOCUMENT"
    echo "Example: $0 my-role ./trust-policy.json"
    exit 1
fi

ROLE_NAME="$1"
TRUST_POLICY_DOCUMENT="$2"

# Define output path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AWS_OUTPUT_FILE="$BASE_DIR/json/aws-output.json"

# Create the IAM role and capture the response
echo "Creating IAM role '$ROLE_NAME'..."
RESPONSE=$(aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "file://$TRUST_POLICY_DOCUMENT")

echo "IAM role created successfully."
echo "$RESPONSE"

# Initialize aws-output.json if it doesn't exist
if [ ! -f "$AWS_OUTPUT_FILE" ]; then
    echo "{}" > "$AWS_OUTPUT_FILE"
fi

# Add the response to aws-output.json under the iam_role field
UPDATED=$(jq --argjson role "$RESPONSE" '.iam_role = $role' "$AWS_OUTPUT_FILE")
echo "$UPDATED" > "$AWS_OUTPUT_FILE"

echo ""
echo "Role response saved to '$AWS_OUTPUT_FILE' under 'iam_role' field."
