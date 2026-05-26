-- Use Snowflake Managed Storage — no external volume object required
ALTER DATABASE <% ctx.env.DEMO_DATABASE_NAME %> SET EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED';
