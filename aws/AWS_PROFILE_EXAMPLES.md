# AWS_PROFILE Configuration Examples

## Overview

The `AWS_PROFILE` variable can be configured in three ways, with clear precedence rules.

## Configuration Methods

### Method 1: In `.env/iceberg.env` (Recommended)

**Best for:** Teams, persistent configuration, avoiding repeated exports

Edit `.env/iceberg.env`:
```shell
# Uncomment and set to your profile
AWS_PROFILE=production
AWS_REGION=us-west-2
```

**Usage:**
```shell
# Just run - profile is automatically loaded
./validate-prerequisites.sh
```

**Output:**
```
ℹ️  Loaded AWS_PROFILE from .env/iceberg.env: production

----------------------------------------------------------
✅ AWS credentials are configured (using profile: production).
   Account: 987654321098
   Identity: prod-user
```

### Method 2: Environment Variable

**Best for:** Temporary overrides, different profiles per session

```shell
# Export for the session
export AWS_PROFILE=staging

# Run validation
./validate-prerequisites.sh
```

**Output:**
```
----------------------------------------------------------
✅ AWS credentials are configured (using profile: staging).
   Account: 123456789012
   Identity: staging-user
```

**Note:** Environment variable takes precedence over `.env/iceberg.env`

### Method 3: One-Time Override

**Best for:** Quick testing, ad-hoc profile switches

```shell
# Use profile for just this command
AWS_PROFILE=dev ./validate-prerequisites.sh
```

## Priority Order

1. **Highest Priority:** `AWS_PROFILE` environment variable (if already exported)
2. **Medium Priority:** `AWS_PROFILE` from `.env/iceberg.env` (if set)
3. **Lowest Priority:** Default AWS credential chain

### Examples

**Scenario A: File setting only**
```shell
# .env/iceberg.env contains: AWS_PROFILE=production
./validate-prerequisites.sh
# Uses: production (from file)
```

**Scenario B: Environment variable overrides file**
```shell
# .env/iceberg.env contains: AWS_PROFILE=production
export AWS_PROFILE=staging
./validate-prerequisites.sh
# Uses: staging (from environment)
```

**Scenario C: One-time override**
```shell
# .env/iceberg.env contains: AWS_PROFILE=production
# Environment has: AWS_PROFILE=staging
AWS_PROFILE=dev ./validate-prerequisites.sh
# Uses: dev (from command line)
```

**Scenario D: No profile set**
```shell
# .env/iceberg.env contains: #AWS_PROFILE= (commented)
# No environment variable
./validate-prerequisites.sh
# Uses: default profile or credential chain
```

## Complete Examples

### Example 1: Team Configuration

**Setup (one time):**
```shell
# .env/iceberg.env
AWS_PROFILE=company-prod
AWS_REGION=us-east-1
```

**Daily usage (all team members):**
```shell
./validate-prerequisites.sh
```

**Override for testing:**
```shell
AWS_PROFILE=company-dev ./validate-prerequisites.sh
```

### Example 2: Multi-Environment Developer

**Setup (one time):**
```shell
# .env/iceberg.env
AWS_PROFILE=dev
AWS_REGION=us-east-1
```

**Shell aliases (~/.bashrc or ~/.zshrc):**
```shell
alias validate-dev='./validate-prerequisites.sh'
alias validate-staging='AWS_PROFILE=staging ./validate-prerequisites.sh'
alias validate-prod='AWS_PROFILE=production ./validate-prerequisites.sh'
```

**Usage:**
```shell
validate-dev      # Uses dev from file
validate-staging  # Overrides with staging
validate-prod     # Overrides with production
```

### Example 3: CI/CD Pipeline

**In `.env/iceberg.env` (committed to repo):**
```shell
# Default profile for local development
#AWS_PROFILE=dev
AWS_REGION=us-east-1
```

**In CI/CD (environment variables):**
```yaml
# GitHub Actions
env:
  AWS_PROFILE: ci-deployment
  AWS_REGION: us-east-1

steps:
  - name: Validate prerequisites
    run: ./validate-prerequisites.sh
```

### Example 4: No Profile Needed

**For users with simple setup:**
```shell
# .env/iceberg.env
#AWS_PROFILE=
AWS_REGION=us-east-1
```

**Result:**
- Uses `~/.aws/credentials` default profile
- Or AWS environment variables
- Or EC2/ECS IAM role

## Checking Current Configuration

### See what profile will be used

```shell
# Check environment
echo $AWS_PROFILE

# Check file
grep "^AWS_PROFILE=" .env/iceberg.env

# Run validation to see actual
./validate-prerequisites.sh
```

### List available profiles

```shell
aws configure list-profiles
```

**Output:**
```
default
dev
staging
production
```

### Test a specific profile

```shell
aws sts get-caller-identity --profile production
```

## Troubleshooting

### Profile from file not being used

**Cause:** Environment variable is already set

**Check:**
```shell
echo $AWS_PROFILE
```

**Fix:**
```shell
unset AWS_PROFILE
./validate-prerequisites.sh
```

### Profile doesn't exist

**Error:**
```
The config profile (myprofile) could not be found
```

**Fix:**
```shell
# Create the profile
aws configure --profile myprofile

# Or list existing profiles
aws configure list-profiles
```

### Want to ignore file setting

**Temporarily:**
```shell
AWS_PROFILE= ./validate-prerequisites.sh  # Empty value
```

**Permanently:**
```shell
# Comment out in .env/iceberg.env
#AWS_PROFILE=production
```

### File exists but profile not loading

**Check file syntax:**
```shell
# Must be exactly this format (no spaces around =)
AWS_PROFILE=myprofile

# NOT these:
AWS_PROFILE = myprofile  # ❌ spaces
AWS_PROFILE=  # ❌ empty value
# AWS_PROFILE=myprofile  # ❌ commented out
```

## Best Practices

### 1. Use file for persistent configuration
```shell
# .env/iceberg.env - team standard
AWS_PROFILE=company-prod
```

### 2. Document your profiles
```shell
# .env/iceberg.env
# Available profiles:
#   - company-dev: Development account
#   - company-staging: Staging account
#   - company-prod: Production account (default)
AWS_PROFILE=company-prod
```

### 3. Use environment variables for overrides
```shell
# Switch profiles without editing files
export AWS_PROFILE=staging
```

### 4. Keep sensitive profiles secure
```shell
# Don't commit actual profile names if they're sensitive
# Use descriptive but non-revealing names
AWS_PROFILE=client-project-prod  # Generic
```

### 5. Test before committing
```shell
# Always verify the profile works
./validate-prerequisites.sh
```

## See Also

- [AWS_PROFILE_GUIDE.md](AWS_PROFILE_GUIDE.md) - Comprehensive AWS profile documentation
- [VALIDATION_GUIDE.md](../VALIDATION_GUIDE.md) - Prerequisites validation guide
- [.env/README.md](../.env/README.md) - Environment configuration documentation

