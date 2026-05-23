-- ========================================================================
-- STEP 1: Set Session Variables (Managed Storage — no external volume)
-- ========================================================================
-- UPDATE THESE VALUES:
SET warehouse_name = '{{ demo_warehouse_name }}';             -- e.g., 'COMPUTE_WH'
SET demo_database = '{{ demo_database_name }}';               -- e.g., 'DEMO_DB';
SET demo_database_comment = '{{ demo_database_ddl_comment }}'; -- e.g., 'Iceberg V3 demo'
SET demo_schema = '{{ demo_schema_name }}';                   -- e.g., 'RAW';
SET demo_engineer_role = '{{ demo_engineer_role_name }}';     -- e.g., 'JOHN_DOE_DATA_ENGINEER'
SET demo_engineer_user = '{{ demo_engineer_user_name }}';     -- e.g., 'JOHN_DOE

SET demo_setup_user = current_user();

-- Admin context
USE ROLE ACCOUNTADMIN;

-- ========================================================================
-- STEP 2: Create Demo Roles
-- ========================================================================
CREATE ROLE IF NOT EXISTS IDENTIFIER($DEMO_ENGINEER_ROLE);

-- ========================================================================
-- STEP 3: Users for each role, each user needs a Personal Access Token
-- ========================================================================
-- Service users (for PAT-based external access)
CREATE USER IF NOT EXISTS IDENTIFIER($DEMO_ENGINEER_USER) LOGIN_NAME=$DEMO_ENGINEER_USER TYPE='service';

-- Role assignments
GRANT ROLE IDENTIFIER($DEMO_ENGINEER_ROLE) TO USER IDENTIFIER($DEMO_SETUP_USER);
GRANT ROLE IDENTIFIER($DEMO_ENGINEER_ROLE) TO USER IDENTIFIER($DEMO_ENGINEER_USER);
GRANT ROLE IDENTIFIER($DEMO_ENGINEER_ROLE) TO USER IDENTIFIER($DEMO_SETUP_USER);

-- Default roles (so PAT runs with the intended role)
ALTER USER IDENTIFIER($DEMO_ENGINEER_USER) SET DEFAULT_ROLE = $DEMO_ENGINEER_ROLE;

-- ========================================================================
-- STEP 4: Grant resource access to demo roles
-- ========================================================================
GRANT USAGE ON WAREHOUSE IDENTIFIER($WAREHOUSE_NAME) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

-- ========================================================================
-- STEP 5: Create Database, Schemas, and grants on them
-- ========================================================================
CREATE DATABASE IF NOT EXISTS IDENTIFIER($DEMO_DATABASE)
    COMMENT = $DEMO_DATABASE_COMMENT;

-- Use Snowflake Managed Storage — no external volume object required
ALTER DATABASE IDENTIFIER($DEMO_DATABASE) SET EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED';

USE DATABASE IDENTIFIER($DEMO_DATABASE);

-- Primary schema for raw events (referenced as RAW in the notebook and Spark demo)
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($DEMO_SCHEMA);

-- Schema for AI-redacted tables (created by the notebook's AI_REDACT step)
CREATE SCHEMA IF NOT EXISTS REDACTED;

-- Grant database + all schemas (both RAW and REDACTED) to engineer role
GRANT USAGE ON DATABASE IDENTIFIER($DEMO_DATABASE) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);
GRANT USAGE ON ALL SCHEMAS IN DATABASE IDENTIFIER($DEMO_DATABASE) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

-- Grant table creation rights on both schemas
GRANT CREATE ICEBERG TABLE ON SCHEMA IDENTIFIER($DEMO_SCHEMA) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);
GRANT MONITOR ON SCHEMA IDENTIFIER($DEMO_SCHEMA) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

GRANT CREATE ICEBERG TABLE ON SCHEMA REDACTED TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);
GRANT MONITOR ON SCHEMA REDACTED TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

-- Create the internal named stage for JSON file uploads
USE DATABASE IDENTIFIER($DEMO_DATABASE);
USE SCHEMA IDENTIFIER($DEMO_SCHEMA);

CREATE OR REPLACE STAGE {{ demo_stage_name }}
    DIRECTORY = ( ENABLE = TRUE )
  ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
