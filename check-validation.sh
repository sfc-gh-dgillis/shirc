#!/usr/bin/env bash
#
# Helper script to check if prerequisites have been validated
# Returns exit code 0 if validated, 1 if not
#

VALIDATION_FLAG="tasks/.prerequisites_validated"

if [ ! -f "$VALIDATION_FLAG" ]; then
    echo "❌ Prerequisites not validated."
    echo "   Please run: ./validate-prerequisites.sh"
    exit 1
fi

# Read validation info
source "$VALIDATION_FLAG"

echo "✅ Prerequisites validated"
echo "   Status: $VALIDATION_STATUS"
echo "   Last checked: $VALIDATION_TIMESTAMP"
echo ""
echo "Validated components:"
echo "   • AWS CLI: $AWS_CLI"
echo "   • AWS Credentials: $AWS_CREDENTIALS"
echo "   • Task CLI: $TASK_CLI"
echo "   • Snowflake CLI: $SNOWFLAKE_CLI"
echo "   • Environment Config: $ENV_CONFIG"
echo "   • AWS Region: $AWS_REGION_CONFIGURED"

exit 0

