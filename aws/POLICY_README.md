# S3 Bucket Policy

## Overview

The `s3_bucket_policy.json` file contains an IAM policy that grants permissions to perform operations on the `dgillis-dev` S3 bucket and its objects.

## Policy Details

### Statement 1: Object Operations

**Sid:** `AllowObjectOperations`

Grants permissions to:

- `s3:PutObject` - Upload objects to the bucket
- `s3:GetObject` - Download/read objects from the bucket
- `s3:GetObjectVersion` - Access specific versions of objects (if versioning is enabled)
- `s3:DeleteObject` - Delete objects from the bucket
- `s3:DeleteObjectVersion` - Delete specific versions of objects

**Resource:** `arn:aws:s3:::dgillis-dev/*`  
Applies to all objects within the bucket (indicated by `/*`)

### Statement 2: Bucket Operations

**Sid:** `AllowBucketOperations`

Grants permissions to:

- `s3:ListBucket` - List objects in the bucket
- `s3:GetBucketLocation` - Get the bucket's AWS region

**Resource:** `arn:aws:s3:::dgillis-dev`  
Applies to the bucket itself (no trailing `/*`)

**Condition:**

- Allows listing objects with any prefix (`s3:prefix: ["*"]`)

## Usage

### Attach Policy to IAM User

```bash
# Create the policy
aws iam create-policy \
  --policy-name DgillisDev-S3Access \
  --policy-document file://s3_bucket_policy.json

# Attach to a user
aws iam attach-user-policy \
  --user-name YOUR_USERNAME \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DgillisDev-S3Access
```

### Attach Policy to IAM Role

```bash
# Attach to a role (e.g., for EC2 instances)
aws iam attach-role-policy \
  --role-name YOUR_ROLE_NAME \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DgillisDev-S3Access
```

### Apply as Bucket Policy

To apply this as a bucket policy (allowing access for specific principals):

```bash
# First, add a "Principal" field to each statement
# Then apply the policy
aws s3api put-bucket-policy \
  --bucket dgillis-dev \
  --policy file://s3_bucket_policy.json
```

**Note:** For bucket policies, you need to add a `"Principal"` field to specify who has access. Example:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT_ID:user/USERNAME"
  },
  "Action": ["s3:PutObject", "s3:GetObject"],
  "Resource": "arn:aws:s3:::dgillis-dev/*"
}
```

## Customize for Your Bucket

To use this policy for a different bucket, replace `dgillis-dev` with your bucket name:

```bash
# Using sed
sed 's/dgillis-dev/your-bucket-name/g' s3_bucket_policy.json > your_policy.json

# Or manually edit the file
```

## Security Considerations

### Principle of Least Privilege

- This policy grants full CRUD (Create, Read, Update, Delete) access to the bucket
- Consider restricting to only necessary actions for your use case
- Example: Remove `DeleteObject` if deletion should be restricted

### Restrict by Path/Prefix

To limit access to only the `snowflake-iceberg/` folder:

```json
{
  "Resource": "arn:aws:s3:::dgillis-dev/snowflake-iceberg/*"
}
```

### Add Conditions

Example conditions to add:

```json
"Condition": {
  "IpAddress": {
    "aws:SourceIp": "203.0.113.0/24"
  }
}
```

Or require encryption:

```json
"Condition": {
  "StringEquals": {
    "s3:x-amz-server-side-encryption": "AES256"
  }
}
```

## Common Policy Patterns

### Read-Only Access

```json
{
  "Action": [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:ListBucket"
  ]
}
```

### Write-Only Access

```json
{
  "Action": [
    "s3:PutObject"
  ]
}
```

### Folder-Specific Access

```json
{
  "Action": ["s3:*"],
  "Resource": [
    "arn:aws:s3:::dgillis-dev/snowflake-iceberg/*"
  ],
  "Condition": {
    "StringLike": {
      "s3:prefix": ["snowflake-iceberg/*"]
    }
  }
}
```

## Validation

Validate your policy JSON:

```bash
# Using Python
python3 -m json.tool s3_bucket_policy.json

# Using jq
jq . s3_bucket_policy.json

# Using AWS CLI
aws iam simulate-custom-policy \
  --policy-input-list file://s3_bucket_policy.json \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::dgillis-dev/test.txt
```

## Testing

After applying the policy, test access:

```bash
# Test listing
aws s3 ls s3://dgillis-dev/

# Test upload
echo "test" > test.txt
aws s3 cp test.txt s3://dgillis-dev/snowflake-iceberg/

# Test download
aws s3 cp s3://dgillis-dev/snowflake-iceberg/test.txt ./downloaded.txt

# Test delete
aws s3 rm s3://dgillis-dev/snowflake-iceberg/test.txt
```

## Troubleshooting

### Access Denied

- Verify the policy is attached to your user/role
- Check the bucket name matches exactly
- Ensure bucket exists and you have permissions
- Review CloudTrail logs for detailed error information

### Policy Too Permissive

- Add conditions to restrict by IP, time, or encryption
- Limit actions to only what's needed
- Restrict resources to specific paths

### Need More Permissions

Add additional actions as needed:

- `s3:PutObjectAcl` - Modify object permissions
- `s3:GetBucketVersioning` - Check versioning status
- `s3:PutLifecycleConfiguration` - Manage lifecycle policies

## Resources

- [AWS S3 Actions](https://docs.aws.amazon.com/AmazonS3/latest/API/API_Operations.html)
- [S3 Policy Examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-policies-s3.html)
- [IAM Policy Simulator](https://policysim.aws.amazon.com/)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
