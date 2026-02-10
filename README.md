# SHIRC - Snowflake Horizon Iceberg REST Catalog

> Automated setup and management of AWS and Snowflake resources for Apache Iceberg tables

## Overview

SHIRC provides automated infrastructure setup for working with Apache Iceberg tables through Snowflake's Horizon REST catalog. Using Task automation, it handles:

- **AWS Resources**: S3 buckets, IAM policies, and roles with trust relationships
- **Snowflake Resources**: External volumes, databases, schemas, roles, and stages
- **Integration**: Automatic trust policy updates to connect AWS and Snowflake
- **Demo Notebook**: Generates and deploys a Snowflake notebook demonstrating Iceberg V3 features
- **Spark Demo**: Local Spark environment with Jupyter notebook connecting to Snowflake Horizon REST catalog

## Quick Start

### One-Command Setup

```bash
# 1. Configure environment
cp .env/iceberg.env.template .env/iceberg.env
# Edit .env/iceberg.env with your values

# 2a. Set up Snowflake notebook demo
task demo-up

# 2b. OR set up local Spark + Jupyter demo
task spark-demo-up
```

Both tasks use shared infrastructure setup (`infrastructure-up`):

1. **AWS Resources Setup** (`aws-resources-up`)
   - Validates AWS CLI is installed and configured
   - Creates S3 bucket for Iceberg data storage
   - Generates IAM policy for S3 bucket access
   - Creates IAM policy in AWS
   - Generates trust policy for cross-account access
   - Creates IAM role with trust policy
   - Attaches IAM policy to role

2. **Snowflake Resources Setup** (`snowflake-resources-up`)
   - Validates Snowflake CLI is installed and configured
   - Creates external volume pointing to S3 bucket
   - Describes external volume to get Snowflake's IAM user ARN

3. **AWS-Snowflake Integration**
   - Updates IAM role trust policy with Snowflake's IAM user ARN

4. **Snowflake Demo Environment Setup**
   - Runs initialization SQL to create database, schema, roles, and stages
   - Uploads demo files to internal named stage

**`demo-up`** then deploys a Snowflake notebook:
   - Generates notebook from template with environment variable substitution
   - Generates snowflake.yml project file
   - Deploys notebook to Snowflake

**`spark-demo-up`** then sets up local Spark environment:
   - Validates conda is installed
   - Creates conda environment with PySpark, Jupyter, and OpenJDK
   - Launches Jupyter notebook connecting to Snowflake Horizon REST catalog

### Teardown

```bash
# Clean up Snowflake notebook demo
task demo-teardown

# Clean up Spark demo
task spark-demo-teardown
```

The teardown removes resources in reverse order:
1. Drops Snowflake database (or removes conda environment for Spark demo)
2. Drops external volume
3. Detaches IAM policy from role
4. Deletes IAM role
5. Deletes IAM policy
6. Deletes S3 bucket (with force flag to remove contents)

## Prerequisites

