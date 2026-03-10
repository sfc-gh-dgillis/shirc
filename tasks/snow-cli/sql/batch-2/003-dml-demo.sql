-- ========================================================================
-- Iceberg V3 DML demo: deletion vectors and row lineage
-- ========================================================================
-- In V3 tables with ENABLE_ICEBERG_MERGE_ON_READ = TRUE, UPDATE/DELETE/MERGE
-- write deletion vectors (bitmap files) instead of positional delete files.
-- This reduces write amplification and improves DML performance.
-- ========================================================================

SET warehouse_name     = '{{ demo_warehouse_name }}';
SET demo_database      = '{{ demo_database_name }}';
SET demo_schema        = '{{ demo_schema_name }}';
SET demo_engineer_role = '{{ demo_engineer_role_name }}';

USE ROLE      IDENTIFIER($DEMO_ENGINEER_ROLE);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE DATABASE  IDENTIFIER($DEMO_DATABASE);
USE SCHEMA    IDENTIFIER($DEMO_SCHEMA);

-- ── UPDATE: uses deletion vectors in V3 (vs. positional delete files in V2)
UPDATE customer_events_partitioned
SET region = 'us-west-2'
WHERE region = 'us-west';

-- ── MERGE: efficient with deletion vectors
MERGE INTO customer_events_v3_features t
USING (
    SELECT 'evt_merge_test' AS event_id,
           PARSE_JSON('{"source":"merge_test","region":"us-east-1"}') AS payload
) s
ON t.event_id = s.event_id
WHEN MATCHED     THEN UPDATE SET t.payload = s.payload
WHEN NOT MATCHED THEN INSERT (event_id, payload) VALUES (s.event_id, s.payload);

-- ── Row lineage: query the hidden _row_id column (V3 native metadata)
-- Each row in a V3 table has a unique BIGINT identifier maintained by Snowflake.
-- This enables CDC, auditing, and row-level data governance.
SELECT _row_id, event_id, event_ts, payload
FROM   customer_events_v3_features
LIMIT  10;

-- ── Confirm the tables are using Iceberg format version 3
SHOW PARAMETERS LIKE 'ICEBERG_VERSION' IN TABLE customer_events_v3_features;
SHOW PARAMETERS LIKE 'ICEBERG_VERSION' IN TABLE customer_events_partitioned;
SHOW PARAMETERS LIKE 'ICEBERG_VERSION' IN TABLE iot_events;
