#!/usr/bin/env bash
set -euo pipefail

# Launches the Spark + Horizon REST catalog interop notebook in Jupyter.
# Ensures a virtual environment exists and dependencies are installed before running.
# Mirrors cmd/stream-telemetry.sh (uv/venv pattern; no conda).
# Usage: ./run-spark-jupyter.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPARK_DIR="$SCRIPT_DIR/../pyutil/spark"
VENV_DIR="${SPARK_VENV_DIR:-$SCRIPT_DIR/../../../.venv-spark}"
REQUIREMENTS_FILE="$SPARK_DIR/requirements.txt"
NOTEBOOK="${SPARK_NOTEBOOK_PATH:-$SPARK_DIR/spark_iceberg_interop.ipynb}"

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

# pyspark 4.0 requires Java 17+.
if ! command -v java &>/dev/null; then
    echo "WARNING: java not found on PATH. Apache Spark 4.0 requires Java 17+." >&2
fi

# Launch Jupyter on the interop notebook
jupyter notebook "$NOTEBOOK"
