-- ========================================================================
-- Iceberg V3 Demo Tables
-- ========================================================================
-- All tables use ICEBERG_VERSION = 3 explicitly so the format version
-- is self-documenting and environment-portable.  For environments where
-- every Iceberg table should default to V3 without the per-table clause,
-- Snowflake supports:
--   ALTER DATABASE  <db>     SET ICEBERG_VERSION_DEFAULT = 3;
--   ALTER SCHEMA    <schema> SET ICEBERG_VERSION_DEFAULT = 3;
--   ALTER ACCOUNT            SET ICEBERG_VERSION_DEFAULT = 3;
-- ========================================================================

SET warehouse_name   = '{{ demo_warehouse_name }}';
SET demo_database    = '{{ demo_database_name }}';
SET demo_schema      = '{{ demo_schema_name }}';
SET demo_engineer_role = '{{ demo_engineer_role_name }}';

USE ROLE      IDENTIFIER($DEMO_ENGINEER_ROLE);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE DATABASE  IDENTIFIER($DEMO_DATABASE);
USE SCHEMA    IDENTIFIER($DEMO_SCHEMA);

-- ========================================================================
-- TABLE 1: customer_events_v3_features
-- Demonstrates: VARIANT with auto-shredding, column DEFAULT (V3 feature)
-- Note: named distinctly from the notebook's CUSTOMER_EVENTS table to avoid
-- conflicts when both the notebook demo and this batch are run in the same schema.
-- ========================================================================
CREATE ICEBERG TABLE IF NOT EXISTS customer_events_v3_features (
    event_id   STRING           NOT NULL,
    event_ts   TIMESTAMP_LTZ(6) DEFAULT CURRENT_TIMESTAMP(),  -- V3: column default
    payload    VARIANT                                         -- V3: auto-shredded VARIANT
)
ICEBERG_VERSION = 3
CATALOG         = 'SNOWFLAKE'
BASE_LOCATION   = 'customer_events_v3_features';

-- ========================================================================
-- TABLE 2: customer_events_partitioned
-- Demonstrates: temporal + identity partition transforms, hierarchical
--               directory layout (V3), deletion vectors via
--               ENABLE_ICEBERG_MERGE_ON_READ (V3)
-- ========================================================================
CREATE ICEBERG TABLE IF NOT EXISTS customer_events_partitioned (
    event_id   STRING           NOT NULL,
    event_date DATE             DEFAULT CURRENT_DATE(),  -- V3: column default
    region     STRING,
    payload    VARIANT
)
PARTITION BY (DAY(event_date), region)   -- temporal + identity transforms
PATH_LAYOUT  = HIERARCHICAL              -- V3: hierarchical directory layout
ENABLE_ICEBERG_MERGE_ON_READ = TRUE      -- V3: deletion vectors for DML
ICEBERG_VERSION = 3
CATALOG         = 'SNOWFLAKE'
BASE_LOCATION   = 'customer_events_partitioned';

-- ========================================================================
-- TABLE 3: iot_events
-- Demonstrates: nanosecond-precision timestamps and GEOMETRY type (V3)
-- ========================================================================
CREATE ICEBERG TABLE IF NOT EXISTS iot_events (
    device_id     BIGINT           NOT NULL,
    recorded_at   TIMESTAMP_NTZ(9),   -- V3: nanosecond precision (timestamp_ns)
    location      GEOMETRY,           -- V3: geometry type
    reading       DOUBLE
)
ICEBERG_VERSION = 3
CATALOG         = 'SNOWFLAKE'
BASE_LOCATION   = 'iot_events';

-- ========================================================================
-- TABLE 4: vehicle_telemetry_stream
-- Demonstrates: Snowpipe Streaming into Iceberg V3 VARIANT columns
-- Data is ingested via the Snowpipe Streaming Python SDK (see
-- pyutil/snowpipe_streaming/stream_telemetry.py).
-- ========================================================================
CREATE ICEBERG TABLE IF NOT EXISTS vehicle_telemetry_stream (
    vehicle_id    STRING           NOT NULL,
    event_ts      TIMESTAMP_LTZ(6) DEFAULT CURRENT_TIMESTAMP(),
    telemetry     VARIANT
)
ICEBERG_VERSION = 3
CATALOG         = 'SNOWFLAKE'
BASE_LOCATION   = 'vehicle_telemetry_stream';

-- ========================================================================
-- TABLE 5: daily_event_counts (Dynamic Iceberg Table)
-- Demonstrates: Dynamic Iceberg V3 tables (auto-refreshed materialized view)
-- Note: TARGET_LAG drives automatic incremental refresh from the source table.
-- ========================================================================
CREATE DYNAMIC ICEBERG TABLE IF NOT EXISTS daily_event_counts (
    event_date  DATE,
    region      STRING,
    event_count NUMBER
)
TARGET_LAG      = '1 hour'
WAREHOUSE       = IDENTIFIER($WAREHOUSE_NAME)
ICEBERG_VERSION = 3
CATALOG         = 'SNOWFLAKE'
BASE_LOCATION   = 'daily_event_counts'
AS
    SELECT
        event_date,
        region,
        COUNT(*) AS event_count
    FROM customer_events_partitioned
    GROUP BY event_date, region;
