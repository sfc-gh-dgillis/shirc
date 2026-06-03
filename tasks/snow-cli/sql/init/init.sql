-- Admin context
USE ROLE ACCOUNTADMIN;

-- ========================================================================
-- STEP 1: Create Warehouse
-- ========================================================================
CREATE WAREHOUSE IF NOT EXISTS <% ctx.env.DEMO_WAREHOUSE_NAME %>
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Fleet Analytics Iceberg V3 Guide';

-- ========================================================================
-- STEP 2: Create Roles
-- ========================================================================
CREATE ROLE IF NOT EXISTS <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;
CREATE ROLE IF NOT EXISTS <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;
CREATE ROLE IF NOT EXISTS <% ctx.env.DEMO_ADMIN_ROLE_NAME %>;

-- ========================================================================
-- STEP 3: Create Database and set Iceberg defaults
-- ========================================================================
CREATE DATABASE IF NOT EXISTS <% ctx.env.DEMO_DATABASE_NAME %>
    COMMENT = '<% ctx.env.DEMO_DATABASE_DDL_COMMENT %>';

-- Set Iceberg V3 as the default version for all Iceberg tables in this database
-- See: https://docs.snowflake.com/en/LIMITEDACCESS/iceberg/tables-iceberg-v3-specification-support
ALTER DATABASE <% ctx.env.DEMO_DATABASE_NAME %> SET ICEBERG_VERSION_DEFAULT = 3;

-- NOTE: Storage mode (external volume or managed) is applied by a separate
-- mode-specific SQL file (init_storage_external.sql or init_storage_managed.sql)
-- run immediately after this script.

USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;

-- ========================================================================
-- STEP 3: Create Medallion Schemas (Bronze / Silver / Gold)
-- ========================================================================
CREATE SCHEMA IF NOT EXISTS <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
    COMMENT = 'Raw data layer - source Iceberg tables';

CREATE SCHEMA IF NOT EXISTS <% ctx.env.DEMO_SCHEMA_NAME_SILVER %>
    COMMENT = 'Curated data layer - transformed Iceberg tables';

CREATE SCHEMA IF NOT EXISTS <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>
    COMMENT = 'Analytics layer - aggregated Iceberg tables';

-- ========================================================================
-- STEP 4: Create internal named stage (in bronze schema for raw file uploads)
-- ========================================================================
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>;

CREATE STAGE IF NOT EXISTS <% ctx.env.DEMO_INTERNAL_NAMED_STAGE %>
    DIRECTORY = ( ENABLE = TRUE )
    ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' )
    COMMENT = '<% ctx.env.DEMO_INTERNAL_NAMED_STAGE_COMMENT %>';

-- ========================================================================
-- STEP 5: Create file format for JSON ingestion
-- ========================================================================
CREATE FILE FORMAT IF NOT EXISTS <% ctx.env.DEMO_JSON_FILE_FORMAT %>
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    COMMENT = '<% ctx.env.DEMO_JSON_FILE_FORMAT_COMMENT %>';

-- ========================================================================
-- STEP 6: External Access Integration for API calls
-- Required for Python code in notebooks to access external APIs
-- ========================================================================
CREATE OR REPLACE NETWORK RULE <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.<% ctx.env.DEMO_NETWORK_RULE_NAME %>
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<% ctx.env.DEMO_NETWORK_RULE_HOST %>');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION <% ctx.env.DEMO_EXTERNAL_ACCESS_INTEGRATION_NAME %>
    ALLOWED_NETWORK_RULES = (<% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.<% ctx.env.DEMO_NETWORK_RULE_NAME %>)
    ENABLED = TRUE
    COMMENT = '<% ctx.env.DEMO_EXTERNAL_ACCESS_INTEGRATION_COMMENT %>';
