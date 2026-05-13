#!/usr/bin/env bash
set -euo pipefail

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 EXTERNAL_VOLUME_NAME [OUTPUT_DIR]"
    echo "Example: $0 iceberg_ext_vol output"
    exit 1
fi

EXTERNAL_VOLUME_NAME="$1"
OUTPUT_DIR="${2:-output}"
STORAGE_LOCATION_FILE="${OUTPUT_DIR}/external-volume-desc-storage-location.json"

# Check if EXTERNAL_VOLUME_NAME is set
if [ -z "$EXTERNAL_VOLUME_NAME" ]; then
    echo "Error: EXTERNAL_VOLUME_NAME not provided"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Describing Snowflake external volume: $EXTERNAL_VOLUME_NAME"
echo ""

# Run snow CLI with direct query, capture output in variable
EXT_VOL_DESC=$(snow sql --query "DESC EXTERNAL VOLUME $EXTERNAL_VOLUME_NAME;" --format JSON_EXT)

echo "External volume described successfully"

# Extract STORAGE_LOCATION_1 JSON from the output
echo "Extracting storage location details..."

# Find the element where parent_property = STORAGE_LOCATIONS and property = STORAGE_LOCATION_1
# The property_value is a JSON string that needs to be unquoted
STORAGE_LOCATION_JSON=$(echo "$EXT_VOL_DESC" | jq -r '.[] | select(.parent_property == "STORAGE_LOCATIONS" and .property == "STORAGE_LOCATION_1") | .property_value')

if [ -n "$STORAGE_LOCATION_JSON" ] && [ "$STORAGE_LOCATION_JSON" != "null" ]; then
    # Parse the JSON string and write it as formatted JSON to the file
    echo "$STORAGE_LOCATION_JSON" | jq '.' > "$STORAGE_LOCATION_FILE"
    echo "Storage location details saved to: $STORAGE_LOCATION_FILE"
else
    echo "Warning: Could not find STORAGE_LOCATION_1 in the output"
    exit 1
fi
