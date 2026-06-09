# SHIRC - Snowflake Horizon Iceberg REST Catalog

> Automated setup and management of Snowflake infrastructure for Apache Iceberg tables

> **Based on the Snowflake quickstart _"Enterprise Lakehouse Platform for Iceberg V3"_.**
> This project is a reimplementation of the official Smart Fleet IoT Analytics demo from:
> - Guide: <https://www.snowflake.com/en/developers/guides/iceberg-v3-tables-comprehensive-guide/>
> - Assets: <https://github.com/Snowflake-Labs/sfquickstarts/tree/master/site/sfguides/src/iceberg-v3-tables-comprehensive-guide>
>
> SHIRC keeps the same use case, data model, and feature scope, but swaps the guide's
> single `setup.sh` + `config.env` for a modular [Task](https://taskfile.dev/)-driven
> workflow, and adds a few enhancements (notably OpenLineage external lineage). See
> [Relationship to the Snowflake Quickstart](#relationship-to-the-snowflake-quickstart)
> for a full diff.

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
| Spark demo | [Apache Spark 4.0+](https://spark.apache.org/) + Java 17+ (notebook deps auto-installed into a local venv) |
| Snowpipe Streaming | `pip install snowpipe-streaming cryptography` + key-pair auth configured |

### Validate Prerequisites

```bash
task validate-prerequisites:snowcli
task validate-prerequisites:awscli    # only needed for external storage mode
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
DEMO_SCHEMA_NAME_BRONZE=RAW
DEMO_ENGINEER_ROLE_NAME=V3_DEMO_ICEBERG_ENGINEER_ROLE
DEMO_INTERNAL_NAMED_STAGE=yourstagename
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
# Auth uses a key-pair JWT from CLI_CONNECTION_NAME (no PAT).
# The enforced-masking demo reuses DEMO_ANALYST_ROLE_NAME / DEMO_ENGINEER_ROLE_NAME.
SPARK_HORIZON_CATALOG_URI=https://<account>.snowflakecomputing.com/polaris/api/catalog
SPARK_CATALOG_NAME=YOUR_DATABASE_NAME
SPARK_CLOUD_PROVIDER=aws          # aws | gcp | azure (selects the Iceberg cloud bundle)
SPARK_ICEBERG_VERSION=1.10.1
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
| `task apply-network-policy` | Optional - creates INGRESS network rule + policy for streaming (see Troubleshooting) |

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
| `task snow-cli:run-init`                             | Run initialization SQL (handles both managed and external modes) |
| `task snow-cli:sort-and-process-sql-folder`         | Run the batch-1 analytics pipeline (SQL scripts 001–010 in order) |
| `task snow-cli:upload-files-to-internal-named-stage` | Upload files to internal stage                             |
| `task snow-cli:generate-fleet-notebook`             | Generate the fleet analytics notebook from its template    |
| `task snow-cli:deploy-notebook`                     | Deploy notebook to Snowflake                               |
| `task snow-cli:stream-telemetry`                    | Stream simulated vehicle telemetry via Snowpipe Streaming SDK |
| `task snow-cli:run-spark-jupyter`                   | Bootstrap a venv and launch the Spark interop notebook in Jupyter |
| `task snow-cli:drop-database-if-exists`              | Drop database if it exists                                 |

### Spark Tasks

| Task                      | Description                                           |
|---------------------------|-------------------------------------------------------|
| `task spark-demo-up`      | Infrastructure + Spark/Jupyter interop notebook       |
| `task spark-demo-teardown`| Teardown infrastructure (the Spark venv is local)     |

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
|  |   Database: your_database (ICEBERG_VERSION_DEFAULT=3) |  |
|  |   +-- Schema: BRONZE (raw)                            |  |
|  |   |   +-- Stage: your_stage (internal)                |  |
|  |   |   +-- Iceberg V3 Tables                           |  |
|  |   |       +-- VEHICLE_TELEMETRY_STREAM (VARIANT)      |  |
|  |   |       +-- MAINTENANCE_LOGS / SENSOR_READINGS ...  |  |
|  |   |       +-- VEHICLE_LOCATIONS (GEOGRAPHY)           |  |
|  |   +-- Schema: SILVER (curated)                        |  |
|  |   |   +-- Dynamic Iceberg Tables                      |  |
|  |   +-- Schema: GOLD (analytics)                        |  |
|  |   |   +-- Dynamic tables + Semantic View + Agent      |  |
|  |   +-- Schema: POLICIES (masking, tags)                |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Roles: analyst / engineer / admin                   |  |
|  |   Notebook: fleet_analytics_notebook                  |  |
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
|  |   Database: your_database (ICEBERG_VERSION_DEFAULT=3) |  |
|  |   +-- Schema: BRONZE (raw)                            |  |
|  |   |   +-- Stage: your_stage (internal)                |  |
|  |   |   +-- Iceberg V3 Tables                           |  |
|  |   +-- Schemas: SILVER / GOLD / POLICIES               |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |   Roles: analyst / engineer / admin                   |  |
|  |   Notebook: fleet_analytics_notebook                  |  |
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
- A virtual environment — `task stream-telemetry` auto-creates `.venv` and installs `pyutil/snowpipe_streaming/requirements.txt` via `cmd/stream-telemetry.sh`
- Target table `VEHICLE_TELEMETRY_STREAM` created by the batch-1 pipeline (`task snow-cli:sort-and-process-sql-folder`, part of `demo-up`)

The script reads credentials from your Snow CLI `~/.snowflake/config.toml` (or `connections.toml`) using the `CLI_CONNECTION_NAME` connection. External lineage is registered with a JWT generated by `snow connection generate-jwt` (no PAT required).

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

# 6. Run the batch-1 analytics pipeline (tables, dynamic tables, governance, semantic view, agent)
task snow-cli:sort-and-process-sql-folder

# 7. Generate and deploy notebook
task snow-cli:generate-fleet-notebook
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
|   |   |   +-- run-init.sh                  # Unified init script (handles both storage modes)
|   |   |   +-- create-external-volume.sh    # External volume creation (external mode)
|   |   |   +-- desc-external-volume.sh      # Describe external volume -> output JSON
|   |   |   +-- drop-external-volume.sh      # External volume teardown
|   |   |   +-- generate-notebook-generic.sh # Notebook generation (calls .py)
|   |   |   +-- deploy-notebook.sh           # Notebook deployment
|   |   |   +-- stream-telemetry.sh          # venv bootstrap + run streaming script
|   |   |   +-- run-spark-jupyter.sh          # venv bootstrap + launch Spark interop notebook
|   |   +-- sql/
|   |   |   +-- init/                        # Init SQL (run before batch-1)
|   |   |   |   +-- init.sql                     # Warehouse, roles, DB (ICEBERG_VERSION_DEFAULT=3), medallion schemas, stage, EAI
|   |   |   |   +-- init_storage_managed.sql     # Sets EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
|   |   |   |   +-- init_storage_external.sql    # Points DB at the user's external volume
|   |   |   |   +-- create_external_volume.sql   # CREATE EXTERNAL VOLUME (external mode only)
|   |   |   +-- batch-1/                      # Analytics pipeline (run in numeric order)
|   |   |   |   +-- 001-create_iceberg_tables.sql      # 6 Iceberg V3 tables (VARIANT, GEOGRAPHY, DEFAULT)
|   |   |   |   +-- 002-load_iceberg_lookup_tables.sql # Seed lookup/sample data
|   |   |   |   +-- 003-create_dynamic_tables.sql      # 4 dynamic Iceberg tables
|   |   |   |   +-- 004-grants.sql                     # Role hierarchy + INGEST LINEAGE
|   |   |   |   +-- 005-masking_policies.sql           # PII masking policies
|   |   |   |   +-- 006-dmfs.sql                       # Data metric functions
|   |   |   |   +-- 007-tags.sql                       # Governance tags
|   |   |   |   +-- 008-load_sample_data.sql           # COPY INTO from stage + more rows
|   |   |   |   +-- 009-create_semantic_view.sql       # Native CREATE SEMANTIC VIEW
|   |   |   |   +-- 010-create_agent.sql               # Cortex Agent + helper views
|   |   |   +-- network_policy.sql           # Optional INGRESS rule for streaming
|   |   +-- notebook/
|   |   |   +-- fleet_analytics_notebook/
|   |   |       +-- templates/            # Source notebook template
|   |   |       +-- generated/            # Rendered notebook (deployed to Snowsight)
|   |   +-- pyutil/
|   |       +-- snowcliput/           # File uploader (PUT files to internal stage)
|   |       +-- snowclisp/            # SQL pipeline runner (executes batch-1 in order)
|   |       +-- snowpipe_streaming/   # Snowpipe Streaming SDK integration
|   |           +-- stream_telemetry.py   # Vehicle telemetry simulator + external lineage
|   |           +-- requirements.txt
|   |       +-- spark/               # Spark 4.0 + Horizon REST catalog interop
|   |           +-- spark_iceberg_interop.ipynb  # Fleet tables, variant_get, enforced masking
|   |           +-- requirements.txt
|   +-- validate-prerequisites/
|       +-- validate-prerequisite-tasks.yml
+-- upload/                           # JSON files uploaded to the internal stage
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

1. **Initialization SQL**: Creates the database with `EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'` and `ICEBERG_VERSION_DEFAULT = 3`, medallion schemas (Bronze/Silver/Gold), roles, internal stage, and an external access integration for API calls
2. **File Upload**: Uploads demo JSON files to the internal named stage
3. **Batch-1 Pipeline**: Runs SQL scripts 001–010 (Iceberg tables, dynamic tables, governance, semantic view, agent)
4. **Notebook**: Generates and deploys the fleet analytics notebook

### External Storage Mode

1. **S3 Bucket**: Created in your specified region
2. **IAM Policy**: Generated from template with S3 permissions (ListBucket, GetObject, PutObject, DeleteObject)
3. **IAM Role**: Created with trust policy (trusts your AWS account)
4. **Policy Attachment**: IAM policy attached to the role
5. **External Volume**: Created in Snowflake pointing to your S3 bucket
6. **Trust Policy Update**: AWS role trust policy updated to allow Snowflake's IAM user to assume the role
7. **Initialization SQL**: Creates the database (`ICEBERG_VERSION_DEFAULT = 3`), medallion schemas, roles, internal stage, and external access integration
8. **File Upload**: Uploads demo JSON files to the internal named stage
9. **Batch-1 Pipeline**: Runs SQL scripts 001–010 (Iceberg tables, dynamic tables, governance, semantic view, agent)
10. **Notebook**: Generates and deploys the fleet analytics notebook

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
| **Streaming script can't connect** | See *Network Policy for streaming* below      |

### Network Policy for streaming (optional)

If `task stream-telemetry` cannot reach Snowflake (typical when an account
network policy is already in place or you are on a restrictive corporate
VPN), create an ingress network policy scoped to your current public IP:

```bash
task apply-network-policy
```

This runs `tasks/snow-cli/sql/network_policy.sql` which:

1. Reads your current public IP via `CURRENT_IP_ADDRESS()`.
2. Creates a `NETWORK RULE` (MODE=INGRESS, TYPE=IPV4) named
   `$DEMO_INGRESS_NETWORK_RULE_NAME` containing only that IP.
3. Creates a `NETWORK POLICY` named `$DEMO_NETWORK_POLICY_NAME` referencing
   that rule.

The script does **not** apply the policy. To bind it to your user, run
manually after verifying the detected IP:

```sql
ALTER USER <your_username> SET NETWORK_POLICY = FLEET_STREAMING_POLICY;
```

> Warning: a wrong IP will lock you out of Snowflake. Always verify the
> detected IP from the script's output before running the `ALTER USER`.

Cleanup (manual):

```sql
ALTER USER <your_username> UNSET NETWORK_POLICY;
DROP NETWORK POLICY IF EXISTS FLEET_STREAMING_POLICY;
DROP NETWORK RULE IF EXISTS FLEET_ANALYTICS_DB.RAW.FLEET_STREAMING_NETWORK_RULE;
```

Note: this is distinct from the EGRESS network rule + EXTERNAL ACCESS
INTEGRATION (`OPEN_METEO_ACCESS`) created by `task demo-up`. Those control
*outbound* calls from in-Snowflake code; this one controls *inbound* client
connections.

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

- Database with `ICEBERG_VERSION_DEFAULT = 3`, medallion schemas (Bronze/Silver/Gold) plus a policies schema, role hierarchy, and an internal stage
- 6 source Iceberg tables (VARIANT, GEOGRAPHY, and DEFAULT-valued columns) seeded with sample fleet data
- 4 dynamic Iceberg tables (one using `REFRESH_MODE = INCREMENTAL`)
- Governance objects: PII masking policies, governance tags, and data metric functions
- A native semantic view and a Cortex Agent over the fleet data
- Demo files uploaded to the internal stage and the fleet analytics notebook deployed to Snowsight

After running `task demo-up` (external mode), you additionally get:

- S3 bucket ready for Iceberg data storage
- IAM role with proper permissions and trust policy
- Snowflake external volume configured and integrated
- All resource metadata saved in JSON files

The deployed notebook and streaming script demonstrate:

- Querying VARIANT telemetry with semi-structured notation
- Batch + API ingestion (COPY INTO, external access integration)
- Declarative pipelines via dynamic Iceberg tables
- Governance: masking, tags, DMFs, and lineage (incl. OpenLineage external lineage)
- AI: semantic view, Cortex Agent, and `ML.FORECAST`
- Geospatial analytics with GEOGRAPHY / H3
- Real-time ingestion via the Snowpipe Streaming SDK
- Cross-engine access from Spark 4.0 via the Horizon REST catalog (`variant_get`)

## Relationship to the Snowflake Quickstart

SHIRC is a reimplementation of the Snowflake-Labs quickstart **"Enterprise Lakehouse Platform for Iceberg V3"**:

- **Guide:** <https://www.snowflake.com/en/developers/guides/iceberg-v3-tables-comprehensive-guide/>
- **Assets:** <https://github.com/Snowflake-Labs/sfquickstarts/tree/master/site/sfguides/src/iceberg-v3-tables-comprehensive-guide>

It keeps the same Smart Fleet IoT Analytics use case, the same data model, and essentially the same feature scope. The differences below are about **how** the demo is delivered, not **what** it teaches.

### Same as the quickstart

- The 6 source Iceberg tables (`VEHICLE_TELEMETRY_STREAM`, `MAINTENANCE_LOGS`, `SENSOR_READINGS`, `VEHICLE_LOCATIONS`, `VEHICLE_REGISTRY`, `API_WEATHER_DATA`)
- The 4 dynamic tables (`TELEMETRY_ENRICHED`, `MAINTENANCE_ANALYSIS`, `DAILY_FLEET_SUMMARY`, `VEHICLE_HEALTH_SCORE`)
- Snowflake-managed storage as the default; VARIANT + semi-structured queries; time-series and geospatial (GEOGRAPHY) analytics; `ML.FORECAST`
- Governance (masking policies, DMFs, classification tags), Snowpipe Streaming, Open-Meteo API ingestion (`OPEN_METEO_ACCESS`), a Cortex / Snowflake Intelligence agent
- Cross-region replication and cross-region inference (covered as guided steps in the deployed notebook)
- Spark 4.0 cross-engine reads via the Horizon Iceberg REST catalog with vended credentials, including **masking policies enforced cross-engine** (full PII for the engineer role, masked for `FLEET_ANALYST`)

### How SHIRC differs

| Area | Quickstart | SHIRC |
|------|-----------|-------|
| Orchestration | Single `setup.sh` + `config.env` | Modular [Task](https://taskfile.dev/) workflow + `.env/iceberg.env`, SQL split into ordered scripts `001`–`010` |
| External storage providers | S3, GCS, Azure Blob/ADLS Gen2, OneLake | Snowflake-managed **and AWS S3 only** — but with full cross-account IAM policy/role/trust automation |
| Semantic layer | Ships a `fleet_semantic_model.yaml` semantic model file | Builds a native in-database `CREATE SEMANTIC VIEW` (`009-create_semantic_view.sql`) |
| Notebook | Static `fleet_analytics_notebook.ipynb` | Generated from a template via `variables.json`, then deployed with `snow` |
| Lineage | (not covered) | **Adds OpenLineage external lineage** via JWT to `/api/v2/lineage/external-lineage` + `GRANT INGEST LINEAGE ON ACCOUNT` |

### Feature coverage matrix

**Demonstrated (parity with the quickstart):**

| Capability | Where |
|------------|-------|
| `ICEBERG_VERSION_DEFAULT = 3` | `sql/init/init.sql` |
| VARIANT columns + semi-structured queries | `001-create_iceberg_tables.sql`, notebook |
| GEOGRAPHY type + geospatial / H3 analytics | `001/002-*.sql`, notebook |
| DEFAULT column values | `001-create_iceberg_tables.sql` (`VEHICLE_STATUS DEFAULT 'ACTIVE'`) |
| Dynamic Iceberg tables (incl. `REFRESH_MODE = INCREMENTAL`) | `003-create_dynamic_tables.sql` |
| Governance: masking policies, tags, DMFs | `005/006/007-*.sql` |
| Native semantic view + Cortex Agent | `009/010-*.sql` |
| Open-Meteo API ingestion + external access integration | `001/008-*.sql`, notebook (`OPEN_METEO_ACCESS`) |
| `ML.FORECAST` predictive maintenance | fleet notebook |
| Snowpipe Streaming ingestion | `pyutil/snowpipe_streaming/stream_telemetry.py` |
| Cross-region replication + cross-region inference | fleet notebook (`FLEET_ANALYTICS_REPLICATION`) |
| Cross-engine Spark 4.0 read + enforced masking via Horizon REST catalog | `pyutil/spark/spark_iceberg_interop.ipynb` |

**Added beyond the quickstart:**

| Capability | Where |
|------------|-------|
| External (OpenLineage) lineage via JWT | `stream_telemetry.py` → `/api/v2/lineage/external-lineage` |
| Cross-account AWS S3 / IAM trust automation | `tasks/aws-cli/` |

**Beyond both the guide and this repo** (broader Iceberg V3 surface area not covered by either):

| Capability | Notes |
|------------|-------|
| Merge-on-read / deletion vectors (`MERGE`/`DELETE`/`UPDATE`) | No DML against Iceberg tables yet — the headline V3 write path |
| Explicit row lineage (`_row_id`, sequence numbers) | Only used implicitly by the incremental dynamic table |
| Time travel (`AT` / `BEFORE`) | Not shown in SQL or notebook |
| Snapshot / table history inspection | No snapshot/history queries |
| Schema evolution (`ADD`/`DROP`/`RENAME COLUMN`) | Not demonstrated |
| Partitioning / clustering (`CLUSTER BY`, auto-clustering, search optimization) | No partition spec or clustering keys |
| Table maintenance & monitoring (snapshot expiration, storage metrics) | Not implemented |
| GEOMETRY type | Only GEOGRAPHY is used |

## Resources

- [Enterprise Lakehouse Platform for Iceberg V3 (quickstart guide)](https://www.snowflake.com/en/developers/guides/iceberg-v3-tables-comprehensive-guide/) - The guide this project is based on
- [sfquickstarts assets folder](https://github.com/Snowflake-Labs/sfquickstarts/tree/master/site/sfguides/src/iceberg-v3-tables-comprehensive-guide) - Source SQL, notebooks, and sample data for the guide
- [Apache Iceberg](https://iceberg.apache.org/) - Open table format specification
- [Snowflake Iceberg Tables](https://docs.snowflake.com/en/user-guide/tables-iceberg) - Snowflake Iceberg documentation
- [Snowpipe Streaming](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview) - Real-time ingestion
- [Task Documentation](https://taskfile.dev/) - Task runner documentation
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/) - AWS CLI documentation
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake CLI documentation

## License

This project is provided as-is for educational and demonstration purposes.
