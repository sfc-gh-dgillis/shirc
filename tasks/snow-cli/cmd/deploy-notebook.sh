#!/usr/bin/env bash
set -euo pipefail

# Deploys a notebook to Snowflake using the Snow CLI
# Usage: ./deploy-notebook.sh NOTEBOOK_FILE

if [ $# -lt 1 ]; then
    echo "Usage: $0 NOTEBOOK_FILE"
    echo "Example: $0 ../../output/snowflake_iceberg_v3_demo_notebook.ipynb"
    exit 1
fi

NOTEBOOK_FILE="$1"

# Check if notebook file exists
if [ ! -f "$NOTEBOOK_FILE" ]; then
    echo "Error: Notebook file not found at $NOTEBOOK_FILE"
    exit 1
fi

echo "Deploying notebook to Snowflake..."
echo "  Notebook: $NOTEBOOK_FILE"
echo ""

# Deploy the notebook using snow CLI
snow notebook deploy "$NOTEBOOK_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "Notebook deployed successfully"
else
    echo ""
    echo "Failed to deploy notebook"
    exit 1
fi
