-- ========================================================================
-- network_policy.sql
--
-- OPTIONAL: Ingress network policy for the streaming script.
--
-- Creates an INGRESS network rule scoped to your current public IP and a
-- network policy referencing it. Run this only if your workstation cannot
-- connect to Snowflake from the Snowpipe Streaming SDK (e.g. behind a
-- corporate VPN with restrictive egress, or your account already has a
-- network policy applied that blocks your IP).
--
-- WARNING: applying a network policy restricts connections to the listed IPs
-- only. If your IP changes (VPN reconnect, different network), you can lock
-- yourself out. This script intentionally creates the objects but does NOT
-- bind the policy to your user — you must run the ALTER USER step manually
-- once you have verified the detected IP.
--
-- See: https://docs.snowflake.com/en/user-guide/network-policies
-- ========================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE <% ctx.env.DEMO_DATABASE_NAME %>;
USE SCHEMA <% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>;

-- ------------------------------------------------------------------------
-- Auto-detect current IP and create rule + policy
-- ------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
    my_ip VARCHAR;
BEGIN
    SELECT CURRENT_IP_ADDRESS() INTO :my_ip;

    EXECUTE IMMEDIATE
        'CREATE OR REPLACE NETWORK RULE <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.<% ctx.env.DEMO_INGRESS_NETWORK_RULE_NAME %>
            MODE = INGRESS
            TYPE = IPV4
            VALUE_LIST = (''' || :my_ip || ''')
            COMMENT = ''Ingress rule for streaming script - IP: ' || :my_ip || '''';

    EXECUTE IMMEDIATE
        'CREATE OR REPLACE NETWORK POLICY <% ctx.env.DEMO_NETWORK_POLICY_NAME %>
            ALLOWED_NETWORK_RULE_LIST = (<% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.<% ctx.env.DEMO_INGRESS_NETWORK_RULE_NAME %>)
            COMMENT = ''Network policy for streaming script''';

    RETURN 'Created network rule and policy for IP: ' || :my_ip
        || '. Policy NOT YET APPLIED. To apply to your user run: '
        || 'ALTER USER <your_username> SET NETWORK_POLICY = <% ctx.env.DEMO_NETWORK_POLICY_NAME %>;';
END;
$$;

-- ------------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------------
SHOW NETWORK POLICIES LIKE '<% ctx.env.DEMO_NETWORK_POLICY_NAME %>';
SHOW NETWORK RULES LIKE '<% ctx.env.DEMO_INGRESS_NETWORK_RULE_NAME %>';

SELECT 'Detected IP' AS info, CURRENT_IP_ADDRESS() AS value
UNION ALL
SELECT 'Next step (run manually after verifying IP)',
       'ALTER USER <your_username> SET NETWORK_POLICY = <% ctx.env.DEMO_NETWORK_POLICY_NAME %>';

-- ========================================================================
-- Cleanup (run manually when no longer needed)
-- ========================================================================
-- ALTER USER <your_username> UNSET NETWORK_POLICY;
-- DROP NETWORK POLICY IF EXISTS <% ctx.env.DEMO_NETWORK_POLICY_NAME %>;
-- DROP NETWORK RULE  IF EXISTS <% ctx.env.DEMO_DATABASE_NAME %>.<% ctx.env.DEMO_SCHEMA_NAME_BRONZE %>.<% ctx.env.DEMO_INGRESS_NETWORK_RULE_NAME %>;
