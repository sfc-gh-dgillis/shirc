#!/usr/bin/env bash
set -euo pipefail

# Generates a Snowflake notebook from a template by substituting variables
# Usage: ./generate-notebook.sh TEMPLATE_FILE OUTPUT_FILE

if [ $# -lt 2 ]; then
    echo "Usage: $0 TEMPLATE_FILE OUTPUT_FILE"
    echo "Example: $0 notebook/snowflake_iceberg_v3_template.ipynb ../../output/snowflake_iceberg_v3_demo_notebook.ipynb"
    exit 1
fi

TEMPLATE_FILE="$1"
OUTPUT_FILE="$2"

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Run the Python script to generate the notebook
python3 cmd/generate-notebook.py --template "$TEMPLATE_FILE" --output "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "Notebook generated successfully: $OUTPUT_FILE"
else
    echo ""
    echo "Failed to generate notebook"
    exit 1
fi
