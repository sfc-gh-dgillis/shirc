# Snowflake Horizon Iceberg REST Catalog - Python Guide

This script demonstrates how to interact with Snowflake's Horizon Iceberg REST catalog using PyIceberg.

## Overview

The `blogcode_snowflake_iceberg.py` script provides a complete example of:
- Connecting to Snowflake's Iceberg REST catalog
- Creating databases and tables
- Inserting and updating data
- Querying with filters
- Time travel operations using snapshots
- Schema management

## Prerequisites

### 1. Snowflake Account Setup
- Active Snowflake account with Iceberg table support
- Appropriate permissions to create databases and tables
- A warehouse configured and running

### 2. Python Environment
```bash
# Install required packages
pip install -r requirements.txt
```

Or install individually:
```bash
pip install pyiceberg pyarrow pandas tabulate requests snowflake-connector-python
```

## Configuration

### Environment Variables (Recommended)
Set the following environment variables for authentication:

```bash
export SNOWFLAKE_ACCOUNT='your_account_identifier'
export SNOWFLAKE_USER='your_username'
export SNOWFLAKE_PASSWORD='your_password'
export SNOWFLAKE_WAREHOUSE='COMPUTE_WH'
export SNOWFLAKE_ROLE='ACCOUNTADMIN'  # Optional, defaults to ACCOUNTADMIN
```

**Finding Your Account Identifier:**
- Format: `<orgname>-<account_name>` (e.g., `myorg-myaccount`)
- Or legacy format: `<account_locator>.<region>` (e.g., `xy12345.us-east-1`)
- Find it in your Snowflake URL: `https://<account_identifier>.snowflakecomputing.com`

### Alternative: Command Line Arguments
```bash
python blogcode_snowflake_iceberg.py \
  --account your_account \
  --user your_user \
  --warehouse COMPUTE_WH \
  --table customer_data
```

## Usage

### Basic Usage
```bash
# Using environment variables
python blogcode_snowflake_iceberg.py --table customer_data
```

### With Custom Database and Catalog
```bash
python blogcode_snowflake_iceberg.py \
  --catalog my_catalog \
  --database my_database \
  --table my_table
```

### Full Example with All Options
```bash
python blogcode_snowflake_iceberg.py \
  --account myorg-myaccount \
  --user myuser \
  --warehouse COMPUTE_WH \
  --catalog iceberg_catalog \
  --database iceberg_db \
  --table customer_data
```

## Script Features

### 1. Database and Table Management
- Automatically lists existing databases and tables
- Creates database if it doesn't exist
- Creates table with predefined schema
- Handles table existence gracefully

### 2. Data Operations
- **Insert**: Adds sample customer data
- **Update**: Modifies customer preference flags
- **Query**: Filters data using expressions (e.g., `EqualTo`)
- **Scan**: Retrieves full table data

### 3. Time Travel
The script demonstrates Iceberg's time travel capabilities:
- Lists all table snapshots
- Queries data from specific snapshots
- Shows snapshot metadata (timestamp, schema ID, manifest location)

### 4. Schema Definition
The script uses a customer schema with the following fields:
```python
- c_salutation (string)
- c_preferred_cust_flag (string)
- c_first_sales_date_sk (int32)
- c_customer_sk (int32)
- c_first_name (string)
- c_email_address (string)
```

## Architecture

### Snowflake REST Catalog Endpoint
```
https://<account>.snowflakecomputing.com/polaris/api/catalog
```

### Authentication Flow
1. Script retrieves credentials from environment or arguments
2. Obtains OAuth token from Snowflake
3. Configures PyIceberg REST catalog with token
4. Performs all operations through REST API

### PyIceberg Configuration
The script configures the catalog programmatically:
```python
{
    "type": "rest",
    "uri": "https://<account>.snowflakecomputing.com/polaris/api/catalog",
    "warehouse": "<warehouse_name>",
    "token": "<oauth_token>"
}
```

## Expected Output

When you run the script, you'll see:
1. 🔐 Authentication status
2. 📚 List of available databases
3. 📋 Tables in the target database
4. 📊 Initial data with highlighted preference flag
5. 🔄 Update confirmation
6. 📊 Updated data showing changes
7. ⏰ Snapshot history
8. 📸 Time travel query results

## Troubleshooting

### Authentication Errors
```
Error retrieving OAuth token
```
**Solution:**
- Verify your credentials are correct
- Check that your account has OAuth configured
- Ensure your user has appropriate permissions

### Catalog Connection Errors
```
Failed to connect to REST catalog
```
**Solution:**
- Verify your account identifier format
- Ensure warehouse is running
- Check network connectivity to Snowflake

### Permission Errors
```
Insufficient privileges
```
**Solution:**
- Grant necessary privileges: `CREATE DATABASE`, `CREATE TABLE`, `INSERT`, `UPDATE`
- Use a role with appropriate permissions (e.g., `ACCOUNTADMIN` for testing)

### PyIceberg Version Issues
```
Module not found or incompatible
```
**Solution:**
```bash
pip install --upgrade pyiceberg>=0.5.0
```

## Advanced Usage

### Modifying the Schema
Edit the `create_customer_schema()` function to define your own schema:
```python
def create_customer_schema() -> pa.Schema:
    return pa.schema([
        pa.field('your_field', pa.string()),
        pa.field('another_field', pa.int64()),
        # Add more fields as needed
    ])
```

### Custom Queries
Use PyIceberg expressions for filtering:
```python
from pyiceberg.expressions import And, GreaterThan, LessThan

tabledata = table.scan(
    row_filter=And(
        GreaterThan("c_customer_sk", 1000),
        LessThan("c_customer_sk", 2000)
    ),
    limit=100
).to_pandas()
```

### Working with Snapshots
```python
# Get all snapshots
snapshots = table.snapshots()

# Query from a specific point in time
snapshot_id = snapshots[1].snapshot_id  # Second snapshot
historical_data = table.scan(snapshot_id=snapshot_id).to_pandas()
```

## Resources

- [Snowflake Iceberg Tables Documentation](https://docs.snowflake.com/en/user-guide/tables-iceberg)
- [PyIceberg Documentation](https://py.iceberg.apache.org/)
- [Apache Iceberg Specification](https://iceberg.apache.org/spec/)
- [Snowflake REST API](https://docs.snowflake.com/en/developer-guide/rest-api/index)

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for sensitive data
3. **Rotate passwords** regularly
4. **Use role-based access** with minimum required privileges
5. **Enable MFA** on Snowflake accounts
6. **Consider using OAuth** integrations for production

## License

This script is provided as-is for educational and demonstration purposes.

## Contributing

Feel free to extend this script with additional features:
- Batch operations
- Schema evolution
- Partition management
- Performance optimization
- Error recovery mechanisms

## Support

For issues related to:
- **Snowflake**: Contact Snowflake support or check their documentation
- **PyIceberg**: Visit the PyIceberg GitHub repository
- **This script**: Review the code comments and error messages

---

**Note**: This script demonstrates working with Apache Iceberg tables through Snowflake's Horizon Iceberg REST catalog (Polaris). It showcases the power of open table formats for modern data architectures.
