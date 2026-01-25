#!/usr/bin/env python3
import json
import argparse
import subprocess
import os
from pathlib import Path


def get_aws_account_id():
    """Get the AWS account ID from the AWS CLI."""
    result = subprocess.run(
        ["aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text"],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()


def generate_trust_policy(template_path, account_id, external_id):
    """Generate a trust policy from a template."""
    with open(template_path, 'r') as f:
        policy = json.load(f)

    # Update the Principal with the account ID
    policy['Statement'][0]['Principal']['AWS'] = f"arn:aws:iam::{account_id}:root"

    # Update the external ID condition
    policy['Statement'][0]['Condition']['StringEquals']['sts:ExternalId'] = external_id

    return policy


def main():
    parser = argparse.ArgumentParser(description="Generate trust policy from template")
    parser.add_argument("--template", "-t", required=True, help="Path to the trust policy template JSON file")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    template_path = Path(args.template)
    output_path = args.output or "tasks/aws-cli/json/output/trust-policy-output.json"

    # Get external ID from environment variable
    external_id = os.environ.get("TRUST_POLICY_EXTERNAL_ID")
    if not external_id:
        print("Error: TRUST_POLICY_EXTERNAL_ID environment variable is not set")
        return 1

    try:
        print("Getting AWS account ID...")
        account_id = get_aws_account_id()
        print(f"Account ID: {account_id}")
        print(f"External ID: {external_id}")

        policy = generate_trust_policy(template_path, account_id, external_id)

        # Create output directory if needed
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'w') as f:
            json.dump(policy, f, indent=4)
        print(f"Trust policy generated: {output_path}")

    except subprocess.CalledProcessError as e:
        print(f"Error getting AWS account ID: {e.stderr}")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
