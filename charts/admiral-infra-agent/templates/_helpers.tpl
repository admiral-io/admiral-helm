{{/*
Expand the name of the chart.
*/}}
{{- define "admiral-infra-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "admiral-infra-agent.fullname" -}}
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
{{- define "admiral-infra-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "admiral-infra-agent.labels" -}}
helm.sh/chart: {{ include "admiral-infra-agent.chart" . }}
{{ include "admiral-infra-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: infra-agent
{{- end }}

{{/*
Selector labels
*/}}
{{- define "admiral-infra-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "admiral-infra-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "admiral-infra-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "admiral-infra-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Runner token secret helpers
   ======================================================================= */}}

{{/*
Return the name of the secret holding the runner token.
*/}}
{{- define "admiral-infra-agent.tokenSecretName" -}}
{{- if .Values.agent.existingSecret }}
{{- .Values.agent.existingSecret }}
{{- else }}
{{- printf "%s-token" (include "admiral-infra-agent.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the key within the token secret that holds the runner token.
*/}}
{{- define "admiral-infra-agent.tokenSecretKey" -}}
{{- if .Values.agent.existingSecret }}
{{- .Values.agent.existingSecretKey | default "runner-token" }}
{{- else }}
{{- printf "runner-token" }}
{{- end }}
{{- end }}

{{/* =======================================================================
   Utility: tpl values render
   ======================================================================= */}}

{{/*
Render a value that may contain template expressions.
Usage: {{ include "admiral-infra-agent.tplvalues.render" (dict "value" .Values.foo "context" $) }}
*/}}
{{- define "admiral-infra-agent.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context }}
{{- else }}
{{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end }}
