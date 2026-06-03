-- Snowflake Iceberg V3 Comprehensive Guide
-- Script 05: Masking Policies, Tags, and Data Metric Functions
-- =============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE WAREHOUSE <% ctx.env.DEMO_WAREHOUSE_NAME %>;

-- ============================================
-- MASKING POLICIES
-- ============================================

-- Create schema for policies
CREATE SCHEMA IF NOT EXISTS <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>;

-- Masking policy for PII - Names
CREATE OR REPLACE MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_NAME_MASK AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('<% ctx.env.DEMO_ADMIN_ROLE_NAME %>', '<% ctx.env.DEMO_ENGINEER_ROLE_NAME %>', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() = '<% ctx.env.DEMO_ANALYST_ROLE_NAME %>' THEN
            CONCAT(LEFT(val, 2), REPEAT('*', LENGTH(val) - 4), RIGHT(val, 2))
        ELSE REPEAT('*', 8)
    END;

-- Masking policy for PII - Email
CREATE OR REPLACE MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_EMAIL_MASK AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('<% ctx.env.DEMO_ADMIN_ROLE_NAME %>', '<% ctx.env.DEMO_ENGINEER_ROLE_NAME %>', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() = '<% ctx.env.DEMO_ANALYST_ROLE_NAME %>' THEN
            CONCAT(
                LEFT(val, 2),
                REPEAT('*', POSITION('@' IN val) - 3),
                SUBSTRING(val, POSITION('@' IN val))
            )
        ELSE '****@****.***'
    END;

-- Masking policy for PII - Phone
CREATE OR REPLACE MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_PHONE_MASK AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('<% ctx.env.DEMO_ADMIN_ROLE_NAME %>', '<% ctx.env.DEMO_ENGINEER_ROLE_NAME %>', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() = '<% ctx.env.DEMO_ANALYST_ROLE_NAME %>' THEN
            CONCAT(LEFT(val, 6), '****', RIGHT(val, 2))
        ELSE '+1-***-***-****'
    END;

-- Apply masking policies to VEHICLE_REGISTRY PII columns
ALTER ICEBERG TABLE <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY
    MODIFY COLUMN DRIVER_NAME SET MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_NAME_MASK;
ALTER ICEBERG TABLE <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY
    MODIFY COLUMN DRIVER_EMAIL SET MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_EMAIL_MASK;
ALTER ICEBERG TABLE <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.VEHICLE_REGISTRY
    MODIFY COLUMN DRIVER_PHONE SET MASKING POLICY <% ctx.env.DEMO_POLICIES_SCHEMA_NAME %>.PII_PHONE_MASK;
