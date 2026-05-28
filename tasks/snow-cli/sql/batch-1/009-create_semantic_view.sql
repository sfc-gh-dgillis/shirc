-- Snowflake Iceberg V3 Comprehensive Guide
-- Script 09: Create Semantic View for Cortex Agent
-- =================================================
-- Creates a SEMANTIC VIEW (schema-level object) via SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML
-- so the Cortex Agent (010-create_agent.sql) can reference it by name instead of a stage YAML file.
-- See: https://docs.snowflake.com/en/sql-reference/stored-procedures/system_create_semantic_view_from_yaml

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>;

-- The semantic view name is taken from the `name:` field in the YAML body below.
-- We lowercase-quote it inside the YAML so the resulting object is named exactly DEMO_SEMANTIC_VIEW_NAME.
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
    '<% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>',
    $$
name: <% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>
description: Semantic view for fleet analytics on Iceberg V3 tables. Powers the Cortex Agent.

tables:
  - name: VEHICLE_REGISTRY
    description: Master data for vehicles and their drivers
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
      table: VEHICLE_REGISTRY
    primary_key:
      columns:
        - vehicle_id
    dimensions:
      - name: vehicle_id
        description: Unique identifier for the vehicle (format VH-XXXX)
        expr: VEHICLE_ID
        data_type: VARCHAR
        unique: true
      - name: make
        description: Vehicle manufacturer
        expr: MAKE
        data_type: VARCHAR
      - name: model
        description: Vehicle model
        expr: MODEL
        data_type: VARCHAR
      - name: year
        description: Vehicle model year
        expr: YEAR
        data_type: NUMBER
      - name: fleet_region
        description: Geographic region of the fleet (Pacific Northwest, California, Mountain West, Midwest, Northeast)
        expr: FLEET_REGION
        data_type: VARCHAR
      - name: driver_name
        description: Name of the assigned driver (PII - subject to masking)
        expr: DRIVER_NAME
        data_type: VARCHAR
    metrics:
      - name: vehicle_count
        description: Count of distinct vehicles in the registry
        expr: COUNT(DISTINCT VEHICLE_ID)

  - name: VEHICLE_TELEMETRY_STREAM
    description: Real-time streaming telemetry events with VARIANT TELEMETRY_DATA. Use colon-notation to extract nested fields.
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
      table: VEHICLE_TELEMETRY_STREAM
    dimensions:
      - name: vehicle_id
        description: Vehicle identifier
        expr: VEHICLE_ID
        data_type: VARCHAR
      - name: check_engine
        description: Check engine light status from diagnostics
        expr: "TELEMETRY_DATA:diagnostics:check_engine::BOOLEAN"
        data_type: BOOLEAN
    time_dimensions:
      - name: event_timestamp
        description: Timestamp of the telemetry event (microsecond precision)
        expr: EVENT_TIMESTAMP
        data_type: TIMESTAMP_NTZ
      - name: event_date
        description: Date of the telemetry event
        expr: DATE(EVENT_TIMESTAMP)
        data_type: DATE
    metrics:
      - name: avg_speed_mph
        description: Average vehicle speed in MPH
        expr: AVG(TELEMETRY_DATA:speed_mph::FLOAT)
      - name: max_speed_mph
        description: Maximum vehicle speed in MPH
        expr: MAX(TELEMETRY_DATA:speed_mph::FLOAT)
      - name: avg_engine_temp_f
        description: Average engine temperature in Fahrenheit
        expr: AVG(TELEMETRY_DATA:engine:temperature_f::INT)
      - name: avg_fuel_level_pct
        description: Average fuel level percentage
        expr: AVG(TELEMETRY_DATA:engine:fuel_level_pct::FLOAT)
      - name: total_hard_brakes
        description: Total hard braking events
        expr: SUM(TELEMETRY_DATA:driver_behavior:hard_brake_count::INT)
      - name: total_hard_accelerations
        description: Total hard acceleration events
        expr: SUM(TELEMETRY_DATA:driver_behavior:hard_acceleration_count::INT)
      - name: total_sharp_turns
        description: Total sharp turn events
        expr: SUM(TELEMETRY_DATA:driver_behavior:sharp_turn_count::INT)
      - name: event_count
        description: Total number of telemetry events
        expr: COUNT(*)

  - name: SENSOR_READINGS
    description: Time-series sensor data including engine temp, oil pressure, fuel consumption
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
      table: SENSOR_READINGS
    dimensions:
      - name: vehicle_id
        description: Vehicle identifier
        expr: VEHICLE_ID
        data_type: VARCHAR
    time_dimensions:
      - name: reading_timestamp
        description: Timestamp of the sensor reading
        expr: READING_TIMESTAMP
        data_type: TIMESTAMP_NTZ
      - name: reading_date
        description: Date of the reading
        expr: DATE(READING_TIMESTAMP)
        data_type: DATE
    metrics:
      - name: avg_fuel_consumption_gph
        description: Average fuel consumption in gallons per hour
        expr: AVG(FUEL_CONSUMPTION_GPH)
      - name: avg_engine_temp_f
        description: Average engine temperature in Fahrenheit
        expr: AVG(ENGINE_TEMP_F)
      - name: avg_oil_pressure_psi
        description: Average oil pressure in PSI
        expr: AVG(OIL_PRESSURE_PSI)

  - name: VEHICLE_LOCATIONS
    description: GPS positions with GEOGRAPHY LOCATION_POINT. Use H3_POINT_TO_CELL_STRING for spatial aggregation.
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
      table: VEHICLE_LOCATIONS
    dimensions:
      - name: vehicle_id
        description: Vehicle identifier
        expr: VEHICLE_ID
        data_type: VARCHAR
      - name: fleet_region
        description: Fleet region (California, Pacific Northwest, Mountain West, Midwest, Northeast)
        expr: FLEET_REGION
        data_type: VARCHAR
      - name: h3_cell_resolution_6
        description: H3 geospatial cell at resolution 6 for spatial aggregation
        expr: "H3_POINT_TO_CELL_STRING(LOCATION_POINT, 6)"
        data_type: VARCHAR
      - name: h3_cell_resolution_7
        description: H3 geospatial cell at resolution 7 for finer spatial aggregation
        expr: "H3_POINT_TO_CELL_STRING(LOCATION_POINT, 7)"
        data_type: VARCHAR
    facts:
      - name: latitude
        description: GPS latitude
        expr: LATITUDE
        data_type: FLOAT
      - name: longitude
        description: GPS longitude
        expr: LONGITUDE
        data_type: FLOAT
    time_dimensions:
      - name: location_timestamp
        description: Timestamp of the location reading
        expr: LOCATION_TIMESTAMP
        data_type: TIMESTAMP_NTZ
      - name: location_date
        description: Date of the location reading
        expr: DATE(LOCATION_TIMESTAMP)
        data_type: DATE
    metrics:
      - name: avg_speed_mph
        description: Average speed in MPH
        expr: AVG(SPEED_MPH)
      - name: vehicle_count
        description: Count of distinct vehicles seen at this location
        expr: COUNT(DISTINCT VEHICLE_ID)

  - name: MAINTENANCE_LOGS
    description: Vehicle maintenance events and service records (VARIANT LOG_DATA contains event_type, severity, total_cost)
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>
      table: MAINTENANCE_LOGS
    dimensions:
      - name: log_id
        description: Unique identifier for the log entry
        expr: LOG_ID
        data_type: VARCHAR
        unique: true
      - name: vehicle_id
        description: Vehicle that received maintenance
        expr: VEHICLE_ID
        data_type: VARCHAR
      - name: event_type
        description: Type of maintenance event
        expr: "LOG_DATA:event_type::STRING"
        data_type: VARCHAR
      - name: severity
        description: Severity level (LOW, MEDIUM, HIGH, CRITICAL)
        expr: "LOG_DATA:severity::STRING"
        data_type: VARCHAR
    time_dimensions:
      - name: log_timestamp
        description: Timestamp of the maintenance log
        expr: LOG_TIMESTAMP
        data_type: TIMESTAMP_NTZ
      - name: log_date
        description: Date of the maintenance log
        expr: DATE(LOG_TIMESTAMP)
        data_type: DATE
    metrics:
      - name: total_cost
        description: Total maintenance cost
        expr: SUM(LOG_DATA:total_cost::FLOAT)
      - name: event_count
        description: Number of maintenance events
        expr: COUNT(*)

  - name: DAILY_FLEET_SUMMARY
    description: Pre-aggregated daily fleet metrics by region (Gold layer)
    base_table:
      database: <% ctx.env.DEMO_DATABASE_NAME %>
      schema: <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>
      table: DAILY_FLEET_SUMMARY
    dimensions:
      - name: fleet_region
        description: Fleet region
        expr: FLEET_REGION
        data_type: VARCHAR
    time_dimensions:
      - name: summary_date
        description: Date of the summary
        expr: SUMMARY_DATE
        data_type: DATE
    metrics:
      - name: active_vehicles
        description: Active vehicles for the day
        expr: SUM(ACTIVE_VEHICLES)
      - name: total_events
        description: Total telemetry events for the day
        expr: SUM(TOTAL_EVENTS)
      - name: avg_speed_mph
        description: Average speed for the day
        expr: AVG(AVG_SPEED_MPH)
      - name: critical_events
        description: Critical engine-health events
        expr: SUM(CRITICAL_EVENTS)
      - name: aggressive_driving_events
        description: Aggressive driving events
        expr: SUM(AGGRESSIVE_DRIVING_EVENTS)

