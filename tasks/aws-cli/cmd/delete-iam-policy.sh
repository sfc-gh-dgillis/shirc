#!/usr/bin/env bash
set -euo pipefail

# Path to the JSON output file
JSON_FILE="tasks/aws-cli/json/aws-output.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file not found at $JSON_FILE"
    exit 1
fi

# Extract the policy ARN from the JSON file
POLICY_ARN=$(jq -r '.iam_policy.Policy.Arn // empty' "$JSON_FILE")

# Check if policy ARN was found
if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "null" ]; then
    echo "Warning: No IAM policy ARN found in $JSON_FILE"
    echo "Nothing to delete."
    exit 0
fi

echo "Found policy ARN: $POLICY_ARN"

# Check if the policy exists in AWS
echo "Checking if policy exists..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "Warning: Policy $POLICY_ARN does not exist or is not accessible"
    echo "Nothing to delete."
    exit 0
fi

# Get the policy name for display
POLICY_NAME=$(echo "$POLICY_ARN" | awk -F'/' '{print $NF}')
echo "Policy name: $POLICY_NAME"

# Check if the policy is attached to any entities
echo "Checking for policy attachments..."
ATTACHMENT_COUNT=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.AttachmentCount' --output text)

if [ "$ATTACHMENT_COUNT" -gt 0 ]; then
    echo "Warning: Policy is attached to $ATTACHMENT_COUNT entity/entities"
    echo "Policy cannot be deleted while attached."
    echo ""
    echo "To detach the policy, run:"
    echo "  aws iam list-entities-for-policy --policy-arn $POLICY_ARN"
    echo "Then detach from users/roles/groups before deleting."
    exit 1
fi

# Delete all policy versions except the default
echo "Checking for non-default policy versions..."
VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?!IsDefaultVersion].VersionId' --output text)

if [ -n "$VERSIONS" ]; then
    echo "Deleting non-default policy versions..."
    for VERSION in $VERSIONS; do
        echo "  Deleting version: $VERSION"
        aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$VERSION"
    done
fi

# Delete the policy
echo "Deleting IAM policy: $POLICY_NAME"
aws iam delete-policy --policy-arn "$POLICY_ARN"

# Check if deletion was successful
if [ $? -eq 0 ]; then
    echo "IAM policy deleted successfully: $POLICY_NAME"
    echo "   ARN: $POLICY_ARN"
else
    echo "Failed to delete IAM policy"
    exit 1
fi
