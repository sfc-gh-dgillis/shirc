-- Snowflake Iceberg V3 Comprehensive Guide
-- Script 03: Create Iceberg V3 Tables
-- ====================================
-- BASE_LOCATION is omitted: explicit paths break Snowflake-managed Iceberg storage.

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>;
USE WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %>;

-- ============================================
-- Table 1: VEHICLE_TELEMETRY_STREAM
-- Purpose: Real-time streaming vehicle telemetry with VARIANT
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE VEHICLE_TELEMETRY_STREAM (
    VEHICLE_ID STRING NOT NULL,
    EVENT_TIMESTAMP TIMESTAMP_NTZ(6) NOT NULL,
    TELEMETRY_DATA VARIANT NOT NULL,
    INGESTED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Real-time vehicle telemetry events streamed via Snowpipe Streaming';

-- ============================================
-- Table 2: MAINTENANCE_LOGS
-- Purpose: Batch-loaded JSON maintenance/diagnostic logs
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE MAINTENANCE_LOGS (
    LOG_ID STRING NOT NULL,
    VEHICLE_ID STRING NOT NULL,
    LOG_TIMESTAMP TIMESTAMP_NTZ(6) NOT NULL,
    LOG_DATA VARIANT NOT NULL,
    SOURCE_FILE STRING,
    INGESTED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott - 3 things (1. external volume on create statement 2. 6 columns here vs 5 in copy into 3. file_format should be JSON_FORMAT in COPY INTO, not (TYPE = JSON))
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Maintenance and diagnostic logs loaded from JSON files';

-- ============================================
-- Table 3: SENSOR_READINGS
-- Purpose: High-precision time-series sensor data
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE SENSOR_READINGS (
    READING_ID STRING NOT NULL,
    VEHICLE_ID STRING NOT NULL,
    READING_TIMESTAMP TIMESTAMP_NTZ(6) NOT NULL,  -- Microsecond precision for Spark compatibility
    ENGINE_TEMP_F FLOAT,
    OIL_PRESSURE_PSI FLOAT,
    BATTERY_VOLTAGE FLOAT,
    FUEL_CONSUMPTION_GPH FLOAT,
    TIRE_PRESSURE_FL FLOAT,
    TIRE_PRESSURE_FR FLOAT,
    TIRE_PRESSURE_RL FLOAT,
    TIRE_PRESSURE_RR FLOAT,
    ODOMETER_MILES FLOAT,
    INGESTED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'High-precision time-series sensor readings';

-- ============================================
-- Table 4: VEHICLE_LOCATIONS
-- Purpose: Geospatial vehicle position data
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE VEHICLE_LOCATIONS (
    LOCATION_ID STRING NOT NULL,
    VEHICLE_ID STRING NOT NULL,
    LOCATION_TIMESTAMP TIMESTAMP_NTZ(6) NOT NULL,
    LATITUDE FLOAT NOT NULL,
    LONGITUDE FLOAT NOT NULL,
    LOCATION_POINT GEOGRAPHY,
    ALTITUDE_FT FLOAT,
    HEADING_DEGREES FLOAT,
    SPEED_MPH FLOAT,
    FLEET_REGION STRING,
    INGESTED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Geospatial vehicle location data with GEOGRAPHY type';

-- ============================================
-- Table 5: VEHICLE_REGISTRY
-- Purpose: Master data for vehicles and drivers
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE VEHICLE_REGISTRY (
    VEHICLE_ID STRING NOT NULL,
    VIN STRING,
    MAKE STRING,
    MODEL STRING,
    YEAR INT,
    LICENSE_PLATE STRING,
    DRIVER_ID STRING,
    DRIVER_NAME STRING,
    DRIVER_EMAIL STRING,
    DRIVER_PHONE STRING,
    FLEET_REGION STRING,
    VEHICLE_STATUS STRING DEFAULT 'ACTIVE',
    REGISTRATION_DATE DATE,
    LAST_SERVICE_DATE DATE,
    CREATED_AT TIMESTAMP_LTZ(6),
    UPDATED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Master data for vehicles and drivers (contains PII)';

-- ============================================
-- Table 6: API_WEATHER_DATA
-- Purpose: Weather data from public API with VARIANT
-- Note: Using TIMESTAMP(6) for microsecond precision (Spark compatibility)
-- ============================================
CREATE OR REPLACE ICEBERG TABLE API_WEATHER_DATA (
    CITY_NAME STRING NOT NULL,
    LATITUDE FLOAT NOT NULL,
    LONGITUDE FLOAT NOT NULL,
    WEATHER_DATA VARIANT NOT NULL,
    INGESTED_AT TIMESTAMP_LTZ(6))
    -- TODO - discuss with Scott
    -- EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Weather data fetched from Open-Meteo API';

-- ============================================
-- Snowpipe Streaming default pipe
--
-- The Python SDK in pyutil/snowpipe_streaming/ uses the default pipe
-- naming convention <TABLE_NAME>-STREAMING (auto-created on first
-- channel open). No explicit CREATE PIPE is required for the
-- VEHICLE_TELEMETRY_STREAM table -- when stream_telemetry.py opens a
-- channel against pipe "VEHICLE_TELEMETRY_STREAM-STREAMING" Snowflake
-- materializes it on demand.
--
-- See: https://docs.snowflake.com/en/user-guide/snowpipe-streaming/snowpipe-streaming-pipe-object
-- ============================================
