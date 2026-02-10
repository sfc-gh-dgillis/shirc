#!/usr/bin/env bash
set -euo pipefail

if ! command -v conda &>/dev/null; then
  echo "conda is not installed."
  echo "To install conda, see: https://docs.conda.io/en/latest/miniconda.html"
  exit 1
fi

echo "conda is installed: $(conda --version)"
