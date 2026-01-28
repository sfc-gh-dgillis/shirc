#!/usr/bin/env python3
"""
Generates a Snowflake notebook from a template by substituting Jinja variables.

Usage:
    python3 generate-notebook.py --template <template.ipynb> --output <output.ipynb>

Environment variables used for substitution:
    - WAREHOUSE_NAME
    - DEMO_ENGINEER_ROLE_NAME
    - DEMO_DATABASE_NAME
    - EXTERNAL_VOLUME_NAME
    - INTERNAL_NAMED_STAGE
"""

import argparse
import json
import os
import sys
from pathlib import Path


def get_required_env(var_name: str) -> str:
    """Get a required environment variable or exit with error."""
    value = os.environ.get(var_name)
    if not value:
        print(f"Error: {var_name} environment variable not set")
        sys.exit(1)
    return value


def substitute_variables(text: str, variables: dict) -> str:
    """Substitute Jinja-style variables in text."""
    result = text
    for key, value in variables.items():
        # Replace {{ variable_name }} with the value
        result = result.replace(f"{{{{ {key} }}}}", value)
    return result


def generate_notebook(template_path: Path, output_path: Path, variables: dict) -> None:
    """Read template notebook, substitute variables, and write output."""
    # Read template
    with open(template_path, 'r') as f:
        notebook = json.load(f)

    # Process each cell
    for cell in notebook.get('cells', []):
        if 'source' in cell:
            # source can be a list of strings or a single string
            if isinstance(cell['source'], list):
                cell['source'] = [substitute_variables(line, variables) for line in cell['source']]
            else:
                cell['source'] = substitute_variables(cell['source'], variables)

    # Create output directory if needed
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Write output notebook
    with open(output_path, 'w') as f:
        json.dump(notebook, f, indent=1)

    print(f"Generated notebook: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate notebook from template")
    parser.add_argument("--template", "-t", required=True, help="Path to template notebook")
    parser.add_argument("--output", "-o", required=True, help="Output notebook path")
    args = parser.parse_args()

    template_path = Path(args.template)
    output_path = Path(args.output)

    if not template_path.exists():
        print(f"Error: Template not found: {template_path}")
        return 1

    # Get variables from environment
    variables = {
        "warehouse_name": get_required_env("WAREHOUSE_NAME"),
        "demo_engineer_role_name": get_required_env("DEMO_ENGINEER_ROLE_NAME"),
        "demo_database_name": get_required_env("DEMO_DATABASE_NAME"),
        "external_volume_name": get_required_env("EXTERNAL_VOLUME_NAME"),
        "internal_named_stage": get_required_env("INTERNAL_NAMED_STAGE"),
    }

    print("Generating notebook from template...")
    print(f"  Template: {template_path}")
    print(f"  Output: {output_path}")
    print(f"  Warehouse: {variables['warehouse_name']}")
    print(f"  Role: {variables['demo_engineer_role_name']}")
    print(f"  Database: {variables['demo_database_name']}")
    print(f"  External Volume: {variables['external_volume_name']}")
    print(f"  Internal Stage: {variables['internal_named_stage']}")
    print()

    generate_notebook(template_path, output_path, variables)
    return 0


if __name__ == "__main__":
    sys.exit(main())
