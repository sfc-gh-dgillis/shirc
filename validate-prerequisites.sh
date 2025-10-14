#!/usr/bin/env bash

# Initialize failure counter
FAILURE_COUNT=0
FAILED_CHECKS=()

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Prerequisites Validation Script                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if AWS CLI is installed
echo "----------------------------------------------------------"
if command -v aws >/dev/null 2>&1; then
    echo "✅ AWS CLI is installed."
else
    echo "❌ Error: AWS CLI is not installed."
    echo "   Please install it from: https://aws.amazon.com/cli/"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=("AWS CLI")
fi

# Load AWS_PROFILE from .env/iceberg.env if it exists and AWS_PROFILE is not already set
ENV_FILE=".env/iceberg.env"
if [ -z "$AWS_PROFILE" ] && [ -f "$ENV_FILE" ]; then
    # Check if AWS_PROFILE is defined in the file
    if grep -q "^AWS_PROFILE=" "$ENV_FILE" 2>/dev/null; then
        # Extract and export AWS_PROFILE value
        ENV_AWS_PROFILE=$(grep "^AWS_PROFILE=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' "' | tr -d "'")
        if [ -n "$ENV_AWS_PROFILE" ]; then
            export AWS_PROFILE="$ENV_AWS_PROFILE"
            echo ""
            echo "ℹ️  Loaded AWS_PROFILE from .env/iceberg.env: $AWS_PROFILE"
        fi
    fi
fi

# Check if AWS credentials are configured
echo "----------------------------------------------------------"
AWS_PROFILE_MSG=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_MSG=" (using profile: $AWS_PROFILE)"
fi

if aws sts get-caller-identity --region "${AWS_REGION:-us-east-1}" >/dev/null 2>&1; then
    CALLER_IDENTITY=$(aws sts get-caller-identity --region "${AWS_REGION:-us-east-1}" --output json 2>/dev/null)
    ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    USER_ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
    
    echo "✅ AWS credentials are configured${AWS_PROFILE_MSG}."
    if [ -n "$ACCOUNT_ID" ]; then
        echo "   Account: $ACCOUNT_ID"
        echo "   Identity: $(basename "$USER_ARN")"
    fi
else
    echo "❌ Error: AWS credentials are not configured${AWS_PROFILE_MSG}."
    echo "   Please run: aws configure"
    if [ -n "$AWS_PROFILE" ]; then
        echo "   Or configure profile: aws configure --profile $AWS_PROFILE"
    fi
    echo "   Tip: You can set AWS_PROFILE environment variable to use a specific profile"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=("AWS credentials")
fi

# Validate task CLI installation
echo "----------------------------------------------------------"
if command -v task >/dev/null 2>&1; then
    echo "✅ task CLI is installed."
else
    echo "❌ Error: task CLI is not installed."
    echo "   To install task CLI, run: brew install go-task/tap/go-task"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=("task CLI")
fi

# Validate Snowflake CLI installation
echo "----------------------------------------------------------"
if command -v snow >/dev/null 2>&1; then
    echo "✅ Snowflake CLI (snow) is installed."
else
    echo "❌ Error: Snowflake CLI (snow) is not installed."
    echo "   To install Snowflake CLI, follow the instructions at:"
    echo "   https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=("Snowflake CLI")
fi

# Validate .env/iceberg.env file and AWS_REGION
echo "----------------------------------------------------------"
ENV_DIR=".env"
ENV_FILE="$ENV_DIR/iceberg.env"

# Valid AWS regions (as of 2025)
VALID_AWS_REGIONS=(
    "us-east-1" "us-east-2" "us-west-1" "us-west-2"
    "af-south-1" "ap-east-1" "ap-south-1" "ap-south-2"
    "ap-northeast-1" "ap-northeast-2" "ap-northeast-3"
    "ap-southeast-1" "ap-southeast-2" "ap-southeast-3" "ap-southeast-4"
    "ca-central-1" "eu-central-1" "eu-central-2"
    "eu-west-1" "eu-west-2" "eu-west-3"
    "eu-south-1" "eu-south-2" "eu-north-1"
    "me-south-1" "me-central-1" "sa-east-1"
)

if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Error: Directory '.env' does not exist."
    echo "   Please create it: mkdir .env"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=(".env directory")
elif [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: File '.env/iceberg.env' does not exist."
    echo "   Please create the file with AWS_REGION configuration."
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_CHECKS+=(".env/iceberg.env file")
else
    # Check if AWS_REGION is defined in the file
    if grep -q "^AWS_REGION=" "$ENV_FILE" 2>/dev/null; then
        # Extract the AWS_REGION value
        AWS_REGION_VALUE=$(grep "^AWS_REGION=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' "' | tr -d "'")
        
        # Check if it's a valid region
        REGION_VALID=false
        for region in "${VALID_AWS_REGIONS[@]}"; do
            if [ "$AWS_REGION_VALUE" = "$region" ]; then
                REGION_VALID=true
                break
            fi
        done
        
        if [ "$REGION_VALID" = true ]; then
            echo "✅ .env/iceberg.env exists with valid AWS_REGION: $AWS_REGION_VALUE"
        else
            echo "❌ Error: AWS_REGION in .env/iceberg.env is not valid: '$AWS_REGION_VALUE'"
            echo "   Valid regions include: us-east-1, us-west-2, eu-west-1, etc."
            echo "   See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            FAILED_CHECKS+=("AWS_REGION configuration")
        fi
    else
        echo "❌ Error: AWS_REGION variable not found in .env/iceberg.env"
        echo "   Please add: AWS_REGION=us-east-1 (or your preferred region)"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        FAILED_CHECKS+=("AWS_REGION variable")
    fi
fi

# Final summary
echo "----------------------------------------------------------"
echo ""
if [ $FAILURE_COUNT -eq 0 ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ ALL CHECKS PASSED                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "All prerequisites have been validated successfully!"
    
    # Ensure tasks directory exists (may already exist with tracked files)
    TASKS_DIR="tasks"
    mkdir -p "$TASKS_DIR"
    
    # Create validation success flag file
    VALIDATION_FLAG="$TASKS_DIR/.prerequisites_validated"
    TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    cat > "$VALIDATION_FLAG" << EOF
# Prerequisites Validation Success
# This file is automatically generated by validate-prerequisites.sh
# Last validated: $TIMESTAMP

VALIDATION_STATUS=passed
VALIDATION_TIMESTAMP=$TIMESTAMP
AWS_CLI=installed
AWS_CREDENTIALS=configured
TASK_CLI=installed
SNOWFLAKE_CLI=installed
ENV_CONFIG=validated
AWS_REGION_CONFIGURED=yes
EOF
    
    echo ""
    echo "✅ Validation status saved to: $VALIDATION_FLAG"
    exit 0
else
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  ⚠️  VALIDATION FAILED                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "❌ $FAILURE_COUNT check(s) failed!"
    echo ""
    echo "Failed checks:"
    for check in "${FAILED_CHECKS[@]}"; do
        echo "  • $check"
    done
    echo ""
    echo "Please review the error messages above and install the missing"
    echo "prerequisites before proceeding."
    
    # Remove validation flag if it exists (prerequisites no longer valid)
    TASKS_DIR="tasks"
    VALIDATION_FLAG="$TASKS_DIR/.prerequisites_validated"
    if [ -f "$VALIDATION_FLAG" ]; then
        rm "$VALIDATION_FLAG"
        echo ""
        echo "⚠️  Previous validation flag removed due to failed checks."
    fi
    
    echo ""
    exit 1
fi