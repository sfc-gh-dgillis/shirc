-- Admin context
USE ROLE ACCOUNTADMIN;

-- ========================================================================
-- STEP 2: Create Demo Roles
-- ========================================================================
CREATE ROLE IF NOT EXISTS <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

-- ========================================================================
-- STEP 3: Users for each role, each user needs a Personal Access Token
-- ========================================================================
-- Service users (for PAT-based external access)
CREATE USER IF NOT EXISTS <% ctx.env.DEMO_ENGINEER_USER_NAME %> LOGIN_NAME=<% ctx.env.DEMO_ENGINEER_USER_NAME %> TYPE='service';

-- Role assignments
GRANT ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %> TO USER <% ctx.env.DEMO_SETUP_USER %>;
GRANT ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %> TO USER <% ctx.env.DEMO_ENGINEER_USER_NAME %>;

-- Default roles (so PAT runs with the intended role)
ALTER USER <% ctx.env.DEMO_ENGINEER_USER_NAME %> SET DEFAULT_ROLE = <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

-- ========================================================================
-- STEP 4: Grant resource access to demo roles
-- ========================================================================
GRANT USAGE ON WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

-- ========================================================================
-- STEP 5: Create Database, Schemas, and grants on them
-- ========================================================================
CREATE DATABASE IF NOT EXISTS <% ctx.env.DEMO_DATABASE_NAME %>
    COMMENT = '<% ctx.env.DEMO_DATABASE_DDL_COMMENT %>';

-- Use Snowflake Managed Storage — no external volume object required
ALTER DATABASE <% ctx.env.DEMO_DATABASE_NAME %> SET EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED';

USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;

-- Primary schema for raw events (referenced as RAW in the notebook and Spark demo)
CREATE SCHEMA IF NOT EXISTS <% ctx.env.DEMO_SCHEMA_NAME %>;

-- Schema for AI-redacted tables (created by the notebook's AI_REDACT step)
CREATE SCHEMA IF NOT EXISTS REDACTED;

-- Grant database + all schemas (both RAW and REDACTED) to engineer role
GRANT USAGE ON DATABASE <% ctx.env.DEMO_DATABASE_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;
GRANT USAGE ON ALL SCHEMAS IN DATABASE <% ctx.env.DEMO_DATABASE_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

-- Grant table creation rights on both schemas
GRANT CREATE ICEBERG TABLE ON SCHEMA <% ctx.env.DEMO_SCHEMA_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;
GRANT MONITOR ON SCHEMA <% ctx.env.DEMO_SCHEMA_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

GRANT CREATE ICEBERG TABLE ON SCHEMA REDACTED TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;
GRANT MONITOR ON SCHEMA REDACTED TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;

-- Create the internal named stage for JSON file uploads
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME %>;

CREATE OR REPLACE STAGE <% ctx.env.DEMO_INTERNAL_NAMED_STAGE %>
    DIRECTORY = ( ENABLE = TRUE )
  ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
