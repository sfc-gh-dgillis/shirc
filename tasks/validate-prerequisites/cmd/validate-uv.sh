#!/usr/bin/env bash

# Validate uv installation
if command -v uv >/dev/null 2>&1; then
  echo "uv is installed: $(uv --version)"
else
  echo "uv is not installed."
  echo "To install uv, run:"
  echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