relationships:
  - name: telemetry_to_registry
    left_table: VEHICLE_TELEMETRY_STREAM
    right_table: VEHICLE_REGISTRY
    relationship_columns:
      - left_column: vehicle_id
        right_column: vehicle_id
  - name: locations_to_registry
    left_table: VEHICLE_LOCATIONS
    right_table: VEHICLE_REGISTRY
    relationship_columns:
      - left_column: vehicle_id
        right_column: vehicle_id
  - name: sensor_to_registry
    left_table: SENSOR_READINGS
    right_table: VEHICLE_REGISTRY
    relationship_columns:
      - left_column: vehicle_id
        right_column: vehicle_id
  - name: maintenance_to_registry
    left_table: MAINTENANCE_LOGS
    right_table: VEHICLE_REGISTRY
    relationship_columns:
      - left_column: vehicle_id
        right_column: vehicle_id

verified_queries:
  - name: highest_fuel_consumption_last_week
    question: Which vehicles had the highest fuel consumption last week?
    sql: |
      SELECT
          VEHICLE_ID,
          ROUND(AVG(FUEL_CONSUMPTION_GPH), 2) AS avg_fuel_consumption_gph,
          COUNT(*) AS reading_count
      FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.SENSOR_READINGS
      WHERE READING_TIMESTAMP >= DATEADD('week', -1, CURRENT_TIMESTAMP())
      GROUP BY VEHICLE_ID
      ORDER BY avg_fuel_consumption_gph DESC
      LIMIT 10

  - name: critical_maintenance_events
    question: Show me all critical maintenance events
    sql: |
      SELECT
          LOG_ID,
          VEHICLE_ID,
          LOG_TIMESTAMP,
          LOG_DATA:event_type::STRING AS event_type,
          LOG_DATA:description::STRING AS description,
          LOG_DATA:total_cost::FLOAT AS total_cost
      FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.MAINTENANCE_LOGS
      WHERE LOG_DATA:severity::STRING = 'CRITICAL'
      ORDER BY LOG_TIMESTAMP DESC
      LIMIT 20

  - name: avg_speed_by_region
    question: What is the average speed by fleet region?
    sql: |
      SELECT
          FLEET_REGION,
          ROUND(AVG(SPEED_MPH), 1) AS avg_speed_mph,
          COUNT(DISTINCT VEHICLE_ID) AS vehicle_count
      FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_LOCATIONS
      WHERE LOCATION_TIMESTAMP >= DATEADD('day', -1, CURRENT_TIMESTAMP())
      GROUP BY FLEET_REGION
      ORDER BY avg_speed_mph DESC

  - name: drivers_most_hard_braking
    question: Which drivers have the most hard braking events?
    sql: |
      SELECT
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

  - name: vehicles_check_engine_warnings
    question: Find vehicles with check engine warnings
    sql: |
      SELECT
          VEHICLE_ID,
          COUNT(*) AS warning_count,
          MAX(EVENT_TIMESTAMP) AS last_warning
      FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_TELEMETRY_STREAM
      WHERE TELEMETRY_DATA:diagnostics:check_engine::BOOLEAN = TRUE
      GROUP BY VEHICLE_ID
      ORDER BY warning_count DESC
      LIMIT 10

  - name: vehicles_per_h3_cell_california
    question: How many vehicles are in each H3 cell in California?
    sql: |
      SELECT
          H3_POINT_TO_CELL_STRING(LOCATION_POINT, 6) AS h3_cell,
          COUNT(DISTINCT VEHICLE_ID) AS vehicle_count,
          ROUND(AVG(SPEED_MPH), 1) AS avg_speed_mph
      FROM <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_LOCATIONS
      WHERE FLEET_REGION = 'California'
      GROUP BY h3_cell
      ORDER BY vehicle_count DESC
      LIMIT 20
    $$
);

SELECT 'Semantic view created: <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>' AS STATUS;
