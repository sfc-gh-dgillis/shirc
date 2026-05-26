CREATE OR REPLACE EXTERNAL VOLUME <% ctx.env.EXTERNAL_VOLUME_NAME %>
   STORAGE_LOCATIONS =
      (
         (
            NAME = '<% ctx.env.EXTERNAL_VOLUME_NAME %>',
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = '<% ctx.env.STORAGE_BASE_URL %>'
            STORAGE_AWS_ROLE_ARN = '<% ctx.env.STORAGE_AWS_ROLE_ARN %>'
            STORAGE_AWS_EXTERNAL_ID = '<% ctx.env.TRUST_POLICY_EXTERNAL_ID %>'
         )
      )
      ALLOW_WRITES = TRUE;
