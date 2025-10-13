# Prerequisites Validation Script

## Overview

The `validate-prerequisites.sh` script checks that all required tools and configurations are properly installed and configured before running the main Snowflake Iceberg scripts.

## Usage

```shell
./validate-prerequisites.sh
```

## What It Checks

The script validates the following prerequisites:

1. **AWS CLI** - Required for S3 bucket operations
2. **AWS Credentials** - Ensures AWS is properly configured
3. **task CLI** - Task runner for automation (optional)
4. **Snowflake CLI** - Required for Snowflake operations
5. **Environment Configuration** - Validates `.env/iceberg.env` file with AWS_REGION

## Features

### ✅ Success Tracking

- Tracks each validation check
- Shows ✅ for successful checks
- Shows ❌ for failed checks

### 📊 Failure Summary

If any checks fail, the script:

- Continues running all checks (doesn't exit early)
- Counts total failures
- Lists all failed checks at the end
- Exits with error code 1

### 🎯 Clear Exit Status

- **Exit 0**: All checks passed
- **Exit 1**: One or more checks failed

### 💾 Validation Flag File

When all checks pass, the script creates a flag file at `tasks/.prerequisites_validated` containing:

- Validation status
- Timestamp of last validation
- Status of each checked component

This flag file is automatically removed if validation fails on subsequent runs.

## Sample Output

### All Checks Pass

```shell
╔════════════════════════════════════════════════════════════╗
║         Prerequisites Validation Script                   ║
╚════════════════════════════════════════════════════════════╝

----------------------------------------------------------
✅ AWS CLI is installed.
----------------------------------------------------------
✅ AWS credentials are configured.
----------------------------------------------------------
✅ task CLI is installed.
----------------------------------------------------------
✅ Snowflake CLI (snow) is installed.
----------------------------------------------------------

╔════════════════════════════════════════════════════════════╗
║                    ✅ ALL CHECKS PASSED                    ║
╚════════════════════════════════════════════════════════════╝

All prerequisites have been validated successfully!
```

### Some Checks Fail

```shell
╔════════════════════════════════════════════════════════════╗
║         Prerequisites Validation Script                   ║
╚════════════════════════════════════════════════════════════╝

----------------------------------------------------------
✅ AWS CLI is installed.
----------------------------------------------------------
❌ Error: AWS credentials are not configured.
   Please run: aws configure
----------------------------------------------------------
❌ Error: task CLI is not installed.
   To install task CLI, run: brew install go-task/tap/go-task
----------------------------------------------------------
✅ Snowflake CLI (snow) is installed.
----------------------------------------------------------

╔════════════════════════════════════════════════════════════╗
║                  ⚠️  VALIDATION FAILED                     ║
╚════════════════════════════════════════════════════════════╝

❌ 2 check(s) failed!

Failed checks:
  • AWS credentials
  • task CLI

Please review the error messages above and install the missing
prerequisites before proceeding.
```

## Checking Validation Status

### Using the Helper Script

Use `check-validation.sh` to verify prerequisites without re-running validation:

```shell
./check-validation.sh
```

**Output if validated:**

```shell
✅ Prerequisites validated
   Status: passed
   Last checked: 2025-10-13 09:45:23 UTC

Validated components:
   • AWS CLI: installed
   • AWS Credentials: configured
   • Task CLI: installed
   • Snowflake CLI: installed
```

**Output if not validated:**

```shell
❌ Prerequisites not validated.
   Please run: ./validate-prerequisites.sh
```

### Checking in Scripts

```shell
# Check validation status before proceeding
if [ -f "tasks/.prerequisites_validated" ]; then
    echo "Prerequisites already validated, proceeding..."
else
    echo "Prerequisites not validated, running validation..."
    ./validate-prerequisites.sh || exit 1
fi
```

### Reading Validation Data

```shell
# Source the validation file to access variables
if [ -f "tasks/.prerequisites_validated" ]; then
    source tasks/.prerequisites_validated
    echo "Validation status: $VALIDATION_STATUS"
    echo "Last validated: $VALIDATION_TIMESTAMP"
fi
```

## Integration with Other Scripts

Use this script before running main operations:

```shell
# Validate prerequisites first
if ./validate-prerequisites.sh; then
    echo "Prerequisites validated, proceeding..."
    ./aws/create_s3_bucket.sh
else
    echo "Prerequisites validation failed. Please fix errors and try again."
    exit 1
fi
```

Or check if already validated:

```shell
# Check if validation exists, run if not
if ! ./check-validation.sh 2>/dev/null; then
    echo "Running prerequisite validation..."
    ./validate-prerequisites.sh || exit 1
fi

# Proceed with main operations
./aws/create_s3_bucket.sh
```

## Installing Missing Prerequisites

### AWS CLI

**macOS:**

```shell
brew install awscli
```

**Linux:**

```shell
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Configure:**

```shell
aws configure
```

### task CLI

**macOS:**

```shell
brew install go-task/tap/go-task
```

**Linux:**

```shell
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

**Verify:**

```shell
task --version
```

### Snowflake CLI

Follow the [official installation guide](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation)

**Verify:**

```shell
snow --version
```

### Environment Configuration

Create the `.env/iceberg.env` configuration file:

#### **Step 1: Create from template**

```shell
cp .env/iceberg.env.template .env/iceberg.env
```

#### **Step 2: Edit with your values**

```shell
# Edit the file
nano .env/iceberg.env

# At minimum, ensure AWS_REGION is set to a valid region
AWS_REGION=us-east-1
```

**Valid AWS Regions:**

- US: `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2`
- EU: `eu-west-1`, `eu-west-2`, `eu-west-3`, `eu-central-1`
- Asia: `ap-southeast-1`, `ap-southeast-2`, `ap-northeast-1`
- Others: See [AWS Regions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)

**Verify:**

```shell
# Check file exists and has AWS_REGION
grep AWS_REGION .env/iceberg.env
```

## Environment Variables

### AWS_REGION

The script uses `AWS_REGION` (or defaults to `us-east-1`) when checking AWS credentials:

```shell
# Set custom region
export AWS_REGION=us-west-2

# Run validation
./validate-prerequisites.sh
```

## Troubleshooting

### "command not found" for installed tools

Ensure the tool is in your `PATH`:

```shell
echo $PATH
```

Add to your shell profile if needed:

```shell
# ~/.shellrc or ~/.zshrc
export PATH="$PATH:/path/to/tool"
```

### AWS credentials check fails

1. Run `aws configure` to set up credentials
2. Verify credentials file exists: `~/.aws/credentials`
3. Check credentials are valid:
  
```shell
aws sts get-caller-identity
```

### Permission denied

Make the script executable:

```shell
chmod +x validate-prerequisites.sh
```

## Customization

To add additional checks, follow this pattern:

```shell
# Check for your tool
echo "----------------------------------------------------------"
if command -v your-tool >/dev/null 2>&1; then
    echo "✅ Your tool is installed."
else
    echo "❌ Error: Your tool is not installed."
    echo "   To install: brew install your-tool"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=("Your tool")
fi
```

## Best Practices

1. **Run before deployments** - Always validate before running main scripts
2. **CI/CD integration** - Use in build pipelines to catch missing tools early
3. **Team onboarding** - New team members can quickly verify their setup
4. **Environment validation** - Confirm environment is properly configured

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All prerequisites validated successfully |
| 1 | One or more prerequisites missing or misconfigured |

## See Also

- [README.md](README.md) - Main project documentation
- [aws/README.md](aws/README.md) - AWS scripts documentation
- [SNOWFLAKE_ICEBERG_GUIDE.md](SNOWFLAKE_ICEBERG_GUIDE.md) - Snowflake setup guide