- [Task](https://taskfile.dev/) - Task runner (install: `brew install go-task`)
- [AWS CLI](https://aws.amazon.com/cli/) - AWS command line interface
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake command line interface
- [jq](https://stedolan.github.io/jq/) - JSON processor (install: `brew install jq`)
- [Python 3](https://www.python.org/) - Required for notebook generation and file uploads
- [Conda](https://docs.conda.io/en/latest/miniconda.html) - Required for Spark demo (Miniconda recommended)
- AWS credentials configured
- Snowflake credentials configured

### Validate Prerequisites

```bash
task validate-prerequisites:awscli
task validate-prerequisites:snowcli
task validate-prerequisites:conda
```

## Configuration

### Environment Variables

Copy the template and edit `.env/iceberg.env`:

```bash
cp .env/iceberg.env.template .env/iceberg.env
```

Required variables:

```bash
# AWS Configuration
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
S3_PREFIX=snowflake-iceberg
IAM_POLICY_NAME=YourIcebergAccessPolicy
IAM_ROLE_NAME=YourIcebergAccessRole
TRUST_POLICY_EXTERNAL_ID=your-external-id

# Snowflake Configuration
CLI_CONNECTION_NAME=your_snowflake_connection
EXTERNAL_VOLUME_NAME=iceberg_ext_vol
DEMO_DATABASE_NAME=your_database
DEMO_SCHEMA_NAME=your_database.your_schema
DEMO_ENGINEER_ROLE_NAME=V3_DEMO_ICEBERG_ENGINEER_ROLE
DEMO_ENGINEER_USER_NAME=V3_DEMO_ICEBERG_USER
INTERNAL_NAMED_STAGE=@your_database.your_schema.your_stage
WAREHOUSE_NAME=COMPUTE_WH

# Spark Demo Configuration
CONDA_ENV_NAME=iceberg-lab
SPARK_HORIZON_CATALOG_URI=https://<account>.snowflakecomputing.com/polaris/api/catalog
SPARK_CATALOG_NAME=YOUR_DATABASE_NAME
SPARK_SNOWFLAKE_PAT=YOUR_PAT_HERE
SPARK_HORIZON_ROLE=session:role:YOUR_ROLE_NAME
SPARK_ICEBERG_VERSION=1.10.0
SPARK_NOTEBOOK_PATH=tasks/python/notebook/horizon_v3_variant_spark.ipynb
```

## Available Tasks

### Main Tasks

| Task                      | Description                                             |
|---------------------------|---------------------------------------------------------|
| `task infrastructure-up`  | Sets up AWS and Snowflake infrastructure                |
| `task demo-up`            | Infrastructure + Snowflake notebook deployment          |
| `task demo-teardown`      | Teardown Snowflake resources and AWS infrastructure     |
| `task spark-demo-up`      | Infrastructure + Spark/Jupyter environment              |
| `task spark-demo-teardown`| Teardown Spark environment and infrastructure           |

### AWS Resource Tasks

| Task                                                   | Description                                                      |
|--------------------------------------------------------|------------------------------------------------------------------|
| `task aws-resources-up`                                | Create S3 bucket, IAM policy, and role                           |
| `task aws-resources-teardown`                          | Delete IAM role, policy, and S3 bucket                           |
| `task aws-cli:make-s3-bucket`                          | Create S3 bucket only                                            |
| `task aws-cli:delete-s3-bucket`                        | Delete S3 bucket (use FORCE=--force to delete with contents)     |
| `task aws-cli:create-iam-policy`                       | Create IAM policy for S3 access                                  |
| `task aws-cli:delete-iam-policy`                       | Delete IAM policy                                                |
| `task aws-cli:create-iam-role`                         | Create IAM role with trust policy                                |
| `task aws-cli:delete-iam-role`                         | Delete IAM role                                                  |
| `task aws-cli:attach-policy-to-role`                   | Attach policy to role                                            |
| `task aws-cli:detach-policy-from-role`                 | Detach policy from role                                          |
| `task aws-cli:update-trust-policy-with-snowflake-user` | Update trust policy with Snowflake IAM user                      |

### Snowflake Resource Tasks

| Task                                            | Description                                           |
|-------------------------------------------------|-------------------------------------------------------|
| `task snowflake-resources-up`                   | Create and describe external volume                   |
| `task snowflake-resources-teardown`             | Drop database and external volume                     |
| `task snow-cli:create-external-volume`          | Create external volume only                           |
| `task snow-cli:drop-external-volume`            | Drop external volume only                             |
| `task snow-cli:desc-external-volume`            | Describe external volume and save JSON                |
| `task snow-cli:run-init`                        | Run initialization SQL script                         |
| `task snow-cli:upload-files-to-internal-named-stage` | Upload files to internal stage                   |
| `task snow-cli:generate-notebook`               | Generate notebook from template                       |
| `task snow-cli:deploy-notebook`                 | Deploy notebook to Snowflake                          |
| `task snow-cli:drop-database-if-exists`         | Drop database if it exists                            |

### Python/Spark Tasks

| Task                              | Description                                           |
|-----------------------------------|-------------------------------------------------------|
| `task python-tasks:create-conda-env`  | Create conda environment with PySpark and Jupyter |
| `task python-tasks:remove-conda-env`  | Remove conda environment                          |
| `task python-tasks:run-jupyter`       | Launch Jupyter notebook in conda environment      |

## Architecture

### What Gets Created

```text
+-------------------------------------------------------------+
|                         AWS Account                         |
|                                                             |
|  +---------------------+      +------------------------+    |
|  |   S3 Bucket         |      |   IAM Role             |    |
|  |   your-bucket       |<-----|   YourIcebergRole      |    |
|  |   +-- iceberg/      |      |   (Trust Policy)       |    |
|  +---------------------+      +------------------------+    |
|                                          ^                  |
|                                          |                  |
|  +-------------------------------------+ |                  |
|  |   IAM Policy                        | |                  |
|  |   YourIcebergAccessPolicy           |-+                  |
|  |   (S3 permissions)                  |                    |
|  +-------------------------------------+                    |
|                                                             |
+-------------------------------------------------------------+
                                           |
                                           | AssumeRole
                                           v
+-------------------------------------------------------------+
|                    Snowflake Account                        |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   External Volume: iceberg_ext_vol                    |  |
|  |   - Storage: s3://your-bucket/iceberg/                |  |
|  |   - Role ARN: arn:aws:iam::xxx:role/YourRole          |  |
|  |   - External ID: your-external-id                     |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Database: your_database                             |  |
|  |   +-- Schema: your_schema                             |  |
|  |       +-- Stage: your_stage (internal)                |  |
|  |       +-- Iceberg Tables                              |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Role: V3_DEMO_ICEBERG_ENGINEER_ROLE                 |  |
|  |   Notebook: iceberg_v3_demo_notebook                  |  |
|  +-------------------------------------------------------+  |
|                                                             |
+-------------------------------------------------------------+
```

## Usage Examples

### Complete Setup and Teardown

```bash
# Set up everything
task demo-up

# Use your Iceberg tables in Snowflake
# Open the deployed notebook in Snowsight to run the demo

# Clean up everything
task demo-teardown
```

### Step-by-Step Setup

```bash
# 1. Create AWS resources
task aws-resources-up

# 2. Create Snowflake resources
task snowflake-resources-up

# 3. Update trust policy with Snowflake's IAM user
task aws-cli:update-trust-policy-with-snowflake-user

# 4. Run initialization SQL
task snow-cli:run-init

# 5. Upload demo files
task snow-cli:upload-files-to-internal-named-stage

# 6. Generate and deploy notebook
task snow-cli:generate-notebook
task snow-cli:deploy-notebook
```

### Individual Operations

```bash
# Just create an S3 bucket
task aws-cli:make-s3-bucket S3_BUCKET_NAME=my-bucket AWS_REGION=us-west-2

# Delete S3 bucket (force delete with contents)
task aws-cli:delete-s3-bucket S3_BUCKET_NAME=my-bucket FORCE=--force

# Describe existing external volume
task snow-cli:desc-external-volume EXTERNAL_VOLUME_NAME=my_ext_vol
```

## Repository Structure

```text
shirc/
+-- Taskfile.yml                      # Main task definitions
+-- .env/
|   +-- iceberg.env.template          # Configuration template
|   +-- iceberg.env                   # Your config (git-ignored)
+-- tasks/
|   +-- aws-cli/
|   |   +-- awscli-tasks.yml          # AWS CLI task definitions
|   |   +-- cmd/                      # AWS CLI scripts
|   |   +-- json/template/            # JSON templates
|   +-- snow-cli/
|   |   +-- snowcli-tasks.yml         # Snowflake CLI task definitions
|   |   +-- cmd/                      # Snowflake CLI scripts
|   |   |   +-- generate-notebook.py  # Notebook generation script
|   |   |   +-- deploy-notebook.sh    # Notebook deployment script
|   |   +-- sql/                      # SQL templates
|   |   +-- notebook/                 # Notebook templates
|   |   |   +-- iceberg_v3_template.ipynb
|   |   |   +-- iceberg_v3_demo_snowflake_yml_template.yml
|   |   +-- pyutil/                   # Python utilities
|   +-- validate-prerequisites/
|       +-- validate-prerequisite-tasks.yml
+-- upload/                           # Files to upload to internal stage
+-- output/                           # Generated output files (git-ignored)
|   +-- aws-output.json               # AWS resource ARNs and metadata
|   +-- bucket-policy-output.json     # Generated bucket policy
|   +-- trust-policy-output.json      # Generated trust policy
|   +-- trust-policy-updated.json     # Updated trust policy
|   +-- external-volume-desc.json     # External volume description
|   +-- external-volume-desc-storage-location.json
+-- README.md                         # This file
```

## How It Works

### AWS Resources Setup

1. **S3 Bucket**: Created in your specified region with the configured prefix
2. **IAM Policy**: Generated from template with S3 permissions (ListBucket, GetObject, PutObject, DeleteObject)
3. **IAM Role**: Created with initial trust policy (trusts your AWS account)
4. **Policy Attachment**: IAM policy attached to the role

### Snowflake Integration

1. **External Volume**: Created in Snowflake pointing to your S3 bucket
2. **Description**: External volume details retrieved including Snowflake's IAM user ARN
3. **Trust Policy Update**: AWS role trust policy updated to allow Snowflake's IAM user to assume the role

### Demo Environment Setup

1. **Initialization SQL**: Creates database, schema, roles, users, and internal stage
2. **File Upload**: Uploads demo JSON files to internal named stage using Python utility
3. **Notebook Generation**: Generates notebook from template with Jinja variable substitution
4. **Notebook Deployment**: Deploys notebook to Snowflake using `snow notebook deploy`

### Resource Metadata

All generated resource details are stored in the `output/` directory:

- `output/aws-output.json` - AWS resource ARNs and metadata
- `output/bucket-policy-output.json` - Generated IAM policy for S3 bucket access
- `output/trust-policy-output.json` - Generated trust policy for IAM role
- `output/trust-policy-updated.json` - Updated trust policy with Snowflake IAM user
- `output/external-volume-desc.json` - Full external volume description
- `output/external-volume-desc-storage-location.json` - Storage location details

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use `.env` files** for configuration (already git-ignored)
3. **Rotate external IDs** regularly
4. **Use least-privilege IAM policies**
5. **Enable MFA** on AWS and Snowflake accounts
6. **Review trust policies** before deployment
7. **Use separate environments** for dev/staging/prod

## Troubleshooting

### Common Issues

| Issue                              | Solution                                      |
|------------------------------------|-----------------------------------------------|
| **Task not found**                 | Install Task: `brew install go-task`          |
| **AWS CLI not configured**         | Run `aws configure` or set AWS_PROFILE        |
| **Snowflake CLI not configured**   | Run `snow connection add`                     |
| **Permission denied (S3)**         | Check AWS credentials and IAM permissions     |
| **External volume creation fails** | Verify S3 bucket and IAM role exist           |
| **Trust policy update fails**      | Ensure external volume is created first       |
| **jq command not found**           | Install jq: `brew install jq`                 |
| **Notebook deploy fails**          | Check snowflake.yml exists in project dir     |

### Debug Mode

View detailed output by checking the generated files:

```bash
# View AWS output
cat output/aws-output.json | jq '.'

# View Snowflake external volume details
cat output/external-volume-desc-storage-location.json | jq '.'
```

## Resources

### Documentation

- [Apache Iceberg](https://iceberg.apache.org/) - Open table format specification
- [Snowflake Iceberg Tables](https://docs.snowflake.com/en/user-guide/tables-iceberg) - Snowflake Iceberg documentation
- [Task Documentation](https://taskfile.dev/) - Task runner documentation
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/) - AWS CLI documentation
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake CLI documentation

## What You Get

After running `task demo-up`, you will have:

- S3 bucket ready for Iceberg data storage
- IAM role with proper permissions and trust policy
- Snowflake external volume configured and integrated
- Database with schema, roles, and internal stage
- Demo files uploaded to internal stage
- Deployed notebook ready to run in Snowsight
- All resource metadata saved in JSON files

You can then open the deployed notebook in Snowsight to:

- Create Iceberg V3 tables with VARIANT columns
- Load JSON data into VARIANT columns
- Query VARIANT data using semi-structured notation
- Extract data using AI_EXTRACT()
- Redact PII using AI_REDACT()

## License

This project is provided as-is for educational and demonstration purposes.
