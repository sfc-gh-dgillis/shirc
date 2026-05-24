# SHIRC - Snowflake Horizon Iceberg REST Catalog

> Automated setup and management of Snowflake infrastructure for Apache Iceberg tables

## Overview

SHIRC provides automated infrastructure setup for working with Apache Iceberg tables through Snowflake's Horizon REST catalog. Using Task automation, it handles:

- **Snowflake Managed Storage** (default): Zero-config Iceberg tables using `EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'` — no AWS setup required
- **External S3 Storage** (optional): S3 buckets, IAM policies, and roles with trust relationships for bring-your-own storage
- **Snowflake Resources**: Databases, schemas, roles, stages, and Iceberg V3 tables
- **Snowpipe Streaming**: Real-time data ingestion into Iceberg V3 tables via the Snowpipe Streaming Python SDK
- **Demo Notebook**: Generates and deploys a Snowflake notebook demonstrating Iceberg V3 features
- **Spark Demo**: Local Spark environment with Jupyter notebook connecting to Snowflake Horizon REST catalog

## Quick Start

### One-Command Setup (Managed Storage — No AWS Required)

```bash
# 1. Configure environment
cp .env/iceberg.env.template .env/iceberg.env
# Edit .env/iceberg.env with your Snowflake values (STORAGE_MODE=managed is the default)

# 2a. Set up Snowflake notebook demo
task demo-up

# 2b. OR set up local Spark + Jupyter demo
task spark-demo-up
```

### One-Command Setup (External S3 Storage)

```bash
# 1. Configure environment
cp .env/iceberg.env.template .env/iceberg.env
# Set STORAGE_MODE=external and fill in AWS + Snowflake values

# 2. Set up demo (creates AWS resources + Snowflake integration)
task demo-up
```

### How It Routes

`infrastructure-up` dispatches based on `STORAGE_MODE`:

- **`managed`** (default): Validates Snowflake CLI → runs managed init SQL → uploads demo files
- **`external`**: Creates AWS resources → creates Snowflake external volume → updates trust policy → runs init SQL → uploads demo files

After infrastructure is ready, `demo-up` generates and deploys the Snowflake notebook.

### Teardown

```bash
# Clean up Snowflake notebook demo
task demo-teardown

# Clean up Spark demo
task spark-demo-teardown
```

Teardown also routes by `STORAGE_MODE`:
- **Managed**: Drops the Snowflake database (one command — no AWS resources to clean up)
- **External**: Drops Snowflake database and external volume, then deletes IAM role, IAM policy, and S3 bucket

## Prerequisites

