-- ========================================================================
-- STEP 1: Set Session Variables
-- ========================================================================
-- UPDATE THESE VALUES:
SET warehouse_name = '{{ demo_warehouse_name }}';             -- e.g., 'COMPUTE_WH'
SET demo_external_volume = '{{ your_external_volume_name }}'; -- e.g., 'MY_EXT_VOL'
SET demo_database = '{{ demo_database_name }}';               -- e.g., 'DEMO_DB';
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
-- STEP 4: Users for each role, each user needs a Personal Access Token
-- ========================================================================
--GRANT USAGE ON INTEGRATION ICEBERG_S3_INT TO ROLE DATA_ENGINEER; -- optional
GRANT USAGE ON EXTERNAL VOLUME IDENTIFIER($DEMO_EXTERNAL_VOLUME) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);
-- Analysts only read (no create), so USAGE on EXTERNAL VOLUME is not strictly required for them.

-- ========================================================================
-- STEP 5: Create Database, Schemas, and grants on them
-- ========================================================================
CREATE DATABASE IF NOT EXISTS IDENTIFIER($DEMO_DATABASE);

--Important note for PrPr, required
--Set external volume at database level that will be  used to create iceberg table
ALTER DATABASE IDENTIFIER($DEMO_DATABASE) SET EXTERNAL_VOLUME = IDENTIFIER($DEMO_EXTERNAL_VOLUME);

USE DATABASE IDENTIFIER($DEMO_DATABASE);

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($DEMO_SCHEMA);

-- Allow engineer to create tables in these schemas
GRANT USAGE ON DATABASE IDENTIFIER($DEMO_DATABASE)TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);
GRANT USAGE ON ALL SCHEMAS IN DATABASE IDENTIFIER($DEMO_DATABASE) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

GRANT CREATE ICEBERG TABLE ON SCHEMA IDENTIFIER($DEMO_SCHEMA) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

GRANT MONITOR ON SCHEMA IDENTIFIER($DEMO_SCHEMA) TO ROLE IDENTIFIER($DEMO_ENGINEER_ROLE);

--CREATE STAGE
USE DATABASE IDENTIFIER($DEMO_DATABASE);
USE SCHEMA IDENTIFIER($DEMO_SCHEMA);

CREATE OR REPLACE STAGE {{ demo_stage_name }}
    DIRECTORY = ( ENABLE = TRUE )
	ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );
