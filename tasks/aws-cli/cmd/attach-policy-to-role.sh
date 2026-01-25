#!/usr/bin/env bash
set -euo pipefail

# Attaches an IAM policy to a role using ARNs from aws-output.json
# Usage: ./attach-policy-to-role.sh

# Define input path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AWS_OUTPUT_FILE="$BASE_DIR/json/aws-output.json"

# Verify aws-output.json exists
if [ ! -f "$AWS_OUTPUT_FILE" ]; then
    echo "Error: $AWS_OUTPUT_FILE not found"
    exit 1
fi

# Extract policy ARN and role name from aws-output.json
POLICY_ARN=$(jq -r '.iam_policy.Policy.Arn' "$AWS_OUTPUT_FILE")
ROLE_NAME=$(jq -r '.iam_role.Role.RoleName' "$AWS_OUTPUT_FILE")

if [ "$POLICY_ARN" = "null" ] || [ -z "$POLICY_ARN" ]; then
    echo "Error: Could not find policy ARN in $AWS_OUTPUT_FILE"
    exit 1
fi

if [ "$ROLE_NAME" = "null" ] || [ -z "$ROLE_NAME" ]; then
    echo "Error: Could not find role name in $AWS_OUTPUT_FILE"
    exit 1
fi

echo "Attaching policy '$POLICY_ARN' to role '$ROLE_NAME'..."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"

echo "Policy attached successfully."
