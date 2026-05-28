-- Snowflake Iceberg V3 Comprehensive Guide
-- Script 09: Create Semantic View for Cortex Agent
-- =================================================
-- This DDL is the canonical form returned by GET_DDL('SEMANTIC_VIEW', ...)
-- See: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>;

CREATE OR REPLACE SEMANTIC VIEW <% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>
    TABLES (
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY PRIMARY KEY (VEHICLE_ID) COMMENT='Master data for vehicles and their drivers',
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_TELEMETRY_STREAM COMMENT='Real-time streaming telemetry events with VARIANT TELEMETRY_DATA. Use colon-notation to extract nested fields.',
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.SENSOR_READINGS COMMENT='Time-series sensor data including engine temp, oil pressure, fuel consumption',
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_LOCATIONS COMMENT='GPS positions with GEOGRAPHY LOCATION_POINT. Use H3_POINT_TO_CELL_STRING for spatial aggregation.',
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.MAINTENANCE_LOGS UNIQUE (LOG_ID) COMMENT='Vehicle maintenance events and service records (VARIANT LOG_DATA contains event_type, severity, total_cost)',
        <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.DAILY_FLEET_SUMMARY COMMENT='Pre-aggregated daily fleet metrics by region (Gold layer)'
    )
    RELATIONSHIPS (
        TELEMETRY_TO_REGISTRY AS VEHICLE_TELEMETRY_STREAM(VEHICLE_ID) REFERENCES VEHICLE_REGISTRY(VEHICLE_ID),
        SENSOR_TO_REGISTRY AS SENSOR_READINGS(VEHICLE_ID) REFERENCES VEHICLE_REGISTRY(VEHICLE_ID),
        LOCATIONS_TO_REGISTRY AS VEHICLE_LOCATIONS(VEHICLE_ID) REFERENCES VEHICLE_REGISTRY(VEHICLE_ID),
        MAINTENANCE_TO_REGISTRY AS MAINTENANCE_LOGS(VEHICLE_ID) REFERENCES VEHICLE_REGISTRY(VEHICLE_ID)
    )
    FACTS (
        VEHICLE_LOCATIONS.LATITUDE AS LATITUDE COMMENT='GPS latitude',
        VEHICLE_LOCATIONS.LONGITUDE AS LONGITUDE COMMENT='GPS longitude'
    )
    DIMENSIONS (
        VEHICLE_REGISTRY.VEHICLE_ID AS VEHICLE_ID COMMENT='Unique identifier for the vehicle (format VH-XXXX)',
        VEHICLE_REGISTRY.MAKE AS MAKE COMMENT='Vehicle manufacturer',
        VEHICLE_REGISTRY.MODEL AS MODEL COMMENT='Vehicle model',
        VEHICLE_REGISTRY.YEAR AS YEAR COMMENT='Vehicle model year',
        VEHICLE_REGISTRY.FLEET_REGION AS FLEET_REGION COMMENT='Geographic region of the fleet (Pacific Northwest, California, Mountain West, Midwest, Northeast)',
        VEHICLE_REGISTRY.DRIVER_NAME AS DRIVER_NAME COMMENT='Name of the assigned driver (PII - subject to masking)',
        VEHICLE_TELEMETRY_STREAM.VEHICLE_ID AS VEHICLE_ID COMMENT='Vehicle identifier',
        VEHICLE_TELEMETRY_STREAM.CHECK_ENGINE AS TELEMETRY_DATA:diagnostics:check_engine::BOOLEAN COMMENT='Check engine light status from diagnostics',
        VEHICLE_TELEMETRY_STREAM.EVENT_TIMESTAMP AS EVENT_TIMESTAMP COMMENT='Timestamp of the telemetry event (microsecond precision)',
        VEHICLE_TELEMETRY_STREAM.EVENT_DATE AS DATE(EVENT_TIMESTAMP) COMMENT='Date of the telemetry event',
        SENSOR_READINGS.VEHICLE_ID AS VEHICLE_ID COMMENT='Vehicle identifier',
        SENSOR_READINGS.READING_TIMESTAMP AS READING_TIMESTAMP COMMENT='Timestamp of the sensor reading',
        SENSOR_READINGS.READING_DATE AS DATE(READING_TIMESTAMP) COMMENT='Date of the reading',
        VEHICLE_LOCATIONS.VEHICLE_ID AS VEHICLE_ID COMMENT='Vehicle identifier',
        VEHICLE_LOCATIONS.FLEET_REGION AS FLEET_REGION COMMENT='Fleet region (California, Pacific Northwest, Mountain West, Midwest, Northeast)',
        VEHICLE_LOCATIONS.H3_CELL_RESOLUTION_6 AS H3_POINT_TO_CELL_STRING(LOCATION_POINT, 6) COMMENT='H3 geospatial cell at resolution 6 for spatial aggregation',
        VEHICLE_LOCATIONS.H3_CELL_RESOLUTION_7 AS H3_POINT_TO_CELL_STRING(LOCATION_POINT, 7) COMMENT='H3 geospatial cell at resolution 7 for finer spatial aggregation',
        VEHICLE_LOCATIONS.LOCATION_TIMESTAMP AS LOCATION_TIMESTAMP COMMENT='Timestamp of the location reading',
        VEHICLE_LOCATIONS.LOCATION_DATE AS DATE(LOCATION_TIMESTAMP) COMMENT='Date of the location reading',
        MAINTENANCE_LOGS.LOG_ID AS LOG_ID COMMENT='Unique identifier for the log entry',
        MAINTENANCE_LOGS.VEHICLE_ID AS VEHICLE_ID COMMENT='Vehicle that received maintenance',
        MAINTENANCE_LOGS.EVENT_TYPE AS LOG_DATA:event_type::STRING COMMENT='Type of maintenance event',
        MAINTENANCE_LOGS.SEVERITY AS LOG_DATA:severity::STRING COMMENT='Severity level (LOW, MEDIUM, HIGH, CRITICAL)',
        MAINTENANCE_LOGS.LOG_TIMESTAMP AS LOG_TIMESTAMP COMMENT='Timestamp of the maintenance log',
        MAINTENANCE_LOGS.LOG_DATE AS DATE(LOG_TIMESTAMP) COMMENT='Date of the maintenance log',
        DAILY_FLEET_SUMMARY.FLEET_REGION AS FLEET_REGION COMMENT='Fleet region',
        DAILY_FLEET_SUMMARY.SUMMARY_DATE AS SUMMARY_DATE COMMENT='Date of the summary'
    )
    METRICS (
        VEHICLE_REGISTRY.VEHICLE_COUNT AS COUNT(DISTINCT VEHICLE_ID) COMMENT='Count of distinct vehicles in the registry',
        VEHICLE_TELEMETRY_STREAM.AVG_SPEED_MPH AS AVG(TELEMETRY_DATA:speed_mph::FLOAT) COMMENT='Average vehicle speed in MPH',
        VEHICLE_TELEMETRY_STREAM.MAX_SPEED_MPH AS MAX(TELEMETRY_DATA:speed_mph::FLOAT) COMMENT='Maximum vehicle speed in MPH',
        VEHICLE_TELEMETRY_STREAM.AVG_ENGINE_TEMP_F AS AVG(TELEMETRY_DATA:engine:temperature_f::INT) COMMENT='Average engine temperature in Fahrenheit',
        VEHICLE_TELEMETRY_STREAM.AVG_FUEL_LEVEL_PCT AS AVG(TELEMETRY_DATA:engine:fuel_level_pct::FLOAT) COMMENT='Average fuel level percentage',
        VEHICLE_TELEMETRY_STREAM.TOTAL_HARD_BRAKES AS SUM(TELEMETRY_DATA:driver_behavior:hard_brake_count::INT) COMMENT='Total hard braking events',
        VEHICLE_TELEMETRY_STREAM.TOTAL_HARD_ACCELERATIONS AS SUM(TELEMETRY_DATA:driver_behavior:hard_acceleration_count::INT) COMMENT='Total hard acceleration events',
        VEHICLE_TELEMETRY_STREAM.TOTAL_SHARP_TURNS AS SUM(TELEMETRY_DATA:driver_behavior:sharp_turn_count::INT) COMMENT='Total sharp turn events',
        VEHICLE_TELEMETRY_STREAM.EVENT_COUNT AS COUNT(*) COMMENT='Total number of telemetry events',
        SENSOR_READINGS.AVG_FUEL_CONSUMPTION_GPH AS AVG(FUEL_CONSUMPTION_GPH) COMMENT='Average fuel consumption in gallons per hour',
        SENSOR_READINGS.AVG_ENGINE_TEMP_F AS AVG(ENGINE_TEMP_F) COMMENT='Average engine temperature in Fahrenheit',
        SENSOR_READINGS.AVG_OIL_PRESSURE_PSI AS AVG(OIL_PRESSURE_PSI) COMMENT='Average oil pressure in PSI',
        VEHICLE_LOCATIONS.AVG_SPEED_MPH AS AVG(SPEED_MPH) COMMENT='Average speed in MPH',
        VEHICLE_LOCATIONS.VEHICLE_COUNT AS COUNT(DISTINCT VEHICLE_ID) COMMENT='Count of distinct vehicles seen at this location',
        MAINTENANCE_LOGS.TOTAL_COST AS SUM(LOG_DATA:total_cost::FLOAT) COMMENT='Total maintenance cost',
        MAINTENANCE_LOGS.EVENT_COUNT AS COUNT(*) COMMENT='Number of maintenance events',
        DAILY_FLEET_SUMMARY.ACTIVE_VEHICLES AS SUM(ACTIVE_VEHICLES) COMMENT='Active vehicles for the day',
        DAILY_FLEET_SUMMARY.TOTAL_EVENTS AS SUM(TOTAL_EVENTS) COMMENT='Total telemetry events for the day',
        DAILY_FLEET_SUMMARY.AVG_SPEED_MPH AS AVG(AVG_SPEED_MPH) COMMENT='Average speed for the day',
        DAILY_FLEET_SUMMARY.CRITICAL_EVENTS AS SUM(CRITICAL_EVENTS) COMMENT='Critical engine-health events',
        DAILY_FLEET_SUMMARY.AGGRESSIVE_DRIVING_EVENTS AS SUM(AGGRESSIVE_DRIVING_EVENTS) COMMENT='Aggressive driving events'
    )
    COMMENT='Semantic view for fleet analytics on Iceberg V3 tables. Powers the Cortex Agent.'
    AI_VERIFIED_QUERIES (
        HIGHEST_FUEL_CONSUMPTION_LAST_WEEK AS (
            QUESTION 'Which vehicles had the highest fuel consumption last week?'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    VEHICLE_ID,
    ROUND(AVG(FUEL_CONSUMPTION_GPH), 2) AS avg_fuel_consumption_gph,
    COUNT(*) AS reading_count
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.SENSOR_READINGS
WHERE READING_TIMESTAMP >= DATEADD(''week'', -1, CURRENT_TIMESTAMP())
GROUP BY VEHICLE_ID
ORDER BY avg_fuel_consumption_gph DESC
LIMIT 10
'),
        CRITICAL_MAINTENANCE_EVENTS AS (
            QUESTION 'Show me all critical maintenance events'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    LOG_ID,
    VEHICLE_ID,
    LOG_TIMESTAMP,
    LOG_DATA:event_type::STRING AS event_type,
    LOG_DATA:description::STRING AS description,
    LOG_DATA:total_cost::FLOAT AS total_cost
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.MAINTENANCE_LOGS
WHERE LOG_DATA:severity::STRING = ''CRITICAL''
ORDER BY LOG_TIMESTAMP DESC
LIMIT 20
'),
        AVG_SPEED_BY_REGION AS (
            QUESTION 'What is the average speed by fleet region?'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    FLEET_REGION,
    ROUND(AVG(SPEED_MPH), 1) AS avg_speed_mph,
    COUNT(DISTINCT VEHICLE_ID) AS vehicle_count
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_LOCATIONS
WHERE LOCATION_TIMESTAMP >= DATEADD(''day'', -1, CURRENT_TIMESTAMP())
GROUP BY FLEET_REGION
ORDER BY avg_speed_mph DESC
'),
        DRIVERS_MOST_HARD_BRAKING AS (
            QUESTION 'Which drivers have the most hard braking events?'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    r.DRIVER_NAME,
    t.VEHICLE_ID,
    SUM(t.TELEMETRY_DATA:driver_behavior:hard_brake_count::INT) AS total_hard_brakes,
    SUM(t.TELEMETRY_DATA:driver_behavior:hard_acceleration_count::INT) AS total_hard_accelerations,
    COUNT(*) AS event_count
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_TELEMETRY_STREAM t
JOIN <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY r
  ON t.VEHICLE_ID = r.VEHICLE_ID
GROUP BY r.DRIVER_NAME, t.VEHICLE_ID
ORDER BY total_hard_brakes DESC
LIMIT 10
'),
        VEHICLES_CHECK_ENGINE_WARNINGS AS (
            QUESTION 'Find vehicles with check engine warnings'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    VEHICLE_ID,
    COUNT(*) AS warning_count,
    MAX(EVENT_TIMESTAMP) AS last_warning
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_TELEMETRY_STREAM
WHERE TELEMETRY_DATA:diagnostics:check_engine::BOOLEAN = TRUE
GROUP BY VEHICLE_ID
ORDER BY warning_count DESC
LIMIT 10
'),
        VEHICLES_PER_H3_CELL_CALIFORNIA AS (
            QUESTION 'How many vehicles are in each H3 cell in California?'
            ONBOARDING_QUESTION FALSE
            SQL 'SELECT
    H3_POINT_TO_CELL_STRING(LOCATION_POINT, 6) AS h3_cell,
    COUNT(DISTINCT VEHICLE_ID) AS vehicle_count,
    ROUND(AVG(SPEED_MPH), 1) AS avg_speed_mph
FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_LOCATIONS
WHERE FLEET_REGION = ''California''
GROUP BY h3_cell
ORDER BY vehicle_count DESC
LIMIT 20
')
    );
