# AGENTS.md

This file provides guidance to AI coding agents (such as Snowflake Cortex Code CLI) when working with code in this repository.

## Project Overview

SHIRC (Snowflake Horizon Iceberg REST Catalog) automates the setup of AWS and Snowflake infrastructure for Apache Iceberg V3 tables, and provisions a full Fleet IoT analytics demo on top of it. It uses [Task](https://taskfile.dev/) as the primary automation runner, with shell scripts, Python utilities, and SQL files doing the actual work.

Beyond infrastructure, the demo builds an end-to-end lakehouse: source Iceberg tables, dynamic (declarative) Iceberg tables, governance (masking/tags/DMFs), a native semantic view, a Cortex Agent, Snowpipe Streaming ingestion with OpenLineage external lineage, and Spark 4.0 cross-engine access via the Horizon REST catalog.

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
task snow-cli:run-init                        # init SQL (warehouse, roles, DB, schemas, stage)
task snow-cli:sort-and-process-sql-folder     # batch-1 analytics pipeline (001–010, in order)
task snow-cli:generate-fleet-notebook
task snow-cli:deploy-notebook

# Stream simulated telemetry via Snowpipe Streaming (auto-creates .venv, installs requirements.txt)
task stream-telemetry                         # default 100 events
task stream-telemetry EVENT_COUNT=500

# Optional troubleshooting (creates ingress network policy for the streaming script)
task apply-network-policy

# AWS SSO
task aws-cli:refresh-sso-token AWS_PROFILE=my-profile
```

## Architecture

### Task Flow

`infrastructure-up` routes by `STORAGE_MODE`:

- **managed**: validate Snow CLI → run init SQL (no AWS).
- **external**: AWS resources (S3 bucket → IAM policy → IAM role → attach) → create + describe external volume (saves Snowflake IAM user ARN to `output/`) → update AWS trust policy with that ARN (cross-account access) → run init SQL.

Init SQL runs three files in sequence: `sql/init/init.sql` (warehouse, roles, database with `ICEBERG_VERSION_DEFAULT = 3`, medallion schemas, stage, external access integration), then the mode-specific storage file (`init_storage_managed.sql` or `init_storage_external.sql`). Storage mode is selected by which file runs — **not** by conditionals inside a single file.

`demo-up` then layers the demo on top of `infrastructure-up`:
1. Upload files to the Snowflake internal named stage.
2. Run the batch-1 analytics pipeline (`sort-and-process-sql-folder` → scripts 001–010, executed in numeric order by `pyutil/snowclisp`).
3. Generate the fleet analytics notebook from its template (`generate-fleet-notebook`).
4. Deploy the notebook to Snowflake (`deploy-notebook`).

### Batch-1 Analytics Pipeline (`sql/batch-1/`, run in order)

| Script | Purpose |
|--------|---------|
| `001-create_iceberg_tables.sql` | 6 source Iceberg V3 tables (VARIANT, GEOGRAPHY, DEFAULT-valued columns) |
| `002-load_iceberg_lookup_tables.sql` | Seed lookup / sample data |
| `003-create_dynamic_tables.sql` | 4 dynamic Iceberg tables (one `REFRESH_MODE = INCREMENTAL`) |
| `004-grants.sql` | Role hierarchy + `GRANT INGEST LINEAGE ON ACCOUNT` |
| `005-masking_policies.sql` | PII masking policies on `VEHICLE_REGISTRY` |
| `006-dmfs.sql` | Data metric functions applied to Iceberg tables |
| `007-tags.sql` | Governance tags at table + column level |
| `008-load_sample_data.sql` | `COPY INTO` from stage + additional rows |
| `009-create_semantic_view.sql` | Native `CREATE SEMANTIC VIEW` over the Iceberg tables |
| `010-create_agent.sql` | Cortex Agent (`cortex_analyst_text_to_sql`) + helper views |

### Streaming + External Lineage

`pyutil/snowpipe_streaming/stream_telemetry.py` simulates a vehicle fleet and ingests VARIANT events via the Snowpipe Streaming SDK (keypair auth resolved from the named `snow` CLI connection). After streaming, it POSTs an OpenLineage COMPLETE event to `/api/v2/lineage/external-lineage`, authenticating with a JWT from `snow connection generate-jwt` (no PAT). The `stream-telemetry` task runs via `cmd/stream-telemetry.sh`, which bootstraps `.venv` and installs `requirements.txt` before invoking the script.

### Spark Interoperability

`tasks/snow-cli/pyutil/spark/spark_iceberg_interop.ipynb` is a Spark 4.0 notebook that reads the fleet Iceberg V3 tables (including `variant_get` on the `TELEMETRY_DATA` VARIANT column) through the Snowflake Horizon REST catalog with vended credentials. It uses **two** named `snow` CLI connections (same account): the project's shared **key-pair** connection (`CLI_KEYPAIR_CONNECTION_NAME`, also used by streaming and notebook deploy) that mints the Horizon REST catalog **JWT** via `snow connection generate-jwt` (no PAT — `generate-jwt` mandatorily requires a private-key connection), and a **password** connection (`SPARK_PASSWORD_CONNECTION_NAME`) that drives the `spark-snowflake` connector (`spark.snowflake.sfPassword`) and supplies account/user/role. The Spark-only vars live in their own `.env/spark.env` (copied from `.env/spark.env.template`), which `cmd/run-spark-jupyter.sh` sources in addition to the shared `.env/iceberg.env`. It demonstrates **masking policies enforced cross-engine** — full PII as the engineer role vs masked PII as `FLEET_ANALYST`. `task spark-demo-up` provisions infrastructure then runs `snow-cli:run-spark-jupyter`, which bootstraps a venv via `cmd/run-spark-jupyter.sh` (uv/venv pattern, no conda; requires Java 17+) and launches Jupyter.

### Output Files

All commands write metadata to `output/` (git-ignored):
- `output/aws-output.json` — ARNs for created IAM policy and role (read by subsequent tasks)
- `output/bucket-policy-output.json` — Generated IAM policy document
- `output/trust-policy-output.json` — Generated IAM role trust policy
- `output/trust-policy-updated.json` — Trust policy updated with Snowflake IAM user
- `output/external-volume-desc.json` — Full Snowflake external volume description
- `output/external-volume-desc-storage-location.json` — Parsed storage location details

The generated fleet notebook is written to `tasks/snow-cli/notebook/fleet_analytics_notebook/generated/` (the `templates/` copy is the source).

Tasks are stateful and share data via these JSON files. Tasks like `delete-iam-policy`, `attach-policy-to-role`, and `update-trust-policy-with-snowflake-user` read ARNs from `output/aws-output.json` rather than accepting them as parameters.

### Directory Structure

```
Taskfile.yml                       # Root orchestration, includes sub-taskfiles
.env/
  iceberg.env.template             # Copy to iceberg.env and configure (shared demo config)
  spark.env.template               # Copy to spark.env (Spark connector creds + runtime; Spark demo only)
tasks/
  aws-cli/
    awscli-tasks.yml               # AWS CLI task definitions
    cmd/                           # Shell scripts for AWS operations
    json/template/                 # JSON templates (bucket-policy, trust-policy)
  snow-cli/
    snowcli-tasks.yml              # Snowflake CLI task definitions (runs from tasks/snow-cli/ dir)
    cmd/                           # Shell scripts for Snowflake operations (incl. stream-telemetry.sh)
    sql/init/                      # Init SQL: init.sql + init_storage_{managed,external}.sql + create_external_volume.sql
    sql/batch-1/                   # Analytics pipeline 001–010 (tables, dynamic tables, governance, semantic view, agent)
    sql/network_policy.sql         # Optional ingress NETWORK RULE + NETWORK POLICY (run via task apply-network-policy)
    notebook/fleet_analytics_notebook/  # templates/ (source) + generated/ (deployed)
    pyutil/snowcliput/             # Python utility for uploading files to Snowflake stages
    pyutil/snowclisp/              # Python utility that runs the batch-1 SQL pipeline in order
    pyutil/snowpipe_streaming/     # Snowpipe Streaming simulator + external lineage (stream_telemetry.py)
    pyutil/spark/                  # Spark 4.0 + Horizon REST interop notebook (spark_iceberg_interop.ipynb)
  validate-prerequisites/
    validate-prerequisite-tasks.yml
output/                            # Generated files (git-ignored)
upload/                            # Files to upload to Snowflake internal stage
```

### SQL Templating

SQL files use Snowflake CLI **standard templating** with `<% ctx.env.VAR %>` placeholders (not Jinja `{{ }}`). Values come from the env vars exported by `task` from `.env/iceberg.env`, surfaced through `snowflake.yml` in the execution directory. `snowflake.yml` must be in the CWD where `snow sql` runs (`tasks/snow-cli/`). See memory for the full variable-passing convention.

### snow-cli Task Directory

The `snow-cli` taskfile is included with `dir: ./tasks/snow-cli`, so all paths within `snowcli-tasks.yml` are relative to `tasks/snow-cli/` (e.g., `cmd/create-external-volume.sh`, not `tasks/snow-cli/cmd/...`). Output files use `../../output/` to reach the repo root.

## Iceberg V3 Feature Coverage

This repo is a reimplementation of the Snowflake-Labs quickstart *"Enterprise Lakehouse Platform for Iceberg V3"* ([guide](https://www.snowflake.com/en/developers/guides/iceberg-v3-tables-comprehensive-guide/), [assets](https://github.com/Snowflake-Labs/sfquickstarts/tree/master/site/sfguides/src/iceberg-v3-tables-comprehensive-guide)). It keeps the same use case, data model, and feature scope; differences are in delivery, not curriculum. When adding features, prefer closing the broader-V3 gaps below over duplicating what already exists.

**Demonstrated (parity with the quickstart):** `ICEBERG_VERSION_DEFAULT = 3`, VARIANT + semi-structured queries, GEOGRAPHY + H3 geospatial, DEFAULT column values, dynamic Iceberg tables (incl. `REFRESH_MODE = INCREMENTAL`), masking policies, tags, DMFs, native semantic view, Cortex Agent, `ML.FORECAST`, Open-Meteo API ingestion (`OPEN_METEO_ACCESS`), Snowpipe Streaming, cross-region replication + cross-region inference (notebook), Spark 4.0 cross-engine read (`variant_get`).

**How this repo differs from the quickstart:** Task workflow + ordered SQL `001`–`010` instead of `setup.sh` + `config.env`; managed + AWS S3 only (with cross-account IAM trust automation) vs. the guide's S3/GCS/Azure/OneLake; native `CREATE SEMANTIC VIEW` instead of the guide's `fleet_semantic_model.yaml`; template-generated notebook; **adds** OpenLineage external lineage (JWT) which the guide does not cover.

**Beyond both the guide and this repo** (broader Iceberg V3 surface not covered by either): merge-on-read / deletion vectors (`MERGE`/`DELETE`/`UPDATE` on Iceberg), explicit row lineage (`_row_id`), time travel (`AT`/`BEFORE`), snapshot/history inspection, schema evolution (`ADD`/`DROP`/`RENAME COLUMN`), partitioning/clustering (`CLUSTER BY`, auto-clustering, search optimization), table maintenance & monitoring (snapshot expiration, storage metrics), GEOMETRY type. See the "Relationship to the Snowflake Quickstart" section in `README.md` for the detailed matrix.

