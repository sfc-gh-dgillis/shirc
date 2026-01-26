CREATE OR REPLACE EXTERNAL VOLUME {{ external_volume_name }}
   STORAGE_LOCATIONS =
      (
         (
            NAME = '{{ external_volume_name }}',
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = '{{ storage_base_url }}'
            STORAGE_AWS_ROLE_ARN = '{{ storage_aws_role_arn }}'
            STORAGE_AWS_EXTERNAL_ID = '{{ storage_aws_external_id }}'
         )
      )
      ALLOW_WRITES = TRUE;
