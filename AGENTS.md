# AGENTS.md

This file provides guidance to AI coding agents (such as Snowflake Cortex Code CLI) when working with code in this repository.

## Project Overview

SHIRC (Snowflake Horizon Iceberg REST Catalog) automates the setup of AWS and Snowflake infrastructure for Apache Iceberg tables. It uses [Task](https://taskfile.dev/) as the primary automation runner, with shell scripts and SQL files doing the actual work.

## Prerequisites

- `task` - Task runner (`brew install go-task`)
- `aws` - AWS CLI
- `snow` - Snowflake CLI
- `jq` - JSON processor (`brew install jq`)
- `python3` - For file upload utility

## Configuration

Copy and edit the environment file before running anything:

```bash
cp .env/iceberg.env.template .env/iceberg.env
# Edit .env/iceberg.env with your values
```

The `.env/iceberg.env` file is git-ignored. The `Taskfile.yml` loads it via `dotenv`. A custom env file can be used by setting `DOTENV_FILENAME`:

```bash
DOTENV_FILENAME=other.env task demo-up
```

### Storage Mode

The `STORAGE_MODE` variable in `.env/iceberg.env` controls where Iceberg table data is stored:

- **`managed`** (default) — Uses Snowflake Managed Storage. No AWS infrastructure is needed. Snowflake handles all storage internally via `EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'`. Only Snowflake CLI prerequisites are required.
- **`external`** — Uses your own AWS S3 bucket. Requires full AWS configuration (S3 bucket, IAM policy, IAM role, trust policy). The automation creates an external volume in Snowflake pointing to S3 and establishes cross-account trust.

## Key Commands

```bash
# Full setup (AWS + Snowflake + trust policy integration)
task demo-up

# Full teardown
task demo-teardown

# AWS only
task aws-resources-up
task aws-resources-teardown

# Snowflake only
task snowflake-resources-up
task snowflake-resources-teardown

# Validate tooling
task validate-prerequisites:awscli
task validate-prerequisites:snowcli

# Individual AWS operations
task aws-cli:make-s3-bucket
task aws-cli:create-iam-policy
task aws-cli:create-iam-role
task aws-cli:update-trust-policy-with-snowflake-user

# Individual Snowflake operations
task snow-cli:create-external-volume
task snow-cli:desc-external-volume
task snow-cli:drop-external-volume
task snow-cli:generate-notebook
task snow-cli:deploy-notebook

# AWS SSO
task aws-cli:refresh-sso-token AWS_PROFILE=my-profile
```

## Architecture

### Task Flow

`demo-up` orchestrates the full setup in order:
1. AWS resources: S3 bucket → IAM policy → IAM role → attach policy
2. Snowflake resources: create external volume → describe it (saves Snowflake IAM user ARN to `output/`)
3. Update AWS trust policy with the Snowflake IAM user ARN (cross-account access)
4. Run Snowflake init SQL (`batch-1/001-init.sql`)
5. Upload files to Snowflake internal named stage

### Output Files

All commands write metadata to `output/` (git-ignored):
- `output/aws-output.json` — ARNs for created IAM policy and role (read by subsequent tasks)
- `output/bucket-policy-output.json` — Generated IAM policy document
- `output/trust-policy-output.json` — Generated IAM role trust policy
- `output/trust-policy-updated.json` — Trust policy updated with Snowflake IAM user
- `output/external-volume-desc.json` — Full Snowflake external volume description
- `output/external-volume-desc-storage-location.json` — Parsed storage location details
- `output/snowflake_iceberg_v3_demo_notebook.ipynb` — Generated notebook

Tasks are stateful and share data via these JSON files. Tasks like `delete-iam-policy`, `attach-policy-to-role`, and `update-trust-policy-with-snowflake-user` read ARNs from `output/aws-output.json` rather than accepting them as parameters.

### Directory Structure

```
Taskfile.yml                       # Root orchestration, includes sub-taskfiles
.env/
  iceberg.env.template             # Copy to iceberg.env and configure
tasks/
  aws-cli/
    awscli-tasks.yml               # AWS CLI task definitions
    cmd/                           # Shell scripts for AWS operations
    json/template/                 # JSON templates (bucket-policy, trust-policy)
  snow-cli/
    snowcli-tasks.yml              # Snowflake CLI task definitions (runs from tasks/snow-cli/ dir)
    cmd/                           # Shell scripts for Snowflake operations
    sql/batch-0/                   # DDL SQL templates (Jinja-style {{ }} variables)
    sql/batch-1/001-init.sql       # Snowflake initialization (roles, DB, schema, stage)
    notebook/                      # Jupyter notebook template for Snowflake demo
    pyutil/snowcliput/             # Python utility for uploading files to Snowflake stages
    pyutil/snowclisp/              # Python utility (Snowflake stored procedures)
  validate-prerequisites/
    validate-prerequisite-tasks.yml
output/                            # Generated files (git-ignored)
upload/                            # Files to upload to Snowflake internal stage
```

### SQL Templating

SQL files use Jinja-style `{{ variable_name }}` placeholders. The `snow sql` command processes these with `--variable` flags or connection context. The `run-init` task passes env vars from `.env/iceberg.env` as Jinja template variables into `001-init.sql`.

### snow-cli Task Directory

The `snow-cli` taskfile is included with `dir: ./tasks/snow-cli`, so all paths within `snowcli-tasks.yml` are relative to `tasks/snow-cli/` (e.g., `cmd/create-external-volume.sh`, not `tasks/snow-cli/cmd/...`). Output files use `../../output/` to reach the repo root.
