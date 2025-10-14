# AWS Profile Configuration Guide

## Overview

The validation script supports multiple ways to configure AWS credentials, following AWS CLI's standard credential chain.

## Credential Chain Order

The script checks credentials in this order:

1. **Environment Variables** - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
2. **AWS_PROFILE** - Named profile from `~/.aws/credentials`
3. **Default Profile** - The `[default]` profile in `~/.aws/credentials`
4. **IAM Roles** - EC2 instance role or ECS task role

## Usage Examples

### 1. Default Profile (Simplest)

No environment variables needed. Uses `[default]` profile:

```shell
./validate-prerequisites.sh
```

**Output:**
```
✅ AWS credentials are configured.
   Account: 123456789012
   Identity: my-user
```

### 2. Named Profile

Use a specific AWS profile for multi-account setups:

```shell
# Set profile for this session
export AWS_PROFILE=production

# Run validation
./validate-prerequisites.sh
```

**Output:**
```
✅ AWS credentials are configured (using profile: production).
   Account: 987654321098
   Identity: prod-user
```

### 3. Temporary Override

Use a profile just for one command:

```shell
# One-time use
AWS_PROFILE=staging ./validate-prerequisites.sh
```

### 4. Combined with Region

Specify both profile and region:

```shell
export AWS_PROFILE=production
export AWS_REGION=eu-west-1
./validate-prerequisites.sh
```

## AWS Profile Setup

### Creating Named Profiles

**Interactive setup:**
```shell
# Configure default profile
aws configure

# Configure named profile
aws configure --profile production
```

**Manual configuration in `~/.aws/credentials`:**
```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[production]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY

[staging]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**And `~/.aws/config`:**
```ini
[default]
region = us-east-1
output = json

[profile production]
region = us-west-2
output = json

[profile staging]
region = eu-west-1
output = json
```

## Common Scenarios

### Scenario 1: Development Machine

Use default profile for local development:

```shell
# One-time setup
aws configure

# Always works
./validate-prerequisites.sh
```

### Scenario 2: Multiple AWS Accounts

Switch between accounts using profiles:

```shell
# Development account
export AWS_PROFILE=dev
./validate-prerequisites.sh

# Production account
export AWS_PROFILE=prod
./validate-prerequisites.sh
```

### Scenario 3: CI/CD Pipeline

Use environment variables (no profile needed):

```shell
# In CI/CD, set environment variables
export AWS_ACCESS_KEY_ID=$CI_AWS_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$CI_AWS_SECRET_KEY
export AWS_REGION=us-east-1

# Run validation
./validate-prerequisites.sh
```

### Scenario 4: EC2 Instance

Use IAM instance role (no credentials needed):

```shell
# On EC2 with instance role attached
# No AWS credentials needed!
./validate-prerequisites.sh
```

## Checking Your Configuration

### List Available Profiles

```shell
aws configure list-profiles
```

**Output:**
```
default
production
staging
dev
```

### Check Current Profile

```shell
echo $AWS_PROFILE
```

If empty, using default profile.

### Verify Credentials

```shell
# Test default
aws sts get-caller-identity

# Test specific profile
aws sts get-caller-identity --profile production

# Test with environment variable
AWS_PROFILE=staging aws sts get-caller-identity
```

## Troubleshooting

### Error: "AWS credentials are not configured"

**Check 1: Profile exists**
```shell
aws configure list-profiles
```

**Check 2: Profile has credentials**
```shell
cat ~/.aws/credentials | grep -A2 "\[$AWS_PROFILE\]"
```

**Check 3: Credentials are valid**
```shell
aws sts get-caller-identity --profile $AWS_PROFILE
```

### Error: "The config profile could not be found"

The profile doesn't exist. Create it:
```shell
aws configure --profile missing-profile
```

### Error: "Unable to locate credentials"

**Solution 1: Configure default profile**
```shell
aws configure
```

**Solution 2: Set AWS_PROFILE**
```shell
export AWS_PROFILE=your-profile-name
```

**Solution 3: Set credentials as environment variables**
```shell
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

### Wrong Profile Being Used

**Check which profile is active:**
```shell
echo $AWS_PROFILE
aws sts get-caller-identity
```

**Clear profile to use default:**
```shell
unset AWS_PROFILE
```

## Best Practices

### 1. Use Named Profiles for Multiple Accounts
```shell
# ~/.bashrc or ~/.zshrc
alias aws-dev='export AWS_PROFILE=development'
alias aws-prod='export AWS_PROFILE=production'
alias aws-default='unset AWS_PROFILE'
```

### 2. Set Default Region in Profile
```ini
# ~/.aws/config
[profile production]
region = us-west-2
output = json
```

### 3. Use MFA for Sensitive Profiles
```ini
# ~/.aws/config
[profile production]
region = us-west-2
mfa_serial = arn:aws:iam::123456789012:mfa/user
```

### 4. Document Your Profiles
Create a `~/.aws/README` file:
```
Profiles:
- default: Personal AWS account (us-east-1)
- production: Company prod account (us-west-2)
- staging: Company staging account (eu-west-1)
- dev: Company dev account (us-east-1)
```

### 5. Environment Variable Precedence

Remember the order:
1. `AWS_PROFILE` (most specific)
2. Profile in config files
3. Default profile
4. IAM roles (least specific)

## Integration with Other Scripts

### In Shell Scripts

```bash
#!/bin/bash

# Check if profile is set
if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS profile: $AWS_PROFILE"
else
    echo "Using default AWS profile"
fi

# Run validation
./validate-prerequisites.sh
```

### In Taskfile

```yaml
version: '3'

tasks:
  validate-dev:
    desc: Validate with dev profile
    cmds:
      - AWS_PROFILE=dev ./validate-prerequisites.sh

  validate-prod:
    desc: Validate with production profile
    cmds:
      - AWS_PROFILE=production ./validate-prerequisites.sh
```

### In CI/CD

**GitHub Actions:**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1

- name: Validate prerequisites
  run: ./validate-prerequisites.sh
```

**GitLab CI:**
```yaml
validate:
  script:
    - export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    - export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    - export AWS_REGION=us-east-1
    - ./validate-prerequisites.sh
```

## Security Considerations

1. ✅ **Never commit credentials** to version control
2. ✅ **Use IAM roles** when possible (EC2, ECS, Lambda)
3. ✅ **Rotate access keys** regularly
4. ✅ **Use different profiles** for different environments
5. ✅ **Enable MFA** for sensitive accounts
6. ✅ **Use temporary credentials** (STS) when possible
7. ✅ **Restrict IAM permissions** to minimum required

## See Also

- [AWS CLI Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [AWS Named Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
- [AWS Environment Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
- [VALIDATION_GUIDE.md](../VALIDATION_GUIDE.md) - Prerequisites validation documentation

