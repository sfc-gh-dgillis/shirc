-- Admin context
USE ROLE ACCOUNTADMIN;

-- ========================================================================
-- STEP 2: Create Demo Roles
-- ========================================================================
CREATE ROLE IF NOT EXISTS <% ctx.env.demo_engineer_role %>;

-- ========================================================================
-- STEP 3: Users for each role, each user needs a Personal Access Token
-- ========================================================================
-- Service users (for PAT-based external access)
CREATE USER IF NOT EXISTS <% ctx.env.demo_engineer_user %> LOGIN_NAME=<% ctx.env.demo_engineer_user %> TYPE='service';

-- Role assignments
GRANT ROLE <% ctx.env.demo_engineer_role %> TO USER <% ctx.env.demo_setup_user %>;
GRANT ROLE <% ctx.env.demo_engineer_role %> TO USER <% ctx.env.demo_engineer_user %>;

-- Default roles (so PAT runs with the intended role)
ALTER USER <% ctx.env.demo_engineer_user %> SET DEFAULT_ROLE = <% ctx.env.demo_engineer_role %>;

-- ========================================================================
-- STEP 4: Grant resource access to demo roles
-- ========================================================================
--GRANT USAGE ON INTEGRATION ICEBERG_S3_INT TO ROLE DATA_ENGINEER; -- optional
GRANT USAGE ON EXTERNAL VOLUME <% ctx.env.demo_external_volume %> TO ROLE <% ctx.env.demo_engineer_role %>;
-- Analysts only read (no create), so USAGE on EXTERNAL VOLUME is not strictly required for them.
GRANT USAGE ON WAREHOUSE IDENTIFIER($WAREHOUSE_NAME) TO ROLE <% ctx.env.demo_engineer_role %>;

-- ========================================================================
-- STEP 5: Create Database, Schemas, and grants on them
-- ========================================================================
CREATE DATABASE IF NOT EXISTS <% ctx.env.demo_database %>
    COMMENT = <% ctx.env.demo_database_comment %>;

-- Required: set external volume at database level so all Iceberg tables inherit it
ALTER DATABASE <% ctx.env.demo_database %> SET EXTERNAL_VOLUME = <% ctx.env.demo_external_volume %>;

USE DATABASE <% ctx.env.demo_database %>;

-- Primary schema for raw events (referenced as RAW in the notebook and Spark demo)
CREATE SCHEMA IF NOT EXISTS <% ctx.env.demo_schema %>;

-- Grant database + all schemas (both RAW and REDACTED) to engineer role
GRANT USAGE ON DATABASE <% ctx.env.demo_database %> TO ROLE <% ctx.env.demo_engineer_role %>;
GRANT USAGE ON ALL SCHEMAS IN DATABASE <% ctx.env.demo_database %> TO ROLE <% ctx.env.demo_engineer_role %>;

-- Grant table creation rights on both schemas
GRANT CREATE ICEBERG TABLE ON SCHEMA <% ctx.env.demo_schema %> TO ROLE <% ctx.env.demo_engineer_role %>;
GRANT MONITOR ON SCHEMA <% ctx.env.demo_schema %> TO ROLE <% ctx.env.demo_engineer_role %>;

GRANT CREATE ICEBERG TABLE ON SCHEMA REDACTED TO ROLE <% ctx.env.demo_engineer_role %>;
GRANT MONITOR ON SCHEMA REDACTED TO ROLE <% ctx.env.demo_engineer_role %>;

-- Create the internal named stage for JSON file uploads
USE DATABASE <% ctx.env.demo_database %>;
USE SCHEMA <% ctx.env.demo_schema %>;

CREATE OR REPLACE STAGE {{ demo_stage_name }}
    DIRECTORY = ( ENABLE = TRUE )
	ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
