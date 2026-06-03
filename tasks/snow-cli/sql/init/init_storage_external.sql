-- Set external volume at database level so all Iceberg tables inherit it
ALTER DATABASE <% ctx.env.DEMO_DATABASE_NAME %> SET EXTERNAL_VOLUME = '<% ctx.env.EXTERNAL_VOLUME_NAME %>';

-- Grant usage on the external volume to the engineer role
GRANT USAGE ON EXTERNAL VOLUME <% ctx.env.EXTERNAL_VOLUME_NAME %> TO ROLE <% ctx.env.DEMO_ENGINEER_ROLE_NAME %>;
