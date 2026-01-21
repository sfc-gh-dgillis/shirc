# SHIRC - Snowflake Horizon Iceberg REST Catalog

> Python script for working with Apache Iceberg tables via Snowflake's Horizon REST catalog

## 📚 Overview

This repository provides a Python script demonstrating how to interact with Apache Iceberg tables through Snowflake's Horizon REST catalog (Polaris). The script showcases:

- Creating and managing Iceberg tables in Snowflake
- Inserting and updating data
- Querying with filters
- Time travel operations using snapshots
- Schema management

## 🚀 Quick Start

```bash
# 1. Set up environment configuration
cp .env/iceberg.env.template .env/iceberg.env
# Edit .env/iceberg.env and set your AWS_REGION
# Optionally set AWS_PROFILE if using named profiles

# 2. Validate prerequisites
./validate-prerequisites.sh

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up Snowflake environment (interactive)
./setup_snowflake_env.sh

# 5. Run the script
python blogcode_snowflake_iceberg.py --table customer_data
```

## 📁 Repository Structure

```text
shirc/
├── blogcode_snowflake_iceberg.py      # Main Snowflake Iceberg catalog script
├── requirements.txt                   # Python dependencies
├── validate-prerequisites.sh          # Prerequisites validation script
├── check-validation.sh                # Check validation status helper
├── setup_snowflake_env.sh             # Interactive environment setup
├── SNOWFLAKE_ICEBERG_GUIDE.md         # Detailed documentation
├── QUICK_REFERENCE.md                 # Quick reference cheat sheet
├── VALIDATION_GUIDE.md                # Validation script documentation
├── AWS_PROFILE_GUIDE.md               # AWS profile configuration guide
├── AWS_PROFILE_EXAMPLES.md            # AWS profile usage examples
├── setup.sql                          # SQL setup scripts
├── .env/                              # Environment configuration
│   ├── iceberg.env.template           # Configuration template
│   ├── iceberg.env                    # Your config (git-ignored)
│   └── README.md                      # Environment config docs
├── aws/                               # AWS CLI scripts
│   ├── create_s3_bucket.sh            # S3 bucket creation script
│   ├── s3_bucket_policy.json          # IAM policy for bucket access
│   ├── POLICY_README.md               # Policy documentation
│   └── README.md                      # AWS scripts documentation
├── tasks/                             # Task definitions and scripts
│   ├── aws-tasks.yml                  # AWS task definitions
│   ├── cmd/                           # Command scripts directory
│   │   └── bucket_s3_create.sh        # S3 bucket creation
│   ├── .prerequisites_validated       # Validation flag (git-ignored)
│   └── README.md                      # Tasks documentation
└── README.md                          # This file

Note: The tasks/ directory is tracked. Only .prerequisites_validated is git-ignored
```

## 🎯 What This Script Does

The script performs the following operations to demonstrate Iceberg features:

1. **Connect** to Snowflake's Horizon Iceberg REST catalog
2. **List** available databases and tables
3. **Create** a customer table with schema
4. **Insert** sample customer data
5. **Query** data with filters
6. **Update** customer preference flags
7. **Time Travel** - query historical snapshots
8. **Display** formatted output with highlighting

### Sample Output

```shell
═══════════════════════════════════════════════
❄️  Initializing Snowflake Iceberg Table Operations
═══════════════════════════════════════════════

📊 Initial Data - Check preferred_cust_flag value
══════════════════════════════════════════════════════
Focus on c_preferred_cust_flag column for changes
══════════════════════════════════════════════════════
| c_first_name | c_preferred_cust_flag | ... |
|--------------|----------------------|-----|
| Mickey       | ➡️ NULL              | ... |

🔄 Updating customer flag...

📊 Updated Data - Notice the changed preferred_cust_flag
══════════════════════════════════════════════════════
| c_first_name | c_preferred_cust_flag | ... |
|--------------|----------------------|-----|
| Mickey       | ➡️ N                 | ... |

⏰ Snapshot History:
[Shows all table snapshots with timestamps]
```

## 🔧 Configuration

### Environment Variables (Recommended)

Set the following environment variables for authentication:

```bash
export SNOWFLAKE_ACCOUNT='myorg-myaccount'
export SNOWFLAKE_USER='myuser'
export SNOWFLAKE_PASSWORD='mypassword'
export SNOWFLAKE_WAREHOUSE='COMPUTE_WH'
export SNOWFLAKE_ROLE='ACCOUNTADMIN'  # Optional
```

**Finding Your Account Identifier:**

- Format: `<orgname>-<account_name>` (e.g., `myorg-myaccount`)
- Or legacy format: `<account_locator>.<region>` (e.g., `xy12345.us-east-1`)
- Find it in your Snowflake URL: `https://<account_identifier>.snowflakecomputing.com`

### Interactive Setup

Use the setup script for guided configuration:

```bash
./setup_snowflake_env.sh
```

This will:

- Prompt for your Snowflake credentials
- Set environment variables for your session
- Optionally save to a `.env.snowflake` file

## 📖 Documentation

- **[SNOWFLAKE_ICEBERG_GUIDE.md](SNOWFLAKE_ICEBERG_GUIDE.md)** - Comprehensive guide with detailed examples
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference cheat sheet
- **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Prerequisites validation documentation
- **[AWS_PROFILE_GUIDE.md](aws/AWS_PROFILE_GUIDE.md)** - AWS profile configuration guide
- **[AWS_PROFILE_EXAMPLES.md](aws/AWS_PROFILE_EXAMPLES.md)** - AWS profile usage examples

## 🔑 Key Features

### Apache Iceberg Benefits

