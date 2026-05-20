-- ========================================================================
-- Drop Iceberg V3 demo tables (explicit teardown before dropping database)
-- ========================================================================
-- Note: DROP DATABASE IF EXISTS cascades to all tables, so this script is
-- only needed if you want to drop tables individually without destroying
-- the full database.
-- ========================================================================

SET demo_database      = '{{ demo_database_name }}';
SET demo_schema        = '{{ demo_schema_name }}';

USE ROLE ACCOUNTADMIN;
USE DATABASE  IDENTIFIER($DEMO_DATABASE);
USE SCHEMA    IDENTIFIER($DEMO_SCHEMA);

DROP DYNAMIC TABLE  IF EXISTS daily_event_counts;
DROP ICEBERG TABLE  IF EXISTS vehicle_telemetry_stream;
DROP ICEBERG TABLE  IF EXISTS iot_events;
DROP ICEBERG TABLE  IF EXISTS customer_events_partitioned;
DROP ICEBERG TABLE  IF EXISTS customer_events_v3_features;
