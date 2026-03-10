-- ========================================================================
-- Load sample JSON data into Iceberg V3 tables via COPY INTO
-- ========================================================================

SET warehouse_name     = '{{ demo_warehouse_name }}';
SET demo_database      = '{{ demo_database_name }}';
SET demo_schema        = '{{ demo_schema_name }}';
SET demo_engineer_role = '{{ demo_engineer_role_name }}';
SET demo_stage_name    = '{{ demo_stage_name }}';

USE ROLE      IDENTIFIER($DEMO_ENGINEER_ROLE);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE DATABASE  IDENTIFIER($DEMO_DATABASE);
USE SCHEMA    IDENTIFIER($DEMO_SCHEMA);

-- ── Load into customer_events_v3_features (base table)
COPY INTO customer_events_v3_features (event_id, payload)
FROM (
    SELECT
        $1:event_id::STRING,
        $1
    FROM IDENTIFIER($DEMO_STAGE_NAME)
)
FILE_FORMAT = (TYPE = 'JSON')
ON_ERROR    = 'CONTINUE';

-- ── Load into customer_events_partitioned
COPY INTO customer_events_partitioned (event_id, event_date, region, payload)
FROM (
    SELECT
        $1:event_id::STRING,
        $1:event_date::DATE,
        $1:region::STRING,
        $1
    FROM IDENTIFIER($DEMO_STAGE_NAME)
)
FILE_FORMAT = (TYPE = 'JSON')
ON_ERROR    = 'CONTINUE';
