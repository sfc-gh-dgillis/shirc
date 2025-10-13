#!/bin/bash
# Snowflake Iceberg REST Catalog - Environment Setup Script

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Snowflake Iceberg REST Catalog - Environment Setup       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Function to read input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

# Get current values from environment
CURRENT_ACCOUNT="${SNOWFLAKE_ACCOUNT:-}"
CURRENT_USER="${SNOWFLAKE_USER:-}"
CURRENT_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
CURRENT_ROLE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"

# Prompt for Snowflake credentials
echo "Please enter your Snowflake credentials:"
echo ""

read_with_default "Snowflake Account Identifier" "$CURRENT_ACCOUNT" "SF_ACCOUNT"
read_with_default "Snowflake User" "$CURRENT_USER" "SF_USER"
read -s -p "Snowflake Password: " SF_PASSWORD
echo ""
read_with_default "Snowflake Warehouse" "$CURRENT_WAREHOUSE" "SF_WAREHOUSE"
read_with_default "Snowflake Role" "$CURRENT_ROLE" "SF_ROLE"

echo ""
echo "────────────────────────────────────────────────────────────"
echo "Configuration Summary:"
echo "────────────────────────────────────────────────────────────"
echo "Account:   $SF_ACCOUNT"
echo "User:      $SF_USER"
echo "Password:  ********"
echo "Warehouse: $SF_WAREHOUSE"
echo "Role:      $SF_ROLE"
echo "────────────────────────────────────────────────────────────"
echo ""

# Ask for confirmation
read -p "Export these values to your current shell? (y/n): " confirm

if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    # Export variables
    export SNOWFLAKE_ACCOUNT="$SF_ACCOUNT"
    export SNOWFLAKE_USER="$SF_USER"
    export SNOWFLAKE_PASSWORD="$SF_PASSWORD"
    export SNOWFLAKE_WAREHOUSE="$SF_WAREHOUSE"
    export SNOWFLAKE_ROLE="$SF_ROLE"
    
    echo ""
    echo "✅ Environment variables have been set for this session!"
    echo ""
    echo "To make these permanent, add to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "export SNOWFLAKE_ACCOUNT='$SF_ACCOUNT'"
    echo "export SNOWFLAKE_USER='$SF_USER'"
    echo "export SNOWFLAKE_PASSWORD='********'"
    echo "export SNOWFLAKE_WAREHOUSE='$SF_WAREHOUSE'"
    echo "export SNOWFLAKE_ROLE='$SF_ROLE'"
    echo ""
    echo "You can now run:"
    echo "  python blogcode_snowflake_iceberg.py --table your_table_name"
    echo ""
else
    echo ""
    echo "❌ Configuration cancelled. Environment variables not set."
    echo ""
fi

# Offer to create a .env file
echo ""
read -p "Would you like to save these to a .env file? (y/n): " save_env

if [[ $save_env == [yY] || $save_env == [yY][eE][sS] ]]; then
    ENV_FILE=".env.snowflake"
    cat > "$ENV_FILE" << EOF
# Snowflake Iceberg REST Catalog Configuration
# Generated on $(date)

export SNOWFLAKE_ACCOUNT='$SF_ACCOUNT'
export SNOWFLAKE_USER='$SF_USER'
export SNOWFLAKE_PASSWORD='$SF_PASSWORD'
export SNOWFLAKE_WAREHOUSE='$SF_WAREHOUSE'
export SNOWFLAKE_ROLE='$SF_ROLE'
EOF

    chmod 600 "$ENV_FILE"  # Make file readable only by owner
    
    echo ""
    echo "✅ Configuration saved to: $ENV_FILE"
    echo ""
    echo "To use this configuration in a new shell:"
    echo "  source $ENV_FILE"
    echo ""
    echo "⚠️  SECURITY WARNING:"
    echo "  - This file contains your password in plain text"
    echo "  - Add '$ENV_FILE' to .gitignore to prevent committing it"
    echo "  - Consider using a password manager or vault instead"
    echo ""
fi

echo "Setup complete!"

