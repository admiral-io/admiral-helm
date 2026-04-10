{{/*
Expand the name of the chart.
*/}}
{{- define "admiral.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "admiral.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "admiral.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "admiral.labels" -}}
helm.sh/chart: {{ include "admiral.chart" . }}
{{ include "admiral.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "admiral.selectorLabels" -}}
app.kubernetes.io/name: {{ include "admiral.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "admiral.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "admiral.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Dex naming helpers
   ======================================================================= */}}

{{/*
Dex fully qualified name
*/}}
{{- define "admiral.dex.fullname" -}}
{{- printf "%s-dex" (include "admiral.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Dex labels
*/}}
{{- define "admiral.dex.labels" -}}
helm.sh/chart: {{ include "admiral.chart" . }}
{{ include "admiral.dex.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Dex selector labels
*/}}
{{- define "admiral.dex.selectorLabels" -}}
app.kubernetes.io/name: {{ include "admiral.name" . }}-dex
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: dex
{{- end }}

{{/*
Dex service account name
*/}}
{{- define "admiral.dex.serviceAccountName" -}}
{{- if .Values.dex.serviceAccount.create }}
{{- default (include "admiral.dex.fullname" .) .Values.dex.serviceAccount.name | default (include "admiral.dex.fullname" .) }}
{{- else }}
{{- default "default" .Values.dex.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Database helpers
   ======================================================================= */}}

{{/*
Return the database host
*/}}
{{- define "admiral.database.host" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" .Release.Name }}
{{- else }}
{{- .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{/*
Return the database port
*/}}
{{- define "admiral.database.port" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "5432" }}
{{- else }}
{{- .Values.externalDatabase.port | toString }}
{{- end }}
{{- end }}

{{/*
Return the database name
*/}}
{{- define "admiral.database.name" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.database }}
{{- end }}
{{- end }}

{{/*
Return the database user
*/}}
{{- define "admiral.database.user" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.username }}
{{- else }}
{{- .Values.externalDatabase.username }}
{{- end }}
{{- end }}

{{/*
Return the database SSL mode
*/}}
{{- define "admiral.database.sslMode" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "disable" }}
{{- else }}
{{- .Values.externalDatabase.sslMode | default "disable" }}
{{- end }}
{{- end }}

{{/*
Return the name of the secret containing the database password
*/}}
{{- define "admiral.database.secretName" -}}
{{- if .Values.postgresql.enabled }}
  {{- if .Values.postgresql.auth.existingSecret }}
    {{- .Values.postgresql.auth.existingSecret }}
  {{- else }}
    {{- printf "%s-postgresql" .Release.Name }}
  {{- end }}
{{- else }}
  {{- if .Values.externalDatabase.existingSecret }}
    {{- .Values.externalDatabase.existingSecret }}
  {{- else }}
    {{- printf "%s-externaldb" (include "admiral.fullname" .) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Return the key within the database secret containing the password
*/}}
{{- define "admiral.database.secretKey" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "password" }}
{{- else }}
  {{- if .Values.externalDatabase.existingSecret }}
    {{- .Values.externalDatabase.existingSecretPasswordKey | default "db-password" }}
  {{- else }}
    {{- printf "db-password" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Object Storage helpers
   ======================================================================= */}}

{{/*
Return the object storage endpoint (S3/MinIO only)
*/}}
{{- define "admiral.objectStorage.endpoint" -}}
{{- if and .Values.minio.enabled (eq .Values.objectStorage.type "s3") }}
{{- printf "http://%s-minio:9000" .Release.Name }}
{{- else }}
{{- .Values.objectStorage.s3.endpoint }}
{{- end }}
{{- end }}

{{/*
Return the name of the secret containing storage credentials
*/}}
{{- define "admiral.objectStorage.secretName" -}}
{{- if and .Values.minio.enabled (eq .Values.objectStorage.type "s3") }}
  {{- if .Values.minio.existingSecret }}
    {{- .Values.minio.existingSecret }}
  {{- else }}
    {{- printf "%s-minio" .Release.Name }}
  {{- end }}
{{- else if eq .Values.objectStorage.type "s3" }}
  {{- .Values.objectStorage.s3.existingSecret }}
{{- else if eq .Values.objectStorage.type "gcs" }}
  {{- .Values.objectStorage.gcs.existingSecret }}
{{- end }}
{{- end }}

{{/*
Return the secret key for the storage access key
*/}}
{{- define "admiral.objectStorage.accessKeyKey" -}}
{{- if and .Values.minio.enabled (eq .Values.objectStorage.type "s3") }}
{{- printf "rootUser" }}
{{- else }}
{{- .Values.objectStorage.s3.accessKeyKey | default "rootUser" }}
{{- end }}
{{- end }}

{{/*
Return the secret key for the storage secret key
*/}}
{{- define "admiral.objectStorage.secretKeyKey" -}}
{{- if and .Values.minio.enabled (eq .Values.objectStorage.type "s3") }}
{{- printf "rootPassword" }}
{{- else }}
{{- .Values.objectStorage.s3.secretKeyKey | default "rootPassword" }}
{{- end }}
{{- end }}

{{/* =======================================================================
   OAuth2 / OIDC helpers
   ======================================================================= */}}

{{/*
Return the ingress scheme (http or https)
*/}}
{{- define "admiral.ingress.scheme" -}}
{{- if and .Values.ingress.enabled .Values.ingress.tls.enabled }}
{{- printf "https" }}
{{- else }}
{{- printf "http" }}
{{- end }}
{{- end }}

{{/*
Return the OAuth2 issuer URL.
When Dex is enabled, uses the external ingress URL so browser redirects work.
The admiral pod resolves this via hostAliases pointing to the ingress controller.
*/}}
{{- define "admiral.oauth2.issuer" -}}
{{- if and .Values.dex.enabled (not .Values.oauth2.issuer) }}
  {{- if .Values.dex.config.issuer }}
    {{- .Values.dex.config.issuer }}
  {{- else if .Values.ingress.enabled }}
    {{- printf "%s://%s/dex" (include "admiral.ingress.scheme" .) .Values.ingress.host }}
  {{- else }}
    {{- printf "http://%s:%s" (include "admiral.dex.fullname" .) (.Values.dex.service.port | toString) }}
  {{- end }}
{{- else }}
{{- .Values.oauth2.issuer }}
{{- end }}
{{- end }}

{{/*
Return the OAuth2 redirect URL
*/}}
{{- define "admiral.oauth2.redirectUrl" -}}
{{- if .Values.oauth2.redirectUrl }}
{{- .Values.oauth2.redirectUrl }}
{{- else if .Values.ingress.enabled }}
{{- printf "%s://%s/auth/callback" (include "admiral.ingress.scheme" .) .Values.ingress.host }}
{{- else }}
{{- printf "http://localhost:8080/auth/callback" }}
{{- end }}
{{- end }}

{{/*
Return the name of the secret containing OAuth2 credentials
*/}}
{{- define "admiral.oauth2.secretName" -}}
{{- if .Values.oauth2.existingSecret }}
{{- .Values.oauth2.existingSecret }}
{{- else }}
{{- printf "%s-oauth2" (include "admiral.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the Dex issuer URL. Must match what admiral.oauth2.issuer returns
so token validation succeeds.
*/}}
{{- define "admiral.dex.issuer" -}}
{{- if .Values.dex.config.issuer }}
{{- .Values.dex.config.issuer }}
{{- else if .Values.ingress.enabled }}
{{- printf "%s://%s/dex" (include "admiral.ingress.scheme" .) .Values.ingress.host }}
{{- else }}
{{- printf "http://%s:%s" (include "admiral.dex.fullname" .) (.Values.dex.service.port | toString) }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Migration helpers
   ======================================================================= */}}

{{/*
Return the migration image
*/}}
{{- define "admiral.migrations.image" -}}
{{- $repo := .Values.migrations.image.repository | default .Values.image.repository }}
{{- $tag := .Values.migrations.image.tag | default .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" $repo $tag }}
{{- end }}

{{/* =======================================================================
   Utility: tpl values render (lightweight alternative to bitnami common)
   ======================================================================= */}}

{{/*
Render a value that may contain template expressions.
Usage: {{ include "admiral.tplvalues.render" (dict "value" .Values.foo "context" $) }}
*/}}
{{- define "admiral.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context }}
{{- else }}
{{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end }}
