#!/bin/bash

# Snowflake Iceberg REST Catalog Demo Setup Script
echo "🚀 Setting up Snowflake Iceberg REST Catalog Demo..."
echo

# Verify we're in the project directory (look for environment.yml)
if [ ! -f "environment.yml" ]; then
    echo "❌ Error: environment.yml not found in current directory"
    echo "   Make sure you're running this script from the project root directory:"
    echo "   cd horizon-v3-demo"
    echo "   ./setup.sh"
    exit 1
fi

# Check if conda is installed
if ! command -v conda &> /dev/null; then
    echo "❌ Conda is not installed. Please install Conda first:"
    echo "   Mac: https://docs.conda.io/en/latest/miniconda.html#macos-installers"
    echo "   Windows: https://docs.conda.io/en/latest/miniconda.html#windows-installers"
    echo "   Linux: https://docs.conda.io/en/latest/miniconda.html#linux-installers"
    exit 1
fi

echo "✅ Conda found"

# Create conda environment
echo "📦 Creating conda environment 'iceberg-lab'..."
if conda env list | grep -q "iceberg-lab"; then
    echo "⚠️  Environment 'iceberg-lab' already exists. Removing it first..."
    conda env remove -n iceberg-lab -y
fi

conda env create -f environment.yml

if [ $? -eq 0 ]; then
    echo "✅ Conda environment 'iceberg-lab' created successfully"
else
    echo "❌ Failed to create conda environment"
    exit 1
fi

echo
echo "🎉 Setup complete!"
echo
echo "📋 Next steps:"
echo "1. Start the environment:"
echo "   conda activate iceberg-lab"
echo "   jupyter notebook"
echo
echo "2. Open the notebook:"
echo "   • horizon_v3_variant_spark.ipynb"
echo
echo "3. Configure your Snowflake credentials:"
echo "   Update the configuration variables in the notebook:"
echo "   • horizon_catalog_uri"
echo "   • catalog_name (your database)"
echo "   • schema_name"
echo "   • token (your Personal Access Token)"
echo
echo "⚠️  Before running the notebook:"
echo "   • Complete Snowflake setup (see notebook Cell 1)"
echo "   • Ensure Iceberg is enabled on your Snowflake account"
echo "   • Configure an external volume for your database"
echo
echo "📖 See README.md for troubleshooting guide"
echo "Happy coding! 🎯"
