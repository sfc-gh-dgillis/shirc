# SHIRC - Snowflake Horizon Iceberg REST Catalog

> Automated setup and management of AWS and Snowflake resources for Apache Iceberg tables

## 📚 Overview

SHIRC provides automated infrastructure setup for working with Apache Iceberg tables through Snowflake's Horizon REST catalog. Using Task automation, it handles:

- **AWS Resources**: S3 buckets, IAM policies, and roles with trust relationships
- **Snowflake Resources**: External volumes configured for Iceberg storage
- **Integration**: Automatic trust policy updates to connect AWS and Snowflake

## 🚀 Quick Start

### One-Command Setup

```bash
# 1. Configure environment
cp .env/iceberg.env.template .env/iceberg.env
# Edit .env/iceberg.env with your values

# 2. Set up everything
task demo-up
```

That's it! This single command will:

- ✅ Create S3 bucket for Iceberg data
- ✅ Create IAM policy for bucket access
- ✅ Create IAM role with trust policy
- ✅ Create Snowflake external volume
- ✅ Update trust policy with Snowflake's IAM user

### Teardown

```bash
# Clean up all resources
task demo-teardown
```

## 📋 Prerequisites

- [Task](https://taskfile.dev/) - Task runner (install: `brew install go-task`)
- [AWS CLI](https://aws.amazon.com/cli/) - AWS command line interface
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake command line interface
- [jq](https://stedolan.github.io/jq/) - JSON processor (install: `brew install jq`)
- AWS credentials configured
- Snowflake credentials configured

### Validate Prerequisites

```bash
task validate-prerequisites:awscli
task validate-prerequisites:snowcli
```

## ⚙️ Configuration

### Environment Variables

Edit `.env/iceberg.env`:

```bash
# AWS Configuration
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
S3_PREFIX=snowflake-iceberg
IAM_POLICY_NAME=YourIcebergAccessPolicy
IAM_ROLE_NAME=YourIcebergAccessRole
TRUST_POLICY_EXTERNAL_ID=your-external-id

# Snowflake Configuration
EXTERNAL_VOLUME_NAME=iceberg_ext_vol
```

## 🎯 Available Tasks

### Main Tasks

| Task                 | Description                                             |
|----------------------|---------------------------------------------------------|
| `task demo-up`       | Complete setup: AWS + Snowflake + integration           |
| `task demo-teardown` | Complete teardown: remove all resources                 |

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

| Task                                   | Description                              |
|----------------------------------------|------------------------------------------|
| `task snowflake-resources-up`          | Create and describe external volume      |
| `task snowflake-resources-teardown`    | Drop external volume                     |
| `task snow-cli:create-external-volume` | Create external volume only              |
| `task snow-cli:drop-external-volume`   | Drop external volume only                |
| `task snow-cli:desc-external-volume`   | Describe external volume and save JSON   |

## 🏗️ Architecture

### What Gets Created

```text
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                         │
│                                                             │
│  ┌─────────────────────┐      ┌────────────────────────┐  │
│  │   S3 Bucket         │      │   IAM Role             │  │
│  │   your-bucket       │◄─────┤   YourIcebergRole      │  │
│  │   └─ iceberg/       │      │   (Trust Policy)       │  │
│  └─────────────────────┘      └────────────────────────┘  │
│                                          ▲                  │
│                                          │                  │
│  ┌─────────────────────────────────────┐│                  │
│  │   IAM Policy                        ││                  │
│  │   YourIcebergAccessPolicy           ││                  │
│  │   (S3 permissions)                  ││                  │
│  └─────────────────────────────────────┘│                  │
│                                          │                  │
└──────────────────────────────────────────┼──────────────────┘
                                           │
                                           │ AssumeRole
                                           │
┌──────────────────────────────────────────┼──────────────────┐
│                    Snowflake             │                  │
│                                          │                  │
│  ┌──────────────────────────────────────▼──────────────┐  │
│  │   External Volume: iceberg_ext_vol                   │  │
│  │   - Storage: s3://your-bucket/iceberg/               │  │
│  │   - Role ARN: arn:aws:iam::xxx:role/YourRole         │  │
│  │   - External ID: your-external-id                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 📖 Usage Examples

### Complete Setup and Teardown

```bash
# Set up everything
task demo-up

# Use your Iceberg tables in Snowflake
# (create tables, insert data, query, etc.)

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

## 📁 Repository Structure

```text
shirc/
├── Taskfile.yml                      # Main task definitions
├── .env/
│   ├── iceberg.env.template          # Configuration template
│   └── iceberg.env                   # Your config (git-ignored)
├── tasks/
│   ├── aws-cli/
│   │   ├── awscli-tasks.yml          # AWS CLI task definitions
│   │   ├── cmd/                      # AWS CLI scripts
│   │   │   ├── make-bucket.sh
│   │   │   ├── delete-bucket.sh
│   │   │   ├── create-iam-policy.sh
│   │   │   ├── delete-iam-policy.sh
│   │   │   ├── create-iam-role.sh
│   │   │   ├── delete-iam-role.sh
│   │   │   ├── attach-policy-to-role.sh
│   │   │   ├── detach-policy-from-role.sh
│   │   │   ├── generate-iam-policy-for-bucket-access.sh
│   │   │   ├── generate-trust-policy.sh
│   │   │   └── update-trust-policy-with-snowflake-user.sh
│   │   └── json/
│   │       ├── template/             # JSON templates
│   │       ├── output/               # Generated policies
│   │       └── aws-output.json       # AWS resource metadata
│   ├── snow-cli/
│   │   ├── snow-cli-tasks.yml        # Snowflake CLI task definitions
│   │   ├── cmd/                      # Snowflake CLI scripts
│   │   │   ├── create-external-volume.sh
│   │   │   ├── drop-external-volume.sh
│   │   │   └── desc-external-volume.sh
│   │   ├── batch-0/                  # SQL templates
│   │   │   ├── create_external_volume.sql
│   │   │   ├── drop_external_volume.sql
│   │   │   └── desc_external_volume.sql
│   │   └── json/                     # Snowflake outputs
│   │       ├── external-volume-desc.json
│   │       └── external-volume-desc-storage-location.json
│   └── validate-prerequisites/
│       └── validate-prerequisite-tasks.yml
└── README.md                         # This file
```

## 🔧 How It Works

### AWS Resources Setup

1. **S3 Bucket**: Created in your specified region with the configured prefix
2. **IAM Policy**: Generated from template with S3 permissions (ListBucket, GetObject, PutObject, DeleteObject)
3. **IAM Role**: Created with initial trust policy (trusts your AWS account)
4. **Policy Attachment**: IAM policy attached to the role

### Snowflake Integration

1. **External Volume**: Created in Snowflake pointing to your S3 bucket
2. **Description**: External volume details retrieved including Snowflake's IAM user ARN
3. **Trust Policy Update**: AWS role trust policy updated to allow Snowflake's IAM user to assume the role

### Resource Metadata

All resource details are stored in JSON files:

- `tasks/aws-cli/json/aws-output.json` - AWS resource ARNs and metadata
- `tasks/snow-cli/json/external-volume-desc.json` - Full external volume description
- `tasks/snow-cli/json/external-volume-desc-storage-location.json` - Storage location details

## 🔒 Security Best Practices

1. **Never commit credentials** to version control
2. **Use `.env` files** for configuration (already git-ignored)
3. **Rotate external IDs** regularly
4. **Use least-privilege IAM policies**
5. **Enable MFA** on AWS and Snowflake accounts
6. **Review trust policies** before deployment
7. **Use separate environments** for dev/staging/prod

## 🐛 Troubleshooting

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

### Debug Mode

View detailed output by checking the script execution:

```bash
# View AWS output
cat tasks/aws-cli/json/aws-output.json | jq '.'

# View Snowflake external volume details
cat tasks/snow-cli/json/external-volume-desc-storage-location.json | jq '.'
```

## 📚 Resources

### Documentation

- [Apache Iceberg](https://iceberg.apache.org/) - Open table format specification
- [Snowflake Iceberg Tables](https://docs.snowflake.com/en/user-guide/tables-iceberg) - Snowflake Iceberg documentation
- [Task Documentation](https://taskfile.dev/) - Task runner documentation
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/) - AWS CLI documentation
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli) - Snowflake CLI documentation

### Related Projects

- [PyIceberg](https://py.iceberg.apache.org/) - Python client for Apache Iceberg
- [Apache Iceberg REST Catalog](https://iceberg.apache.org/docs/latest/rest/) - REST catalog specification

## 🎓 What You Get

After running `task demo-up`, you'll have:

- ✅ S3 bucket ready for Iceberg data storage
- ✅ IAM role with proper permissions and trust policy
- ✅ Snowflake external volume configured and integrated
- ✅ All resource metadata saved in JSON files
- ✅ Full integration between AWS and Snowflake

You can then create Iceberg tables in Snowflake:

```sql
-- Create an Iceberg table using your external volume
CREATE ICEBERG TABLE my_iceberg_table (
  id INT,
  name STRING,
  created_at TIMESTAMP
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'iceberg_ext_vol'
BASE_LOCATION = 'my_table';

-- Insert data
INSERT INTO my_iceberg_table VALUES (1, 'test', CURRENT_TIMESTAMP());

-- Query data
SELECT * FROM my_iceberg_table;
```

## 🤝 Contributing

Contributions welcome! Areas for enhancement:

- Additional Snowflake resource types (catalogs, schemas)
- Support for multiple external volumes
- Automated testing scripts
- CI/CD pipeline integration
- Terraform/CloudFormation alternatives

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

**Note:** This project automates the setup of AWS and Snowflake resources for Apache Iceberg table integration. It demonstrates infrastructure-as-code principles using Task automation and shell scripting.
