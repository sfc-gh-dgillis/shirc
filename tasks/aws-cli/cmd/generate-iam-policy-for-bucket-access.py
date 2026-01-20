#!/usr/bin/env python3
import json
import argparse
from pathlib import Path


def generate_s3_bucket_policy(template_path, bucket_name, prefix=None):
    # Read the template file
    with open(template_path, 'r') as f:
        policy = json.load(f)

    # Construct resource path based on whether prefix exists
    resource_path = f"arn:aws:s3:::{bucket_name}"
    if prefix:
        resource_path += f"/{prefix}/*"
    else:
        resource_path += "/*"

    # Update the Resource field in first statement (object operations)
    policy['Statement'][0]['Resource'] = resource_path

    # Update the Resource and Condition fields in second statement (bucket operations)
    policy['Statement'][1]['Resource'] = f"arn:aws:s3:::{bucket_name}"
    if prefix:
        policy['Statement'][1]['Condition']['StringLike']['s3:prefix'] = [f"{prefix}/*"]
    else:
        policy['Statement'][1]['Condition']['StringLike']['s3:prefix'] = ["*"]

    return policy


def main():
    parser = argparse.ArgumentParser(description="Generate S3 bucket policy from template")
    parser.add_argument("bucket", help="Name of the S3 bucket")
    parser.add_argument("--prefix", help="Optional prefix path within the bucket")
    parser.add_argument("--output", "-o", help="Output file (default: bucket-policy.json)")
    parser.add_argument("--template", "-t", required=True, help="Path to the bucket policy template JSON file")
    args = parser.parse_args()

    template_path = Path(args.template)
    output_path = args.output or "tasks/aws-cli/json/output/bucket-policy.json"

    try:
        policy = generate_s3_bucket_policy(template_path, args.bucket, args.prefix)

        # Write the modified policy
        with open(output_path, 'w') as f:
            json.dump(policy, f, indent=4)
        print(f"Generated bucket policy saved to {output_path}")

    except Exception as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    main()
