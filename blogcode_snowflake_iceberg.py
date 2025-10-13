#!/usr/bin/env python3
"""
Apache Iceberg Table Operations with Snowflake Horizon Integration
"""

from pyiceberg.catalog import load_catalog
import os
import pyarrow as pa
import pandas as pd
from pyiceberg.expressions import EqualTo
import requests
import json
import argparse
from datetime import datetime
from tabulate import tabulate
import base64

# Constants
DEFAULT_DATABASE = 'iceberg_db'
DEFAULT_CATALOG = 'snowflake_iceberg'

def format_timestamp(timestamp_ms: int) -> str:
    """
    Convert millisecond timestamp to readable datetime string.
    """
    return datetime.fromtimestamp(timestamp_ms / 1000).strftime('%Y-%m-%d %H:%M:%S')

def get_snowflake_oauth_token(account: str, user: str, password: str) -> str:
    """
    Get OAuth token from Snowflake for REST catalog authentication.
    
    Args:
        account: Snowflake account identifier
        user: Snowflake username
        password: Snowflake password
        
    Returns:
        OAuth access token string
    """
    try:
        # Snowflake OAuth token endpoint
        token_url = f"https://{account}.snowflakecomputing.com/oauth/token-request"
        
        # Prepare authentication
        auth_string = f"{user}:{password}"
        auth_bytes = auth_string.encode('ascii')
        auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
        
        headers = {
            'Authorization': f'Basic {auth_b64}',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        data = {
            'grant_type': 'client_credentials',
            'scope': 'session:role-any'
        }
        
        response = requests.post(token_url, headers=headers, data=data)
        response.raise_for_status()
        
        return response.json()['access_token']
        
    except Exception as e:
        print(f"Error retrieving OAuth token: {e}")
        print("Tip: You may need to configure OAuth in your Snowflake account")
        print("Alternative: Use Snowflake connector-based authentication")
        return None

def get_snowflake_credentials() -> dict:
    """
    Retrieve Snowflake credentials from environment variables or prompt user.
    
    Returns:
        Dictionary containing Snowflake connection details
    """
    credentials = {
        'account': os.environ.get('SNOWFLAKE_ACCOUNT'),
        'user': os.environ.get('SNOWFLAKE_USER'),
        'password': os.environ.get('SNOWFLAKE_PASSWORD'),
        'warehouse': os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
        'role': os.environ.get('SNOWFLAKE_ROLE', 'ACCOUNTADMIN')
    }
    
    # Check if all required credentials are present
    missing = [k for k, v in credentials.items() if not v and k != 'role']
    
    if missing:
        print("\n⚠️  Missing Snowflake credentials. Please set the following environment variables:")
        for cred in missing:
            print(f"   - SNOWFLAKE_{cred.upper()}")
        print("\nExample:")
        print("   export SNOWFLAKE_ACCOUNT='your_account'")
        print("   export SNOWFLAKE_USER='your_username'")
        print("   export SNOWFLAKE_PASSWORD='your_password'")
        print("   export SNOWFLAKE_WAREHOUSE='your_warehouse'")
        return None
    
    return credentials

def format_databases(databases: list) -> None:
    """
    Format and print database list in a readable way.
    """
    print("\n📚 Available Databases:")
    db_data = [{'Database': db[0]} for db in databases]
    print(tabulate(db_data, headers='keys', tablefmt='grid', showindex=True))

def format_tables(tables: list, database: str) -> None:
    """
    Format and print table list in a readable way.
    """
    print(f"\n📋 Tables in {database}:")
    table_data = [{'Table Name': table[1]} for table in tables]
    print(tabulate(table_data, headers='keys', tablefmt='grid', showindex=True))

def create_customer_schema() -> pa.Schema:
    """
    Create and return the PyArrow schema for customer table.
    """
    return pa.schema([
        pa.field('c_salutation', pa.string()),
        pa.field('c_preferred_cust_flag', pa.string()),
        pa.field('c_first_sales_date_sk', pa.int32()),
        pa.field('c_customer_sk', pa.int32()),
        pa.field('c_first_name', pa.string()),
        pa.field('c_email_address', pa.string())
    ])

def get_sample_customer_data() -> dict:
    """
    Return sample customer data for testing.
    """
    return {
        "c_salutation": "Ms",
        "c_preferred_cust_flag": "NULL",
        "c_first_sales_date_sk": 2452736,
        "c_customer_sk": 1234,
        "c_first_name": "Mickey",
        "c_email_address": "mickey@email.com"
    }

def print_table_data(df: pd.DataFrame, title: str, highlight_flag: bool = False) -> None:
    """
    Print table data in a formatted way with optional highlighting.
    
    Args:
        df (pd.DataFrame): DataFrame to print
        title (str): Title for the data
        highlight_flag (bool): Whether to highlight the preferred_cust_flag column
    """
    print(f"\n📊 {title}")
    
    if highlight_flag:
        # Create a copy to avoid modifying the original DataFrame
        display_df = df.copy()
        
        # Reorder columns to put c_preferred_cust_flag near the beginning
        if 'c_preferred_cust_flag' in display_df.columns:
            cols = ['c_first_name', 'c_preferred_cust_flag'] + \
                   [col for col in display_df.columns if col not in [
                       'c_first_name', 'c_preferred_cust_flag'
                   ]]
            display_df = display_df[cols]
            
            # Add visual indicator for the flag
            display_df['c_preferred_cust_flag'] = '➡️ ' + display_df['c_preferred_cust_flag'].astype(str)
            
            # Add a header separator
            print("=" * 80)
            print("Focus on c_preferred_cust_flag column for changes")
            print("=" * 80)
    else:
        display_df = df

    print(tabulate(display_df, headers='keys', tablefmt='grid', showindex=False))

def print_snapshot_info(snapshots: list) -> None:
    """
    Print snapshot information in a formatted table.
    """
    if not snapshots:
        print("\n⚠️  No snapshots found for this table")
        return

    snapshot_data = []
    for snapshot in snapshots:
        snapshot_info = {
            'Snapshot ID': snapshot.snapshot_id,
            'Timestamp': format_timestamp(snapshot.timestamp_ms),
            'Manifest List': snapshot.manifest_list,
            'Schema ID': snapshot.schema_id,
            'Summary': snapshot.summary if hasattr(snapshot, 'summary') else 'N/A'
        }
        snapshot_data.append(snapshot_info)

    print("\n📸 Snapshot History:")
    print(tabulate(snapshot_data, headers='keys', tablefmt='grid'))

def initialize_catalog(catalog_name: str, account: str, warehouse: str, 
                       token: str = None, credentials: dict = None):
    """
    Initialize and return the Snowflake REST catalog.
    
    Args:
        catalog_name: Name for the catalog
        account: Snowflake account identifier
        warehouse: Snowflake warehouse name
        token: OAuth token (optional if using credentials)
        credentials: Dict with user/password for authentication
        
    Returns:
        Initialized catalog object
    """
    # Build the REST catalog URI
    catalog_uri = f"https://{account}.snowflakecomputing.com/polaris/api/catalog"
    
    catalog_config = {
        "type": "rest",
        "uri": catalog_uri,
        "warehouse": warehouse,
    }
    
    # Add authentication
    if token:
        catalog_config["token"] = token
    elif credentials:
        # Alternative: use credential-based auth if token not available
        catalog_config["credential"] = f"{credentials['user']}:{credentials['password']}"
    
    print(f"\n🔗 Connecting to: {catalog_uri}")
    print(f"🏭 Using warehouse: {warehouse}")
    
    return load_catalog(catalog_name, **catalog_config)

def hydrate_snowflake_iceberg_table(catalog_name: str, database_name: str, 
                                     table_name: str, credentials: dict) -> None:
    """
    Handle Iceberg table operations including creation, data insertion, and querying.
    
    Args:
        catalog_name: Name of the catalog
        database_name: Database/namespace name
        table_name: Table name
        credentials: Snowflake credentials dictionary
    """
    try:
        print("\n" + "="*50)
        print("❄️  Initializing Snowflake Iceberg Table Operations")
        print("="*50)
        print(f"📖 Catalog    : {catalog_name}")
        print(f"💾 Database   : {database_name}")
        print(f"📊 Table      : {table_name}")
        print(f"👤 Account    : {credentials['account']}")
        print("="*50)

        # Get OAuth token
        print("\n🔐 Authenticating with Snowflake...")
        token = get_snowflake_oauth_token(
            credentials['account'],
            credentials['user'],
            credentials['password']
        )
        
        # Initialize REST catalog
        rest_catalog = initialize_catalog(
            catalog_name,
            credentials['account'],
            credentials['warehouse'],
            token=token,
            credentials=credentials
        )

        # List available databases and tables
        print("\n🔍 Discovering catalog contents...")
        databases = rest_catalog.list_namespaces()
        
        format_databases(databases)
        
        # Check if database exists, create if not
        database_tuple = (database_name,)
        if database_tuple not in databases:
            print(f"\n📝 Creating database: {database_name}")
            rest_catalog.create_namespace(database_name)
        
        tables = rest_catalog.list_tables(namespace=database_name)
        format_tables(tables, database_name)

        # Create table with schema
        print("\n🔨 Creating table schema...")
        my_schema = create_customer_schema()
        
        # Check if table exists before creating
        table_identifier = f"{database_name}.{table_name}"
        try:
            rest_catalog.create_table(
                identifier=table_identifier,
                schema=my_schema
            )
            print("✅ Table created successfully")
        except Exception as e:
            print(f"ℹ️  Table creation note: {str(e)}")

        # Load the table
        table = rest_catalog.load_table(table_identifier)
        print(f"📋 Table schema: {table.schema()}")

        # Insert sample data
        print("\n➕ Inserting sample data...")
        sample_data = get_sample_customer_data()
        df = pa.Table.from_pylist([sample_data], schema=my_schema)
        table.append(df)
        print("✅ Sample data inserted successfully")

        # Query and display initial data
        print("\n🔎 Querying initial data...")
        tabledata = table.scan(
            row_filter=EqualTo("c_first_name", "Mickey"),
            limit=10
        ).to_pandas()
        print_table_data(tabledata, "Initial Data - Check preferred_cust_flag value", highlight_flag=True)

        # Update customer flag
        print("\n🔄 Updating customer flag...")
        print("Changing c_preferred_cust_flag from 'NULL' to 'N'")
        condition = tabledata['c_preferred_cust_flag'] == 'NULL'
        tabledata.loc[condition, 'c_preferred_cust_flag'] = 'N'
        df2 = pa.Table.from_pandas(tabledata, schema=my_schema)
        table.overwrite(df2)

        # Display updated data
        updated_tabledata = table.scan(
            row_filter=EqualTo("c_first_name", "Mickey"),
            limit=10
        ).to_pandas()
        print_table_data(updated_tabledata, "Updated Data - Notice the changed preferred_cust_flag", highlight_flag=True)

        # Add a summary of changes
        print("\n📝 Summary of Changes:")
        print("=" * 80)
        print("c_preferred_cust_flag modifications:")
        print(f"  Before: NULL")
        print(f"  After:  N")
        print("=" * 80)
        
        # Time Travel Operations
        print("\n⏰ Performing Time Travel Operations...")
        customer_snapshots = table.snapshots()
        print_snapshot_info(customer_snapshots)

        if customer_snapshots:
            latest_snapshot = customer_snapshots[0]
            print(f"\n📸 Retrieving data from snapshot {latest_snapshot.snapshot_id}")
            print(f"🕒 Snapshot timestamp: {format_timestamp(latest_snapshot.timestamp_ms)}")
            
            customer_snapshotdata = table.scan(snapshot_id=latest_snapshot.snapshot_id).to_arrow()
            snapshot_df = customer_snapshotdata.to_pandas()
            print_table_data(snapshot_df, "Snapshot Data")

            print("\n📊 Time Travel Summary:")
            print(f"  Total snapshots available: {len(customer_snapshots)}")
            if len(customer_snapshots) > 1:
                print(f"  Earliest snapshot: {format_timestamp(customer_snapshots[-1].timestamp_ms)}")
            print(f"  Latest snapshot: {format_timestamp(customer_snapshots[0].timestamp_ms)}")

    except Exception as e:
        print(f"\n❌ Error during table operations: {str(e)}")
        import traceback
        traceback.print_exc()
        raise

    print("\n✅ All operations completed successfully!")

def main():
    """
    Main function to handle command line arguments and execute table operations.
    """
    try:
        parser = argparse.ArgumentParser(
            description='Process Apache Iceberg table operations with Snowflake Horizon integration',
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
Examples:
  # Using environment variables (recommended)
  export SNOWFLAKE_ACCOUNT='your_account'
  export SNOWFLAKE_USER='your_user'
  export SNOWFLAKE_PASSWORD='your_password'
  export SNOWFLAKE_WAREHOUSE='COMPUTE_WH'
  
  %(prog)s --table customer_data
  
  # With custom database and catalog
  %(prog)s --database my_db --table my_table --catalog my_catalog

Prerequisites:
  1. Install required packages: pip install pyiceberg pyarrow pandas tabulate requests
  2. Configure Snowflake account with Iceberg table support
  3. Set environment variables for authentication
            """
        )
        
        parser.add_argument('--catalog', default=DEFAULT_CATALOG, 
                          help='Catalog name (default: %(default)s)')
        parser.add_argument('--database', default=DEFAULT_DATABASE, 
                          help='Database/namespace name (default: %(default)s)')
        parser.add_argument('--table', required=True, 
                          help='Table name (required)')
        parser.add_argument('--account', 
                          help='Snowflake account (overrides SNOWFLAKE_ACCOUNT env var)')
        parser.add_argument('--user', 
                          help='Snowflake user (overrides SNOWFLAKE_USER env var)')
        parser.add_argument('--warehouse', 
                          help='Snowflake warehouse (overrides SNOWFLAKE_WAREHOUSE env var)')

        args = parser.parse_args()

        # Get Snowflake credentials
        credentials = get_snowflake_credentials()
        
        if not credentials:
            print("\n❌ Failed to retrieve Snowflake credentials.")
            return 1
        
        # Override with command line arguments if provided
        if args.account:
            credentials['account'] = args.account
        if args.user:
            credentials['user'] = args.user
        if args.warehouse:
            credentials['warehouse'] = args.warehouse

        print("\n" + "="*50)
        print("❄️  Snowflake Iceberg REST Catalog Demo")
        print("="*50)
        print(f"Account: {credentials['account']}")
        print(f"User: {credentials['user']}")
        print(f"Warehouse: {credentials['warehouse']}")
        print("="*50)
        
        hydrate_snowflake_iceberg_table(
            args.catalog,
            args.database,
            args.table,
            credentials
        )
        
        return 0

    except KeyboardInterrupt:
        print("\n\n⚠️  Operation cancelled by user")
        return 130
    except Exception as e:
        print(f"\n❌ Error in main execution: {str(e)}")
        return 1

if __name__ == '__main__':
    exit(main())

