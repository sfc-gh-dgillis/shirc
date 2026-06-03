#!/usr/bin/env bash
set -euo pipefail

# Generates a Snowflake notebook from a template using a variables config file.
# Usage: ./generate-notebook-generic.sh TEMPLATE_FILE OUTPUT_FILE VARIABLES_FILE

if [ $# -lt 3 ]; then
    echo "Usage: $0 TEMPLATE_FILE OUTPUT_FILE VARIABLES_FILE"
    echo "Example: $0 notebook/fleet_analytics_template.ipynb notebook/fleet_analytics_notebook/generated/fleet_analytics_notebook.ipynb notebook/fleet_analytics_notebook/variables.json"
    exit 1
fi

TEMPLATE_FILE="$1"
OUTPUT_FILE="$2"
VARIABLES_FILE="$3"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

if [ ! -f "$VARIABLES_FILE" ]; then
    echo "Error: Variables file not found at $VARIABLES_FILE"
    exit 1
fi

python3 cmd/generate-notebook-generic.py --template "$TEMPLATE_FILE" --output "$OUTPUT_FILE" --variables "$VARIABLES_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "Notebook generated successfully: $OUTPUT_FILE"
else
    echo ""
    echo "Failed to generate notebook"
    exit 1
fi
