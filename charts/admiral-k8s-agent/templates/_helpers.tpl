{{/*
Expand the name of the chart.
*/}}
{{- define "admiral-k8s-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "admiral-k8s-agent.fullname" -}}
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
{{- define "admiral-k8s-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "admiral-k8s-agent.labels" -}}
helm.sh/chart: {{ include "admiral-k8s-agent.chart" . }}
{{ include "admiral-k8s-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: k8s-agent
{{- end }}

{{/*
Selector labels
*/}}
{{- define "admiral-k8s-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "admiral-k8s-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "admiral-k8s-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "admiral-k8s-agent.fullname" .) .Values.serviceAccount.name }}
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
{{- define "admiral-k8s-agent.tokenSecretName" -}}
{{- if .Values.agent.existingSecret }}
{{- .Values.agent.existingSecret }}
{{- else }}
{{- printf "%s-token" (include "admiral-k8s-agent.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the key within the token secret that holds the runner token.
*/}}
{{- define "admiral-k8s-agent.tokenSecretKey" -}}
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
Usage: {{ include "admiral-k8s-agent.tplvalues.render" (dict "value" .Values.foo "context" $) }}
*/}}
{{- define "admiral-k8s-agent.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context }}
{{- else }}
{{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end }}
