#!/bin/bash
set -euo pipefail

ENV_NAME="${1:?Error: conda environment name required as first argument}"

if conda env list | grep -q "^$ENV_NAME "; then
  echo "Removing conda environment '$ENV_NAME'..."
  conda env remove -n "$ENV_NAME" -y
  echo "Environment '$ENV_NAME' removed successfully"
else
  echo "Environment '$ENV_NAME' does not exist"
fi
