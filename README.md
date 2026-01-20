# Snowflake Horizon Iceberg REST Catalog (SHIRC)

This repository contains tools and automation for testing [Snowflake Horizon Iceberg REST Catalog](https://docs.snowflake.com/en/user-guide/tables-iceberg-rest-catalog).

## Prerequisites

Before getting started, ensure you have the following tools installed:

- [Task](https://taskfile.dev/) - Task runner for executing automation tasks
- [AWS CLI](https://aws.amazon.com/cli/) - For interacting with AWS services
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) - For interacting with Snowflake
- [uv](https://docs.astral.sh/uv/) - Python package installer

## Getting Started

### Step 1: Validate Prerequisites

Run all prerequisite validation tasks to ensure your environment is properly configured:

```bash
task validate-prerequisites:awscli
task validate-prerequisites:snowcli
task validate-prerequisites:uv
```

These tasks will check:

| Task | Description |
|------|-------------|
| `validate-prerequisites:awscli` | Validates AWS CLI is installed and credentials are configured |
| `validate-prerequisites:snowcli` | Validates Snowflake CLI (snow) is installed |
| `validate-prerequisites:uv` | Validates uv Python package installer is installed |

If any validation fails, follow the installation instructions provided in the output.

### Step 2: Configure Environment

Copy the environment template and configure your settings:

```bash
cp .env/iceberg.env.template .env/iceberg.env
```

Edit `.env/iceberg.env` with your values:

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_PROFILE` | AWS CLI profile to use (optional) | `my-profile` |
| `AWS_REGION` | AWS region for S3 bucket | `us-east-1` |
| `AWS_S3_BUCKET` | S3 bucket name for Iceberg tables | `my-iceberg-bucket` |
| `AWS_S3_FOLDER` | Subfolder within the bucket | `snowflake-iceberg` |

### Step 3: Create S3 Bucket

Create an S3 bucket to store your Iceberg tables. This task uses the `AWS_S3_BUCKET` and `AWS_REGION` values from your `iceberg.env` file. Run from the repository root:

```bash
S3_BUCKET_NAME=$AWS_S3_BUCKET task make-s3-bucket
```

This creates an S3 bucket that will be used as external storage for Snowflake Iceberg tables.

### Step 4: Generate IAM Policy for S3 Bucket Access

Generate an IAM policy document that grants Snowflake access to your S3 bucket. This task uses the `AWS_S3_BUCKET` and `AWS_S3_FOLDER` values from your `iceberg.env` file. Run from the repository root:

```bash
S3_BUCKET_NAME=$AWS_S3_BUCKET \
S3_PREFIX=$AWS_S3_FOLDER \
TEMPLATE_FILE=tasks/aws-cli/json/template/bucket-policy-template.json \
OUTPUT_FILE=tasks/aws-cli/json/output/bucket-policy-output.json \
task generate-iam-policy-for-s3-bucket-access
```

The generated policy grants the following permissions:
- `s3:PutObject`, `s3:GetObject`, `s3:GetObjectVersion`, `s3:DeleteObject`, `s3:DeleteObjectVersion` on objects
- `s3:ListBucket`, `s3:GetBucketLocation` on the bucket

Use this policy to create an IAM role that Snowflake will assume to access your S3 bucket.
