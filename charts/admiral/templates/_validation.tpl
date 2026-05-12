{{/*
Validate Admiral chart configuration.
Produces clear error messages when required settings are missing.
*/}}
{{- define "admiral.validateValues" -}}

{{/* --- Database: must have either in-chart Postgres or external config --- */}}
{{- if not .Values.postgres.enabled }}
  {{- if not .Values.externalDatabase.host }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  A database is required. Either:\n    1. Enable the built-in Postgres:    postgres.enabled=true\n       (dev/demo only — single replica, no HA, no backups)\n    2. Configure an external database:  externalDatabase.host=<hostname>\n\n  For local development, use:  helm install admiral ./charts/admiral -f charts/admiral/demo-values.yaml\n" }}
  {{- end }}
{{- end }}

{{/* --- Object Storage: must have either subchart or external config --- */}}
{{- if not .Values.minio.enabled }}
  {{- if and (eq .Values.objectStorage.type "s3") (not .Values.objectStorage.s3.endpoint) }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  Object storage is required. Either:\n    1. Enable the built-in MinIO:       minio.enabled=true\n    2. Configure an S3 endpoint:        objectStorage.s3.endpoint=<url>\n    3. Configure GCS:                   objectStorage.type=gcs\n\n  For local development, use:  helm install admiral ./charts/admiral -f values/kind.yaml\n" }}
  {{- end }}
  {{- if and (eq .Values.objectStorage.type "gcs") (not .Values.objectStorage.gcs.projectId) }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  GCS project ID is required when objectStorage.type=gcs:\n    objectStorage.gcs.projectId=<your-gcp-project>\n" }}
  {{- end }}
{{- end }}

{{/* --- OIDC: must have either Dex or external issuer --- */}}
{{- if not .Values.dex.enabled }}
  {{- if not .Values.oauth2.issuer }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  An OIDC provider is required. Either:\n    1. Enable the built-in Dex:         dex.enabled=true\n    2. Configure an external provider:  oauth2.issuer=<issuer-url>\n\n  For local development, use:  helm install admiral ./charts/admiral -f values/kind.yaml\n" }}
  {{- end }}
  {{- if and (not .Values.oauth2.existingSecret) (not .Values.oauth2.clientSecret) }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  OAuth2 client credentials are required when using an external OIDC provider. Either:\n    1. Provide a secret:   oauth2.existingSecret=<secret-name>\n    2. Set inline:         oauth2.clientSecret=<secret>\n" }}
  {{- end }}
{{- end }}

{{/* --- External DB: password must be provided somehow --- */}}
{{- if and (not .Values.postgres.enabled) .Values.externalDatabase.host }}
  {{- if and (not .Values.externalDatabase.existingSecret) (not .Values.externalDatabase.password) }}
    {{- fail "\n\nADMIRAL CONFIGURATION ERROR:\n  External database password is required. Either:\n    1. Provide a secret:   externalDatabase.existingSecret=<secret-name>\n    2. Set inline:         externalDatabase.password=<password>\n" }}
  {{- end }}
{{- end }}

{{/* --- S3: credentials via secret or IRSA/Workload Identity --- */}}
{{/* No validation failure here: when using IRSA or Workload Identity, no secret
     is needed. The AWS SDK picks up credentials from the pod's service account
     automatically. Configure serviceAccount.annotations with the appropriate
     IAM role ARN or GCP service account. */}}

{{- end }}
