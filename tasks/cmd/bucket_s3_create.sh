#!/bin/bash
#
# Script to create an S3 bucket using AWS CLI
# Bucket name: dgillis-dev
#

set -e  # Exit on error

# Load configuration from .env file if it exists
ENV_FILE=".env/iceberg.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Configuration with defaults
BUCKET_NAME="${AWS_S3_BUCKET:-dgillis-dev}"
REGION="${AWS_REGION:-us-east-1}"
FOLDER_NAME="${AWS_S3_FOLDER:-snowflake-iceberg}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           AWS S3 Bucket Creation Script                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region:      $REGION"
echo ""


# Display AWS account info
echo "AWS Account Information:"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "  Account ID: $ACCOUNT_ID"
echo "  User/Role:  $USER_ARN"
echo ""

# Check if bucket already exists
echo "Checking if bucket exists..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "ℹ️  Bucket already exists: $BUCKET_NAME"
    echo ""
    echo "Bucket details:"
    aws s3api get-bucket-location --bucket "$BUCKET_NAME" 2>/dev/null || \
        echo "  Unable to get bucket location"
    
    # Still check and create folder if needed
    echo ""
    echo "Checking folder: $FOLDER_NAME/"
    if aws s3 ls "s3://$BUCKET_NAME/$FOLDER_NAME/" 2>/dev/null | grep -q "PRE $FOLDER_NAME/"; then
        echo "ℹ️  Folder already exists: $FOLDER_NAME/"
    else
        echo "Creating folder: $FOLDER_NAME/"
        if aws s3api put-object --bucket "$BUCKET_NAME" --key "$FOLDER_NAME/" 2>/dev/null; then
            echo "✅ Folder created: $FOLDER_NAME/"
        else
            echo "❌ Failed to create folder"
        fi
    fi
    
    exit 0
fi

# Create the bucket
echo "Creating bucket: $BUCKET_NAME"
echo ""

if [ "$REGION" = "us-east-1" ]; then
    # us-east-1 doesn't require LocationConstraint
    if aws s3api create-bucket --bucket "$BUCKET_NAME" 2>&1; then
        echo "✅ Bucket created successfully: $BUCKET_NAME"
    else
        echo "❌ Failed to create bucket"
        exit 1
    fi
else
    # Other regions require LocationConstraint
    if aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>&1; then
        echo "✅ Bucket created successfully: $BUCKET_NAME"
    else
        echo "❌ Failed to create bucket"
        exit 1
    fi
fi

# Enable versioning (optional but recommended for production)
echo ""
read -p "Would you like to enable versioning on this bucket? (y/n): " enable_versioning
if [[ $enable_versioning == [yY] || $enable_versioning == [yY][eE][sS] ]]; then
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    echo "✅ Versioning enabled"
fi

# Enable encryption (optional but recommended)
echo ""
read -p "Would you like to enable default encryption (AES256)? (y/n): " enable_encryption
if [[ $enable_encryption == [yY] || $enable_encryption == [yY][eE][sS] ]]; then
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'
    echo "✅ Encryption enabled"
fi

# Block public access (recommended for security)
echo ""
read -p "Would you like to block all public access? (recommended) (y/n): " block_public
if [[ $block_public == [yY] || $block_public == [yY][eE][sS] ]]; then
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo "✅ Public access blocked"
fi

# Create snowflake-iceberg folder/prefix
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Creating folder: $FOLDER_NAME/"

# Check if folder already exists
if aws s3 ls "s3://$BUCKET_NAME/$FOLDER_NAME/" 2>/dev/null | grep -q "PRE $FOLDER_NAME/"; then
    echo "ℹ️  Folder already exists: $FOLDER_NAME/"
else
    # Create folder by uploading an empty object with trailing slash
    # Note: In S3, folders are just prefixes, so we create a marker object
    if aws s3api put-object --bucket "$BUCKET_NAME" --key "$FOLDER_NAME/" 2>/dev/null; then
        echo "✅ Folder created: $FOLDER_NAME/"
    else
        echo "❌ Failed to create folder (bucket may need a moment to propagate)"
    fi
fi

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Bucket setup complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Bucket URL:         s3://$BUCKET_NAME"
echo "Folder URL:         s3://$BUCKET_NAME/$FOLDER_NAME/"
echo "Console URL:        https://s3.console.aws.amazon.com/s3/buckets/$BUCKET_NAME"
echo ""
echo "To upload files to the folder:"
echo "  aws s3 cp myfile.txt s3://$BUCKET_NAME/$FOLDER_NAME/"
echo ""
echo "To list folder contents:"
echo "  aws s3 ls s3://$BUCKET_NAME/$FOLDER_NAME/"
echo ""
echo "To list all bucket contents:"
echo "  aws s3 ls s3://$BUCKET_NAME/"
echo ""
