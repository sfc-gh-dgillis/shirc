# Environment Configuration Directory

This directory contains environment configuration files for the Iceberg project.

## Files

### `iceberg.env.template`

Template file for environment configuration. Copy this to `iceberg.env` and fill in your values.

### `iceberg.env` (you create this)

Your actual environment configuration. This file is git-ignored and contains sensitive values.

## Setup

1. Copy the template:
   ```shell
   cp .env/iceberg.env.template .env/iceberg.env
   ```

2. Edit the file with your values:
   ```shell
   nano .env/iceberg.env
   # or
   vi .env/iceberg.env
   ```

3. Required values:
   - `AWS_REGION` - Must be a valid AWS region (e.g., us-east-1)
   
4. Optional values:
   - `AWS_PROFILE` - AWS profile to use (uncomment and set if using named profiles)
   - `AWS_S3_BUCKET` - Your S3 bucket name
   - `AWS_S3_FOLDER` - S3 folder/prefix for organizing Iceberg data
   - `SNOWFLAKE_ACCOUNT` - Your Snowflake account identifier
   - `SNOWFLAKE_WAREHOUSE` - Snowflake warehouse name
   - `SNOWFLAKE_DATABASE` - Snowflake database name
   - `SNOWFLAKE_ROLE` - Snowflake role

5. Run validation:
   ```shell
   ./validate-prerequisites.sh
   ```

## Configuration Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AWS_PROFILE` | No | - | AWS profile name (if not set, uses default credential chain) |
| `AWS_REGION` | **Yes** | us-east-1 | AWS region for S3 and services |
| `AWS_S3_BUCKET` | No | shirc-demo | S3 bucket for Iceberg tables |
| `AWS_S3_FOLDER` | No | snowflake-iceberg | S3 folder/prefix for Iceberg data |
| `SNOWFLAKE_ACCOUNT` | No | - | Snowflake account identifier |
| `SNOWFLAKE_WAREHOUSE` | No | COMPUTE_WH | Snowflake warehouse name |
| `SNOWFLAKE_DATABASE` | No | iceberg_db | Snowflake database name |
| `SNOWFLAKE_ROLE` | No | ACCOUNTADMIN | Snowflake role |

## AWS Profile Configuration

### When to Use AWS_PROFILE

Use `AWS_PROFILE` in `.env/iceberg.env` when:
- You have multiple AWS accounts and want to use a non-default profile
- You want to configure the profile once rather than export it each time
- You're working on a team project with a standard profile name

### Priority Order

The validation script uses this order (highest to lowest priority):
1. `AWS_PROFILE` environment variable (if already exported)
2. `AWS_PROFILE` from `.env/iceberg.env` (if set)
3. Default AWS credential chain (environment vars → default profile → IAM role)

### Example Configurations

**Using default profile (no AWS_PROFILE needed):**
```shell
# .env/iceberg.env
#AWS_PROFILE=
AWS_REGION=us-east-1
```

**Using a named profile:**
```shell
# .env/iceberg.env
AWS_PROFILE=production
AWS_REGION=us-west-2
```

**Overriding the file setting:**
```shell
# In shell
export AWS_PROFILE=staging

# This overrides the file setting
./validate-prerequisites.sh
```

## Validation

The `validate-prerequisites.sh` script checks:

1. ✅ `.env` directory exists
2. ✅ `iceberg.env` file exists
3. ✅ `AWS_REGION` variable is defined
4. ✅ `AWS_REGION` value is a valid AWS region
5. ✅ Loads `AWS_PROFILE` if set (and not already in environment)

## Valid AWS Regions

Common regions:
- `us-east-1` - US East (N. Virginia)
- `us-east-2` - US East (Ohio)
- `us-west-1` - US West (N. California)
- `us-west-2` - US West (Oregon)
- `eu-west-1` - Europe (Ireland)
- `eu-central-1` - Europe (Frankfurt)
- `ap-southeast-1` - Asia Pacific (Singapore)
- `ap-northeast-1` - Asia Pacific (Tokyo)

See [AWS Regions and Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for the complete list.

## Security

- ⚠️ **Never commit `iceberg.env`** - It contains sensitive configuration
- ✅ The file is automatically git-ignored
- ✅ Template file is safe to commit
- 🔒 Keep AWS credentials separate (use `aws configure`)
- 🔒 Keep Snowflake passwords separate (use environment variables)

## Troubleshooting

### Validation fails for .env directory

Create the directory:
```shell
mkdir .env
```

### Validation fails for iceberg.env file

Copy the template:
```shell
cp .env/iceberg.env.template .env/iceberg.env
```

### Invalid AWS_REGION

Edit the file and set a valid region:
```shell
# In .env/iceberg.env
AWS_REGION=us-east-1
```

### AWS_PROFILE not working

Check that:
1. The profile exists: `aws configure list-profiles`
2. The profile has credentials: `aws sts get-caller-identity --profile YOUR_PROFILE`
3. No environment variable is overriding it: `echo $AWS_PROFILE`

### Want to override file AWS_PROFILE

Export the environment variable before running:
```shell
export AWS_PROFILE=different-profile
./validate-prerequisites.sh
```

### Permission errors

Ensure files are readable:
```shell
chmod 644 .env/iceberg.env
```

## See Also

- [VALIDATION_GUIDE.md](../archive/VALIDATION_GUIDE.md) - Prerequisites validation documentation
- [AWS_PROFILE_GUIDE.md](../aws/AWS_PROFILE_GUIDE.md) - AWS profile configuration guide
- [README.md](../archive/README.md) - Main project documentation
- [aws/README.md](../aws/README.md) - AWS scripts documentation
