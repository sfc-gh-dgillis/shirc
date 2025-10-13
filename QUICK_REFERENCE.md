# Quick Reference Card - Snowflake Iceberg REST Catalog

## 🚀 Quick Start Commands

```bash
# Setup
export SNOWFLAKE_ACCOUNT='myorg-myaccount'
export SNOWFLAKE_USER='myuser'
export SNOWFLAKE_PASSWORD='mypassword'
export SNOWFLAKE_WAREHOUSE='COMPUTE_WH'

# Run
python blogcode_snowflake_iceberg.py --table customer_data
```

## 📋 Command Line Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--table` | ✅ Yes | - | Table name |
| `--database` | ❌ No | `iceberg_db` | Database/namespace name |
| `--catalog` | ❌ No | `snowflake_iceberg` | Catalog name |
| `--warehouse` | ❌ No | `COMPUTE_WH` | Snowflake warehouse |
| `--account` | ❌ No | from env | Snowflake account identifier |
| `--user` | ❌ No | from env | Snowflake username |

## 🔑 Environment Variables

```bash
SNOWFLAKE_ACCOUNT       # Required: Account identifier (e.g., myorg-myaccount)
SNOWFLAKE_USER          # Required: Username
SNOWFLAKE_PASSWORD      # Required: Password
SNOWFLAKE_WAREHOUSE     # Optional: Default COMPUTE_WH
SNOWFLAKE_ROLE          # Optional: Default ACCOUNTADMIN
```

## 📦 Installation

```bash
# Recommended: Install from requirements file
pip install -r requirements.txt

# Or install packages individually
pip install pyiceberg pyarrow pandas tabulate requests snowflake-connector-python
```

## 🔗 Catalog Endpoint

```
https://<account>.snowflakecomputing.com/polaris/api/catalog
```

**Example:**
```
https://myorg-myaccount.snowflakecomputing.com/polaris/api/catalog
```

## 🔍 Common PyIceberg Operations

```python
from pyiceberg.catalog import load_catalog
from pyiceberg.expressions import EqualTo, GreaterThan, And

# Load catalog
catalog = load_catalog("catalog_name", **config)

# List namespaces/databases
databases = catalog.list_namespaces()

# List tables
tables = catalog.list_tables("database_name")

# Create namespace
catalog.create_namespace("my_database")

# Create table
catalog.create_table("db.table", schema=my_schema)

# Load table
table = catalog.load_table("db.table")

# Append data
table.append(arrow_table)

# Overwrite data
table.overwrite(arrow_table)

# Scan with filter
data = table.scan(
    row_filter=EqualTo("column", "value"),
    limit=100
).to_pandas()

# Complex filter
data = table.scan(
    row_filter=And(
        GreaterThan("id", 1000),
        EqualTo("status", "active")
    )
).to_pandas()

# Get snapshots
snapshots = table.snapshots()

# Time travel - query historical data
old_data = table.scan(
    snapshot_id=snapshots[1].snapshot_id
).to_pandas()

# Get schema
schema = table.schema()

# Get metadata
metadata = table.metadata
```

## 🐛 Troubleshooting Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| `Import "pyiceberg" could not be resolved` | `pip install pyiceberg` |
| `Authentication failed` | Check account identifier format (should be `org-account`) |
| `Warehouse not found` | Verify warehouse exists: `SHOW WAREHOUSES;` in Snowflake |
| `Warehouse suspended` | Start warehouse: `ALTER WAREHOUSE <name> RESUME;` |
| `Permission denied` | Grant privileges: `GRANT CREATE TABLE ON SCHEMA ... TO ROLE ...;` |
| `Table already exists` | Normal - table will be reused |
| `Connection timeout` | Check network/VPN connection and Snowflake status |
| `OAuth token error` | Verify username and password are correct |
| `Module not found` | Run `pip install -r requirements.txt` |

## 🔧 Configuration Files

### PyIceberg Config (~/.pyiceberg.yaml)
```yaml
catalog:
  snowflake_horizon:
    type: rest
    uri: https://myaccount.snowflakecomputing.com/polaris/api/catalog
    warehouse: COMPUTE_WH
    token: <your_token>
```

### Environment File (.env.snowflake)
```bash
export SNOWFLAKE_ACCOUNT='myorg-myaccount'
export SNOWFLAKE_USER='myuser'
export SNOWFLAKE_PASSWORD='mypassword'
export SNOWFLAKE_WAREHOUSE='COMPUTE_WH'
export SNOWFLAKE_ROLE='ACCOUNTADMIN'
```

**Usage:**
```bash
source .env.snowflake
```

## 📊 Sample Schema Definition

```python
import pyarrow as pa
from datetime import datetime

# Define schema
schema = pa.schema([
    pa.field('id', pa.int64()),
    pa.field('name', pa.string()),
    pa.field('email', pa.string()),
    pa.field('created_at', pa.timestamp('us')),
    pa.field('age', pa.int32()),
    pa.field('is_active', pa.bool_()),
    pa.field('balance', pa.float64())
])

# Create data
data = pa.Table.from_pylist([
    {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'created_at': datetime.now(),
        'age': 30,
        'is_active': True,
        'balance': 1000.50
    }
], schema=schema)

# Append to table
table.append(data)
```