- ✅ **ACID Transactions** - Reliable concurrent reads and writes
- ✅ **Time Travel** - Query data as it existed at any point in time
- ✅ **Schema Evolution** - Add/remove columns without rewriting data
- ✅ **Hidden Partitioning** - Automatic partition management
- ✅ **Snapshot Isolation** - Consistent reads without locks

### Script Features

- ✅ **Production-Ready** - Error handling, logging, and validation
- ✅ **Well-Documented** - Inline comments and docstrings
- ✅ **Formatted Output** - Tabulated data with highlighting
- ✅ **Flexible Configuration** - Environment variables and CLI args
- ✅ **Interactive Setup** - Guided environment configuration

## 🛠️ Dependencies

Install all dependencies with:

```bash
pip install -r requirements.txt
```

Or install individually:

```bash
pip install pyiceberg pyarrow pandas tabulate requests snowflake-connector-python
```

### Required Packages

- `pyiceberg>=0.5.0` - Python client for Apache Iceberg
- `pyarrow>=14.0.0` - Columnar data processing
- `pandas>=2.0.0` - Data manipulation
- `tabulate>=0.9.0` - Formatted table output
- `requests>=2.31.0` - HTTP library for REST API
- `snowflake-connector-python>=3.0.0` - Snowflake connectivity

## 📝 Usage Examples

### Basic Usage

```bash
python blogcode_snowflake_iceberg.py --table customer_data
```

### With Custom Database

```bash
python blogcode_snowflake_iceberg.py \
  --database my_database \
  --table my_table
```

### With Custom Configuration

```bash
python blogcode_snowflake_iceberg.py \
  --catalog my_catalog \
  --database my_db \
  --table my_table \
  --warehouse LARGE_WH
```

### With Command Line Credentials

```bash
python blogcode_snowflake_iceberg.py \
  --account myorg-myaccount \
  --user myuser \
  --warehouse COMPUTE_WH \
  --table customer_data
```

## 🔍 Code Example

### Catalog Initialization

The script uses PyIceberg's `load_catalog()` to connect to Snowflake:

```python
from pyiceberg.catalog import load_catalog

catalog = load_catalog(
    "snowflake_iceberg",
    type="rest",
    uri=f"https://{account}.snowflakecomputing.com/polaris/api/catalog",
    warehouse=warehouse,
    token=oauth_token
)
```

### Iceberg Operations

```python
# List databases
databases = catalog.list_namespaces()

# List tables
tables = catalog.list_tables("database_name")

# Load table
table = catalog.load_table("database.table")

# Insert data
table.append(data)

# Query with filters
from pyiceberg.expressions import EqualTo
data = table.scan(
    row_filter=EqualTo("field", "value"),
    limit=10
).to_pandas()

# Time travel
snapshots = table.snapshots()
historical_data = table.scan(
    snapshot_id=snapshots[1].snapshot_id
).to_pandas()
```

## 🧪 Testing

To test the script:

1. **Set up credentials** using environment variables or the setup script
2. **Run the script** with a test table name
3. **Verify output** shows all operations completing successfully
4. **Check Snowflake** to confirm table creation

The script is **idempotent** - safe to run multiple times on the same table.

## 🔒 Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for sensitive data
3. **Add `.env*` files to `.gitignore`** (already configured)
4. **Rotate passwords regularly**
5. **Use least-privilege access** (minimal required permissions)
6. **Enable MFA** on Snowflake accounts
7. **Use dedicated service accounts** for production

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Authentication failed** | Verify account identifier format (should be `orgname-accountname`) |
| **Warehouse not found** | Check warehouse name and ensure it's running |
| **Permission denied** | Grant `CREATE TABLE` and `INSERT` privileges to your user |
| **Module not found** | Run `pip install -r requirements.txt` |
| **OAuth token error** | Check username/password are correct |
| **Connection timeout** | Verify network connectivity and Snowflake availability |

### Debug Mode

For detailed error information, check the traceback in the terminal output. The script includes comprehensive error handling and will display helpful error messages.

## 📚 Resources

### Snowflake

- [Snowflake Iceberg Tables Documentation](https://docs.snowflake.com/en/user-guide/tables-iceberg)
- [Snowflake REST API Documentation](https://docs.snowflake.com/en/developer-guide/rest-api/index)

### Apache Iceberg

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [PyIceberg Documentation](https://py.iceberg.apache.org/)
- [Iceberg Table Specification](https://iceberg.apache.org/spec/)

### Related Articles

- [Medium Article on Snowflake Iceberg](https://medium.com/snowflake/18adaf6b0bbe)

## 🎓 Learn More

This script demonstrates:

- **REST Catalog Pattern** - Using Snowflake's Polaris REST API
- **OAuth Authentication** - Token-based authentication flow
- **PyIceberg Integration** - Working with Iceberg tables in Python
- **Time Travel Queries** - Leveraging Iceberg's snapshot capabilities
- **Schema Management** - Defining and using PyArrow schemas

## 🤝 Contributing

Contributions welcome! Areas for enhancement:

- Schema evolution examples
- Partition management utilities
- Performance optimization techniques
- Bulk data operations
- Integration with Snowpark
- CI/CD pipeline examples

## 📄 License

This project is provided as-is for educational and demonstration purposes.

## 🙏 Acknowledgments

- Apache Iceberg community for the excellent table format
- PyIceberg maintainers for the Python implementation
- Snowflake for Horizon catalog support
- Medium article that inspired this implementation

---

**Note:** This script demonstrates working with Apache Iceberg tables through Snowflake's Horizon REST catalog (Polaris). It showcases the power of open table formats for modern data architectures.

For detailed usage instructions, see [SNOWFLAKE_ICEBERG_GUIDE.md](SNOWFLAKE_ICEBERG_GUIDE.md).
