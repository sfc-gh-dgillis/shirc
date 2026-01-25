#!/usr/bin/env bash
set -euo pipefail

# Generates a trust policy document from a template
# Usage: ./generate-trust-policy.sh TEMPLATE_FILE OUTPUT_FILE

if [ $# -lt 2 ]; then
    echo "Usage: $0 TEMPLATE_FILE OUTPUT_FILE"
    echo "Example: $0 tasks/aws-cli/json/template/trust-policy-template.json tasks/aws-cli/json/output/trust-policy-output.json"
    exit 1
fi

TEMPLATE_FILE="$1"
OUTPUT_FILE="$2"

python3 tasks/aws-cli/cmd/generate-trust-policy.py -t "$TEMPLATE_FILE" -o "$OUTPUT_FILE"