## 🎯 Common Use Cases

### 1. Create and Populate Table
```bash
python blogcode_snowflake_iceberg.py --table customers
```

### 2. Query Specific Database
```bash
python blogcode_snowflake_iceberg.py \
  --database analytics_db \
  --table user_events
```

### 3. Use Custom Warehouse
```bash
python blogcode_snowflake_iceberg.py \
  --warehouse LARGE_WH \
  --table large_dataset
```

### 4. Override Account from Command Line
```bash
python blogcode_snowflake_iceberg.py \
  --account myorg-myaccount \
  --warehouse COMPUTE_WH \
  --table test_data
```

## 💡 Tips & Tricks

1. **Use environment variables** for credentials (never hardcode!)
2. **Run setup script** for interactive configuration: `./setup_snowflake_env.sh`
3. **Check snapshots** before time travel to see available history
4. **Use filters** to reduce data scanned and improve performance
5. **Monitor warehouse** usage in Snowflake for cost optimization
6. **Auto-suspend warehouses** to minimize costs when idle
7. **Use appropriate warehouse size** - start small and scale up if needed
8. **Enable query result caching** in Snowflake for repeated queries
9. **Add `.env*` to .gitignore** to prevent credential leaks
10. **Test with small tables** before scaling up

## 🔐 Security Checklist

- [ ] Credentials stored in environment variables (not in code)
- [ ] `.env*` files added to `.gitignore`
- [ ] Using least-privilege access roles
- [ ] MFA enabled on Snowflake account
- [ ] Regular password rotation scheduled
- [ ] Audit logs enabled in Snowflake
- [ ] Network security configured (allowed IP lists)
- [ ] Data encryption at rest enabled
- [ ] Data encryption in transit (HTTPS/TLS)
- [ ] Service accounts used for automation

## 📈 Performance Tips

### Warehouse Optimization
- Use appropriate warehouse size for your workload
- Enable auto-suspend (e.g., 5 minutes of inactivity)
- Enable auto-resume for on-demand usage
- Use multi-cluster warehouses for high concurrency

### Query Optimization
- Use filters to reduce data scanned
- Leverage Snowflake's result cache
- Cluster tables for better performance
- Use materialized views for common queries

### Cost Management
- Monitor warehouse usage with `SHOW WAREHOUSES;`
- Review query history for optimization opportunities
- Use resource monitors to prevent runaway costs
- Consider Snowflake's query acceleration service

## 📞 Support Resources

| Resource | Link |
|----------|------|
| Snowflake Docs | [docs.snowflake.com](https://docs.snowflake.com) |
| PyIceberg Docs | [py.iceberg.apache.org](https://py.iceberg.apache.org) |
| Apache Iceberg | [iceberg.apache.org](https://iceberg.apache.org) |
| Snowflake Community | [community.snowflake.com](https://community.snowflake.com) |

## 🛠️ Useful Snowflake Commands

```sql
-- Show warehouses
SHOW WAREHOUSES;

-- Show databases
SHOW DATABASES;

-- Show tables in database
SHOW TABLES IN DATABASE iceberg_db;

-- Check warehouse status
DESC WAREHOUSE COMPUTE_WH;

-- Resume warehouse
ALTER WAREHOUSE COMPUTE_WH RESUME;

-- Suspend warehouse
ALTER WAREHOUSE COMPUTE_WH SUSPEND;

-- Grant permissions
GRANT USAGE ON DATABASE iceberg_db TO ROLE my_role;
GRANT CREATE TABLE ON SCHEMA iceberg_db.public TO ROLE my_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA iceberg_db.public TO ROLE my_role;

-- Check current role and user
SELECT CURRENT_ROLE(), CURRENT_USER();
```

## 🔄 Typical Workflow

1. **Setup Environment**
   ```bash
   ./setup_snowflake_env.sh
   ```

2. **Run Script**
   ```bash
   python blogcode_snowflake_iceberg.py --table my_table
   ```

3. **Verify in Snowflake**
   ```sql
   USE DATABASE iceberg_db;
   SHOW TABLES;
   SELECT * FROM my_table;
   ```

4. **Query Snapshots**
   ```sql
   -- Check table history
   SELECT * FROM INFORMATION_SCHEMA.TABLE_STORAGE_METRICS 
   WHERE TABLE_NAME = 'MY_TABLE';
   ```

## 📖 Additional Reading

- **Snowflake Iceberg Tables**: Learn about Iceberg support in Snowflake
- **PyIceberg Guide**: Deep dive into PyIceberg features
- **Apache Iceberg Spec**: Understand the table format specification
- **Snowflake Security**: Best practices for securing your environment

---

**Last Updated:** October 2025  
**Version:** 1.0

Print this page or keep it handy for quick reference! 📋

**Quick Help:**
```bash
# Get help on script usage
python blogcode_snowflake_iceberg.py --help

# Interactive setup
./setup_snowflake_env.sh

# Verify installation
pip list | grep -E "pyiceberg|pyarrow|snowflake"
```
