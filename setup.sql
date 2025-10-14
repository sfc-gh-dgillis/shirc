USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS ICEBERG_TEST_DB;

set external_volume = 'YOUR_EXTERNAL_VOLUME_NAME';
alter database ICEBERG_TEST_DB set external_volume = $external_volume;

CREATE OR REPLACE ICEBERG TABLE ICEBERG_TEST_DB.PUBLIC.TEST_TABLE_EXTENDED (
  col_int INT comment 'int column',
  col_string STRING comment 'string column',
  col_timestamp_ntz timestamp_ntz(6) comment 'timestamp_ntz column'
  )
  CATALOG='SNOWFLAKE'
  EXTERNAL_VOLUME=$external_volume
  BASE_LOCATION='test_table_extended';

insert into ICEBERG_TEST_DB.PUBLIC.TEST_TABLE_EXTENDED (col_int, col_string, col_timestamp_ntz)
values (1, 'test', '2025-01-01 01:00:00'),
(2, 'test2', '2025-01-02 02:00:00'),
(3, 'test3', '2025-01-03 03:00:00');



USE ROLE SECURITYADMIN;

-- Setup service account role and grant access to an iceberg table
CREATE OR REPLACE ROLE HORIZON_REST_SRV_ACCOUNT_ROLE;
-- Grant usage on the database and schema
GRANT USAGE,MONITOR ON DATABASE ICEBERG_TEST_DB TO ROLE HORIZON_REST_SRV_ACCOUNT_ROLE;
GRANT USAGE,MONITOR ON SCHEMA ICEBERG_TEST_DB.PUBLIC TO ROLE HORIZON_REST_SRV_ACCOUNT_ROLE;
-- Grant select on the specific Iceberg table
GRANT SELECT ON TABLE ICEBERG_TEST_DB.PUBLIC.TEST_TABLE_EXTENDED TO ROLE HORIZON_REST_SRV_ACCOUNT_ROLE;

-- Create a service user and assign the role
CREATE OR REPLACE USER HORIZON_REST_SRV_ACCOUNT_USER TYPE=SERVICE DEFAULT_ROLE=HORIZON_REST_SRV_ACCOUNT_ROLE;
GRANT ROLE HORIZON_REST_SRV_ACCOUNT_ROLE TO USER HORIZON_REST_SRV_ACCOUNT_USER;