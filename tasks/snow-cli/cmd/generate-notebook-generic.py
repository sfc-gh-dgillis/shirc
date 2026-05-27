#!/usr/bin/env python3
"""
Generic notebook generator that reads a variable config file and substitutes
Jinja-style placeholders in a template notebook and snowflake.yml.

Usage:
    python3 generate-notebook-generic.py --template <template.ipynb> --output <output.ipynb> --variables <variables.json>

The variables.json file defines a mapping of placeholder names to environment
variables (with optional defaults). See fleet_analytics_notebook/variables.json
for an example.
"""

import argparse
import json
import os
import sys
from pathlib import Path


def load_variables(variables_path: Path) -> dict:
    """Load variable config and resolve values from environment."""
    with open(variables_path, 'r') as f:
        config = json.load(f)

    resolved = {}
    for key, spec in config.get("variables", {}).items():
        env_var = spec.get("env")
        default = spec.get("default")
        value = os.environ.get(env_var, default) if env_var else default
        if value is None:
            print(f"Error: Variable '{key}' has no env var '{env_var}' set and no default")
            sys.exit(1)
        resolved[key] = value

    return resolved, config


def substitute_variables(text: str, variables: dict) -> str:
    """Substitute Jinja-style {{ variable }} placeholders in text."""
    result = text
    for key, value in variables.items():
        result = result.replace(f"{{{{ {key} }}}}", value)
    return result


def generate_notebook(template_path: Path, output_path: Path, variables: dict) -> None:
    """Read template notebook, substitute variables, and write output."""
    with open(template_path, 'r') as f:
        notebook = json.load(f)

    for cell in notebook.get('cells', []):
        if 'source' in cell:
            if isinstance(cell['source'], list):
                cell['source'] = [substitute_variables(line, variables) for line in cell['source']]
            else:
                cell['source'] = substitute_variables(cell['source'], variables)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        json.dump(notebook, f, indent=1)

    print(f"Generated notebook: {output_path}")


def generate_snowflake_yml(template_path: Path, output_path: Path, variables: dict) -> None:
    """Read snowflake.yml template, substitute variables, and write output."""
    with open(template_path, 'r') as f:
        content = f.read()

    content = substitute_variables(content, variables)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        f.write(content)

    print(f"Generated snowflake.yml: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate notebook from template using variable config")
    parser.add_argument("--template", "-t", required=True, help="Path to template notebook (.ipynb)")
    parser.add_argument("--output", "-o", required=True, help="Output notebook path")
    parser.add_argument("--variables", "-v", required=True, help="Path to variables.json config file")
    args = parser.parse_args()

    template_path = Path(args.template)
    output_path = Path(args.output)
    variables_path = Path(args.variables)

    if not template_path.exists():
        print(f"Error: Template not found: {template_path}")
        return 1

    if not variables_path.exists():
        print(f"Error: Variables file not found: {variables_path}")
        return 1

    variables, config = load_variables(variables_path)

    # Add computed variables for snowflake.yml generation
    variables["notebook_file"] = output_path.name
    variables["notebook_file_path"] = str(output_path)

    print("Generating notebook from template...")
    print(f"  Template:  {template_path}")
    print(f"  Output:    {output_path}")
    print(f"  Variables: {variables_path}")
    print(f"  Resolved values:")
    for key, value in variables.items():
        if key not in ("notebook_file", "notebook_file_path"):
            print(f"    {key}: {value}")
    print()

    generate_notebook(template_path, output_path, variables)

    # Generate snowflake.yml if template is specified in config
    yml_template_rel = config.get("snowflake_yml_template")
    if yml_template_rel:
        yml_template_path = (variables_path.parent / yml_template_rel).resolve()
        if yml_template_path.exists():
            yml_output_path = output_path.parent / "snowflake.yml"
            generate_snowflake_yml(yml_template_path, yml_output_path, variables)
        else:
            print(f"Warning: snowflake.yml template not found at {yml_template_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