- [Task](https://taskfile.dev/) - Task runner (install: `brew install go-task`)
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake command line interface
- [jq](https://stedolan.github.io/jq/) - JSON processor (install: `brew install jq`)
- [Python 3](https://www.python.org/) - Required for notebook generation and file uploads

**Additional prerequisites by feature:**

| Feature | Requirement |
|---------|-------------|
| `STORAGE_MODE=external` | [AWS CLI](https://aws.amazon.com/cli/) + configured AWS credentials |
| Spark demo | [Conda](https://docs.conda.io/en/latest/miniconda.html) (Miniconda recommended) |
| Snowpipe Streaming | `pip install snowpipe-streaming cryptography` + key-pair auth configured |

### Validate Prerequisites

```bash
task validate-prerequisites:snowcli
task validate-prerequisites:awscli    # only needed for external storage mode
task validate-prerequisites:conda     # only needed for Spark demo
```

## Configuration

### Environment Variables

Copy the template and edit `.env/iceberg.env`:

```bash
cp .env/iceberg.env.template .env/iceberg.env
```

Use a custom env file by setting `DOTENV_FILENAME`:

```bash
DOTENV_FILENAME=other.env task demo-up
```

#### Storage Mode

```bash
# Controls where Iceberg table data is stored:
#   "managed"  - Snowflake Managed Storage (no AWS setup needed, default)
#   "external" - Your own AWS S3 bucket (requires AWS Configuration below)
STORAGE_MODE=managed
```

#### Snowflake Configuration (always required)

```bash
CLI_CONNECTION_NAME=your_snowflake_connection
DEMO_DATABASE_NAME=yourdbnamehere
DEMO_SCHEMA_NAME=RAW
DEMO_ENGINEER_ROLE_NAME=V3_DEMO_ICEBERG_ENGINEER_ROLE
DEMO_ENGINEER_USER_NAME=V3_DEMO_ICEBERG_USER
INTERNAL_NAMED_STAGE=@yourdbnamehere.RAW.yourstagename
DEMO_WAREHOUSE_NAME=COMPUTE_WH
EXTERNAL_VOLUME_NAME=my_iceberg_ext_vol  # only used when STORAGE_MODE=external
```

#### AWS Configuration (only when `STORAGE_MODE=external`)

```bash
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
S3_PREFIX=snowflake-iceberg
IAM_POLICY_NAME=YourIcebergAccessPolicy
IAM_ROLE_NAME=YourIcebergAccessRole
TRUST_POLICY_EXTERNAL_ID=your-external-id
```

#### Spark Demo Configuration

```bash
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

| Task                      | Description                                                         |
|---------------------------|---------------------------------------------------------------------|
| `task infrastructure-up`  | Sets up infrastructure (routes by `STORAGE_MODE`)                   |
| `task demo-up`            | Infrastructure + Snowflake notebook deployment                      |
| `task demo-teardown`      | Teardown (routes by `STORAGE_MODE`)                                 |
| `task spark-demo-up`      | Infrastructure + Spark/Jupyter environment                          |
| `task spark-demo-teardown`| Teardown Spark environment + infrastructure                         |

### AWS Resource Tasks (external storage mode only)

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
| `task aws-cli:refresh-sso-token`                       | Refresh AWS SSO token (set `AWS_PROFILE`)                        |
| `task aws-cli:list-profiles`                           | List all configured AWS profiles                                 |

### Snowflake Resource Tasks

| Task                                                 | Description                                                |
|------------------------------------------------------|------------------------------------------------------------|
| `task snowflake-resources-up`                        | Create and describe external volume                        |
| `task snowflake-resources-teardown`                  | Drop database and external volume                          |
| `task snowflake-resources-teardown-managed`          | Drop database only (managed mode)                          |
| `task snow-cli:create-external-volume`               | Create external volume only                                |
| `task snow-cli:drop-external-volume`                 | Drop external volume only                                  |
| `task snow-cli:desc-external-volume`                 | Describe external volume and save JSON                     |
| `task snow-cli:run-init`                             | Run initialization SQL (external mode)                     |
| `task snow-cli:run-init-managed`                     | Run initialization SQL (managed mode, no external volume)  |
| `task snow-cli:upload-files-to-internal-named-stage` | Upload files to internal stage                             |
| `task snow-cli:generate-notebook`                    | Generate notebook from template                            |
| `task snow-cli:deploy-notebook`                      | Deploy notebook to Snowflake                               |
| `task snow-cli:drop-database-if-exists`              | Drop database if it exists                                 |

### Iceberg V3 Feature Tables (batch-2)

| Task                            | Description                                                          |
|---------------------------------|----------------------------------------------------------------------|
| `task snow-cli:create-tables`   | Create Iceberg V3 feature-showcase tables                            |
| `task snow-cli:load-data`       | Load staged JSON data into batch-2 tables                            |
| `task snow-cli:run-dml-demo`    | Run DML demo (deletion vectors, row lineage)                         |
| `task snow-cli:drop-tables`     | Drop batch-2 demo tables                                            |
| `task snow-cli:stream-telemetry`| Stream simulated vehicle telemetry via Snowpipe Streaming SDK        |

### Python/Spark Tasks

| Task                              | Description                                           |
|-----------------------------------|-------------------------------------------------------|
| `task python-tasks:create-conda-env`  | Create conda environment with PySpark and Jupyter |
| `task python-tasks:remove-conda-env`  | Remove conda environment                          |
| `task python-tasks:run-jupyter`       | Launch Jupyter notebook in conda environment      |

## Architecture

### Managed Mode (default)

```text
+-------------------------------------------------------------+
|                    Snowflake Account                         |
|                                                             |
|  EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'                      |
|  (Snowflake handles all storage internally)                 |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Database: your_database                             |  |
|  |   +-- Schema: RAW                                     |  |
|  |   |   +-- Stage: your_stage (internal)                |  |
|  |   |   +-- Iceberg V3 Tables                           |  |
|  |   |       +-- CUSTOMER_EVENTS (VARIANT)               |  |
|  |   |       +-- vehicle_telemetry_stream (streaming)    |  |
|  |   +-- Schema: REDACTED                                |  |
|  |       +-- CUSTOMER_EVENTS_REDACTED (AI_REDACT)        |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Role: V3_DEMO_ICEBERG_ENGINEER_ROLE                 |  |
|  |   Notebook: iceberg_v3_demo_notebook                  |  |
|  +-------------------------------------------------------+  |
|                                                             |
+-------------------------------------------------------------+
```

### External Storage Mode

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
|                    Snowflake Account                         |
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
|  |   +-- Schema: RAW                                     |  |
|  |       +-- Stage: your_stage (internal)                |  |
|  |       +-- Iceberg V3 Tables                           |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Role: V3_DEMO_ICEBERG_ENGINEER_ROLE                 |  |
|  |   Notebook: iceberg_v3_demo_notebook                  |  |
|  +-------------------------------------------------------+  |
|                                                             |
+-------------------------------------------------------------+
```

## Snowpipe Streaming

The `stream-telemetry` task demonstrates real-time ingestion into an Iceberg V3 table via the [Snowpipe Streaming Python SDK](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview):

```bash
# Stream 100 simulated vehicle telemetry events (default)
task snow-cli:stream-telemetry

# Stream a custom number of events
task snow-cli:stream-telemetry EVENT_COUNT=500
```

**Requirements:**
- Key-pair authentication configured in your Snow CLI connection (`private_key_path`)
- Python dependencies: `pip install snowpipe-streaming cryptography`
- Target table `VEHICLE_TELEMETRY_STREAM` created via `task snow-cli:create-tables`

The script reads credentials from your Snow CLI `~/.snowflake/config.toml` using the `CLI_CONNECTION_NAME` connection.

## Usage Examples

### Complete Setup and Teardown (Managed)

```bash
# Set up everything (no AWS needed)
task demo-up

# Open the deployed notebook in Snowsight to run the demo

# Clean up
task demo-teardown
```

### Complete Setup and Teardown (External)

```bash
# Set STORAGE_MODE=external in .env/iceberg.env first
task demo-up

# Clean up (removes both Snowflake and AWS resources)
task demo-teardown
```

### Step-by-Step Setup (External Mode)

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

### Batch-2 Feature Tables

```bash
# Create standalone Iceberg V3 feature-showcase tables
task snow-cli:create-tables

# Load data
task snow-cli:load-data

# Run DML demo (deletion vectors, row lineage)
task snow-cli:run-dml-demo

# Stream telemetry data
task snow-cli:stream-telemetry

# Tear down batch-2 tables only
task snow-cli:drop-tables
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
+-- Taskfile.yml                      # Main task definitions (routes by STORAGE_MODE)
+-- .env/
|   +-- iceberg.env.template          # Configuration template
|   +-- iceberg.env                   # Your config (git-ignored)
+-- tasks/
|   +-- aws-cli/
|   |   +-- awscli-tasks.yml          # AWS CLI task definitions
|   |   +-- cmd/                      # AWS CLI scripts
|   |   +-- json/template/            # JSON templates (bucket-policy, trust-policy)
|   +-- snow-cli/
|   |   +-- snowcli-tasks.yml         # Snowflake CLI task definitions
|   |   +-- cmd/                      # Snowflake CLI scripts
|   |   |   +-- run-init.sh           # Init script (external mode)
|   |   |   +-- run-init-managed.sh   # Init script (managed mode)
|   |   |   +-- generate-notebook.sh  # Notebook generation
|   |   |   +-- deploy-notebook.sh    # Notebook deployment
|   |   +-- sql/
|   |   |   +-- infra-up-external/      # SQL for external-storage infrastructure
|   |   |   |   +-- 001-create_external_volume.sql  # External volume DDL
|   |   |   |   +-- 002-init.sql                # Init SQL (external mode)
|   |   |   +-- infra-up-managed/       # SQL for managed-storage infrastructure
|   |   |   |   +-- 001-init-managed.sql      # Init SQL (managed mode)
|   |   |   +-- batch-2/
|   |   |       +-- 001-create-tables.sql     # Iceberg V3 feature tables
|   |   |       +-- 002-load-data.sql         # Data loading
|   |   |       +-- 003-dml-demo.sql          # DML demo (deletion vectors)
|   |   |       +-- teardown.sql              # Drop batch-2 tables
|   |   +-- notebook/                 # Notebook templates
|   |   |   +-- iceberg_v3_template.ipynb
|   |   |   +-- iceberg_v3_demo_snowflake_yml_template.yml
|   |   +-- pyutil/
|   |       +-- snowcliput/           # Python utility for file uploads to stages
|   |       +-- snowclisp/            # Python utility for stored procedures
|   |       +-- snowpipe_streaming/   # Snowpipe Streaming SDK integration
|   |       |   +-- stream_telemetry.py   # Vehicle telemetry data generator
|   |       |   +-- requirements.txt
|   |       +-- genagentsql/          # SQL generation utility
|   +-- python/
|   |   +-- python-tasks.yml          # Conda/Spark task definitions
|   |   +-- notebook/                 # Spark/Jupyter notebooks
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
+-- README.md
+-- AGENTS.md                         # AI agent instructions
```

## How It Works

### Managed Storage Mode

1. **Initialization SQL**: Creates database with `EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'`, schemas (RAW + REDACTED), roles, users, and internal stage
2. **File Upload**: Uploads demo JSON files to internal named stage
3. **Notebook**: Generates and deploys demo notebook

### External Storage Mode

1. **S3 Bucket**: Created in your specified region
2. **IAM Policy**: Generated from template with S3 permissions (ListBucket, GetObject, PutObject, DeleteObject)
3. **IAM Role**: Created with trust policy (trusts your AWS account)
4. **Policy Attachment**: IAM policy attached to the role
5. **External Volume**: Created in Snowflake pointing to your S3 bucket
6. **Trust Policy Update**: AWS role trust policy updated to allow Snowflake's IAM user to assume the role
7. **Initialization SQL**: Creates database, schema, roles, users, and internal stage
8. **File Upload**: Uploads demo JSON files to internal named stage
9. **Notebook**: Generates and deploys demo notebook

### Resource Metadata (external mode)

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

## What You Get

After running `task demo-up` (managed mode), you will have:

- Database with schemas (RAW + REDACTED), roles, and internal stage
- Demo files uploaded to internal stage
- Deployed notebook ready to run in Snowsight

After running `task demo-up` (external mode), you additionally get:

- S3 bucket ready for Iceberg data storage
- IAM role with proper permissions and trust policy
- Snowflake external volume configured and integrated
- All resource metadata saved in JSON files

The deployed notebook demonstrates:

- Creating Iceberg V3 tables with VARIANT columns
- Loading JSON data into VARIANT columns
- Querying VARIANT data using semi-structured notation
- Redacting PII using AI_REDACT()

The batch-2 feature tables demonstrate:

- Partitioned Iceberg V3 tables
- IoT event ingestion
- Real-time streaming via Snowpipe Streaming SDK
- Dynamic Iceberg tables (auto-refreshed)
- DML operations with deletion vectors and row lineage

## Resources

- [Apache Iceberg](https://iceberg.apache.org/) - Open table format specification
- [Snowflake Iceberg Tables](https://docs.snowflake.com/en/user-guide/tables-iceberg) - Snowflake Iceberg documentation
- [Snowpipe Streaming](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview) - Real-time ingestion
- [Task Documentation](https://taskfile.dev/) - Task runner documentation
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/) - AWS CLI documentation
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake CLI documentation

## License

This project is provided as-is for educational and demonstration purposes.
