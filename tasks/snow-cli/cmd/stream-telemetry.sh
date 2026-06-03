#!/usr/bin/env bash
set -euo pipefail

# Streams simulated vehicle telemetry via Snowpipe Streaming SDK.
# Ensures a virtual environment exists and dependencies are installed before running.
# Usage: ./stream-telemetry.sh [EVENT_COUNT]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYUTIL_DIR="$SCRIPT_DIR/../pyutil/snowpipe_streaming"
VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/../../../.venv}"
REQUIREMENTS_FILE="$PYUTIL_DIR/requirements.txt"
EVENT_COUNT="${1:-100}"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
# shellcheck disable=SC1091
. "$VENV_DIR/bin/activate"

# Install dependencies (pip is fast when everything is already installed)
pip install --quiet -r "$REQUIREMENTS_FILE"

# Run the streaming script
python3 "$PYUTIL_DIR/stream_telemetry.py" --events "$EVENT_COUNT"
