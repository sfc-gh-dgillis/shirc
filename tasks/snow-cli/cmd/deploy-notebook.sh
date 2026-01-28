#!/usr/bin/env bash
set -euo pipefail

# Deploys a notebook to Snowflake using the Snow CLI
# Usage: ./deploy-notebook.sh NOTEBOOK_FILE

if [ $# -lt 1 ]; then
    echo "Usage: $0 NOTEBOOK_FILE"
    echo "Example: $0 notebook/iceberg_v3_notebook/iceberg_v3_demo_notebook.ipynb"
    exit 1
fi

NOTEBOOK_FILE="$1"

# Check if notebook file exists
if [ ! -f "$NOTEBOOK_FILE" ]; then
    echo "Error: Notebook file not found at $NOTEBOOK_FILE"
    exit 1
fi

# Get the absolute directory containing the notebook (should have snowflake.yml)
PROJECT_DIR="$(cd "$(dirname "$NOTEBOOK_FILE")" && pwd)"

# Check if snowflake.yml exists in the project directory
if [ ! -f "$PROJECT_DIR/snowflake.yml" ]; then
    echo "Error: snowflake.yml not found in $PROJECT_DIR"
    exit 1
fi

# Extract notebook name without extension for entity ID
NOTEBOOK_NAME="$(basename "$NOTEBOOK_FILE" .ipynb)"

echo "Deploying notebook to Snowflake..."
echo "  Project: $PROJECT_DIR"
echo "  Notebook: $NOTEBOOK_FILE"
echo "  Entity: $NOTEBOOK_NAME"
echo ""

# Deploy the notebook using snow CLI with project path
snow notebook deploy "$NOTEBOOK_NAME" --project "$PROJECT_DIR"

if [ $? -eq 0 ]; then
    echo ""
    echo "Notebook deployed successfully"
else
    echo ""
    echo "Failed to deploy notebook"
    exit 1
fi
