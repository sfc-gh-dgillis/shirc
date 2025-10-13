# AWS Scripts

This directory contains AWS CLI scripts for managing AWS resources.

## Files

### `create_s3_bucket.sh`

Creates an S3 bucket named `dgillis-dev` with optional configuration for versioning, encryption, and public access blocking.

### `s3_bucket_policy.json`

IAM policy document that grants full CRUD access to the `dgillis-dev` S3 bucket. See [POLICY_README.md](POLICY_README.md) for detailed documentation on usage and customization.

### `POLICY_README.md`

Comprehensive documentation for the S3 bucket policy, including usage examples, security considerations, and common patterns.

**Prerequisites:**

- AWS CLI installed (`aws --version`)
- AWS credentials configured (`aws configure`)

**Usage:**

```bash
# Make sure the script is executable
chmod +x create_s3_bucket.sh

# Run the script
./create_s3_bucket.sh
```

**Features:**

- ✅ Checks if bucket already exists
- ✅ Creates `snowflake-iceberg/` folder within the bucket
- ✅ Checks if folder already exists before creating
- ✅ Handles different AWS regions correctly
- ✅ Optional versioning
- ✅ Optional default encryption (AES256)
- ✅ Optional public access blocking
- ✅ Shows AWS account information
- ✅ Provides helpful usage examples

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_DEFAULT_REGION` | `us-east-1` | AWS region for bucket creation |

**Example:**

```bash
# Create bucket in us-east-1 (default)
./create_s3_bucket.sh

# Create bucket in a different region
AWS_DEFAULT_REGION=us-west-2 ./create_s3_bucket.sh
```

**Output:**

If the bucket already exists:

```
ℹ️  Bucket already exists: dgillis-dev
```

If the folder already exists:

```
ℹ️  Folder already exists: snowflake-iceberg/
```

If the bucket and folder are created successfully:

```
✅ Bucket created successfully: dgillis-dev
✅ Folder created: snowflake-iceberg/
```

## AWS Configuration

### Setup AWS Credentials

If you haven't configured AWS CLI yet:

```bash
aws configure
```

You'll be prompted for:

- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., `us-east-1`)
- Default output format (e.g., `json`)

### Verify Configuration

```bash
# Check AWS CLI version
aws --version

# Verify credentials
aws sts get-caller-identity

# List existing S3 buckets
aws s3 ls
```

## Common S3 Commands

```bash
# List buckets
aws s3 ls

# List contents of a bucket
aws s3 ls s3://dgillis-dev/

# List contents of the snowflake-iceberg folder
aws s3 ls s3://dgillis-dev/snowflake-iceberg/

# Upload a file to the root of the bucket
aws s3 cp myfile.txt s3://dgillis-dev/

# Upload a file to the snowflake-iceberg folder
aws s3 cp myfile.txt s3://dgillis-dev/snowflake-iceberg/

# Download a file
aws s3 cp s3://dgillis-dev/myfile.txt ./

# Sync a local directory to the snowflake-iceberg folder
aws s3 sync ./local-dir s3://dgillis-dev/snowflake-iceberg/

# Delete a file
aws s3 rm s3://dgillis-dev/myfile.txt

# Delete all files in the snowflake-iceberg folder
aws s3 rm s3://dgillis-dev/snowflake-iceberg/ --recursive

# Delete bucket (must be empty)
aws s3 rb s3://dgillis-dev
```

## Troubleshooting

### Error: "AWS CLI is not installed"

Install AWS CLI from: [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)

**macOS:**

```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Error: "AWS credentials are not configured"

Run `aws configure` and provide your credentials.

### Error: "Bucket already exists and is owned by you"

This is informational - the script will detect this and print "Bucket already exists".

### Error: "InvalidLocationConstraint"

Make sure your AWS region is valid and properly set.

### Error: "Access Denied"

Check that your IAM user/role has the necessary S3 permissions:

- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutEncryptionConfiguration`
- `s3:PutBucketPublicAccessBlock`

## Security Best Practices

1. **Enable Versioning**: Protects against accidental deletions
2. **Enable Encryption**: Encrypts data at rest
3. **Block Public Access**: Prevents accidental public exposure
4. **Use IAM Roles**: For EC2/Lambda instead of access keys
5. **Enable MFA Delete**: For additional protection on versioned buckets
6. **Enable Logging**: Track access to your bucket
7. **Use Bucket Policies**: Define fine-grained access controls

## Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)

