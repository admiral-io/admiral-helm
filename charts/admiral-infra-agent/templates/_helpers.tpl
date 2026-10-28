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
{{- with include "admiral-infra-agent.version" . }}
app.kubernetes.io/version: {{ . | quote }}
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

{{/*
Name for the cluster-scoped objects. It carries the release namespace so two
releases with the same name in different namespaces do not collide.
*/}}
{{- define "admiral-infra-agent.clusterScopedName" -}}
{{- printf "%s-%s" (include "admiral-infra-agent.fullname" .) .Release.Namespace }}
{{- end }}

{{/*
shutdownDrain in whole seconds. _validation.tpl has already checked its form.
*/}}
{{- define "admiral-infra-agent.shutdownDrainSeconds" -}}
{{- $total := 0 }}
{{- range regexFindAll "[0-9]+[hms]" (toString .Values.shutdownDrain) -1 }}
{{- $n := atoi (regexReplaceAll "[hms]$" . "") }}
{{- if hasSuffix "h" . }}{{- $n = mul $n 3600 }}{{- else if hasSuffix "m" . }}{{- $n = mul $n 60 }}{{- end }}
{{- $total = add $total $n }}
{{- end }}
{{- $total }}
{{- end }}

{{/*
The data volume's claim: the existing one, the chart's, or empty for an
emptyDir.
*/}}
{{- define "admiral-infra-agent.claimName" -}}
{{- if .Values.persistence.enabled }}
{{- .Values.persistence.existingClaim | default (printf "%s-data" (include "admiral-infra-agent.fullname" .)) }}
{{- end }}
{{- end }}

{{/*
"true" or "false". A missing leaderElect means true; default cannot tell a
missing value from false.
*/}}
{{- define "admiral-infra-agent.leaderElect" -}}
{{- if hasKey .Values "leaderElect" }}{{ .Values.leaderElect }}{{ else }}true{{ end }}
{{- end }}

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

{{/*
The version that runs: the image tag, defaulting to the chart appVersion.
The image and the version label both read it, so they agree.
*/}}
{{- define "admiral-infra-agent.version" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end }}
