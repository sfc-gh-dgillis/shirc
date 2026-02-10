#!/bin/bash
set -euo pipefail

ENV_NAME="${1:?Error: conda environment name required as first argument}"

[[ -f "environment.yml" ]] || { echo "Error: environment.yml not found. Run from project root." >&2; exit 1; }

echo "Creating conda environment '$ENV_NAME'..."
conda env list | grep -q "$ENV_NAME" && conda env remove -n "$ENV_NAME" -y

conda env create -f environment.yml
echo "Environment '$ENV_NAME' created successfully"
