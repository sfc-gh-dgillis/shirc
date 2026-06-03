-- Snowflake Iceberg V3 Comprehensive Guide
-- Script 10: Create Helper Views and Cortex Agent
-- ================================================
-- Cortex Agents require Enterprise Edition or higher.
-- The agent references the semantic view created by 009-create_semantic_view.sql.
-- See: https://docs.snowflake.com/en/sql-reference/sql/create-agent

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>;

-- ============================================
-- ENABLE CROSS-REGION INFERENCE (Optional - commented out by default)
-- ============================================
-- Cortex Agents require LLMs that may not be available in all regions.
-- If you see "None of the preferred models are authorized or available in your region",
-- enable cross-region inference. Your data stays in your region; only inference is routed.
-- See: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference
--
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- ============================================
-- HELPER VIEWS (curated for the agent / BI tools)
-- ============================================

CREATE OR REPLACE VIEW VEHICLE_OVERVIEW AS
SELECT
    v.VEHICLE_ID,
    v.MAKE,
    v.MODEL,
    v.YEAR,
    v.DRIVER_NAME,
    v.FLEET_REGION,
    v.VEHICLE_STATUS,
    h.health_score,
    h.health_status,
    h.avg_engine_temp,
    h.check_engine_count AS recent_check_engine_alerts,
    h.maintenance_events_30d
FROM <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY v
LEFT JOIN <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.VEHICLE_HEALTH_SCORE h
    ON v.VEHICLE_ID = h.VEHICLE_ID;

CREATE OR REPLACE VIEW FLEET_PERFORMANCE AS
SELECT
    FLEET_REGION,
    summary_date,
    active_vehicles,
    total_events,
    ROUND(avg_speed_mph, 1) AS avg_speed_mph,
    ROUND(max_speed_mph, 1) AS max_speed_mph,
    ROUND(avg_fuel_level, 1) AS avg_fuel_level_pct,
    ROUND(avg_engine_temp, 1) AS avg_engine_temp_f,
    total_hard_accelerations + total_hard_brakes + total_sharp_turns AS total_driving_events,
    critical_events,
    warning_events,
    aggressive_driving_events
FROM <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.DAILY_FLEET_SUMMARY
ORDER BY summary_date DESC, FLEET_REGION;

CREATE OR REPLACE VIEW MAINTENANCE_SUMMARY AS
SELECT
    VEHICLE_ID,
    event_type,
    severity,
    description,
    LOG_TIMESTAMP,
    technician,
    service_center,
    labor_hours,
    total_cost,
    diagnostic_code_count,
    MAKE,
    MODEL,
    FLEET_REGION
FROM <% ctx.env.DEMO_SCHEMA_NAME_SILVER %>.MAINTENANCE_ANALYSIS
ORDER BY LOG_TIMESTAMP DESC;

-- ============================================
-- CREATE CORTEX AGENT
-- ============================================
-- The agent uses the cortex_analyst_text_to_sql tool backed by the semantic view
-- created in 009-create_semantic_view.sql.

CREATE OR REPLACE AGENT <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_AGENT_NAME %>
    COMMENT = 'AI assistant for fleet management analytics on Iceberg V3 tables'
    PROFILE = '{"display_name": "Fleet Analytics Agent", "color": "blue"}'
    FROM SPECIFICATION
    $$
    orchestration:
      budget:
        seconds: 60
        tokens: 32000

    instructions:
      response: "Provide clear, concise answers with relevant data. Format numbers for readability."
      orchestration: "Use the Analyst tool for all data queries about vehicles, sensors, maintenance, and locations."
      system: |
        You are a fleet analytics assistant helping users understand their vehicle fleet operations.
        The data comes from commercial vehicles tracked across the United States.

        Key entities:
        - Vehicles are identified by VEHICLE_ID in format 'VH-XXXX'
        - Fleet regions: Pacific Northwest, California, Mountain West, Midwest, Northeast

        Data sources available via the semantic view:
        - VEHICLE_REGISTRY: Driver info (may be masked), vehicle make/model/year/region
        - VEHICLE_TELEMETRY_STREAM: Real-time streaming telemetry with VARIANT TELEMETRY_DATA
        - SENSOR_READINGS: Time-series sensor data (FUEL_CONSUMPTION_GPH, ENGINE_TEMP_F, OIL_PRESSURE_PSI)
        - VEHICLE_LOCATIONS: GEOGRAPHY LOCATION_POINT for geospatial; H3 cells available
        - MAINTENANCE_LOGS: VARIANT LOG_DATA with event_type, severity, total_cost
        - DAILY_FLEET_SUMMARY: Pre-aggregated daily metrics by region (gold layer)

        Query tips:
        - For VARIANT columns: use TELEMETRY_DATA:speed_mph::FLOAT
        - For geospatial: use H3_POINT_TO_CELL_STRING(LOCATION_POINT, 6)
      sample_questions:
        - question: "Which vehicles had the highest fuel consumption last week?"
          answer: "I'll query SENSOR_READINGS to analyze fuel consumption by vehicle."
        - question: "Show me all critical maintenance events"
          answer: "I'll search MAINTENANCE_LOGS for events with severity = 'CRITICAL'."
        - question: "What's the average speed by fleet region?"
          answer: "I'll aggregate speed data from VEHICLE_LOCATIONS grouped by region."
        - question: "Find vehicles with check engine warnings"
          answer: "I'll look for check_engine flags in the telemetry data."
        - question: "Which drivers have the most hard braking events?"
          answer: "I'll analyze hard_brake_count from telemetry joined with driver info."

    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "FleetAnalyst"
          description: "Converts natural language to SQL queries for fleet analytics data"

    tool_resources:
      FleetAnalyst:
        semantic_view: "<% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>"
    $$;

-- ============================================
-- GRANTS
-- ============================================

-- Helper views in the gold schema
GRANT SELECT ON VIEW <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.VEHICLE_OVERVIEW TO ROLE <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;
GRANT SELECT ON VIEW <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.FLEET_PERFORMANCE TO ROLE <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;
GRANT SELECT ON VIEW <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.MAINTENANCE_SUMMARY TO ROLE <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;

-- Semantic view (the agent's tool resource)
GRANT SELECT ON SEMANTIC VIEW <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>
    TO ROLE <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;
GRANT SELECT ON SEMANTIC VIEW <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_SEMANTIC_VIEW_NAME %>
    TO ROLE <% ctx.env.DEMO_ADMIN_ROLE_NAME %>;

-- The agent itself
GRANT USAGE ON AGENT <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_AGENT_NAME %>
    TO ROLE <% ctx.env.DEMO_ANALYST_ROLE_NAME %>;
GRANT USAGE ON AGENT <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_AGENT_NAME %>
    TO ROLE <% ctx.env.DEMO_ADMIN_ROLE_NAME %>;

-- ============================================
-- VERIFY
-- ============================================

SHOW AGENTS IN SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_GOLD %>;

SELECT 'Cortex Agent created: <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_GOLD %>.<% ctx.env.DEMO_AGENT_NAME %>' AS STATUS;
SELECT 'Navigate to Cortex AI > Agents in Snowsight to test the agent.' AS NEXT_STEP;
