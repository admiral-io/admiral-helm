{{/*
Validate admiral-k8s-agent chart configuration.
Produces clear error messages when required settings are missing.
*/}}
{{- define "admiral-k8s-agent.validateValues" -}}

{{/* --- Admiral address --- */}}
{{- if not .Values.admiral.server }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  admiral.server is required.\n  Set it to Admiral's address (host:port):\n    --set admiral.server=admiral.example.com:443\n" }}
{{- end }}

{{/* --- Service account --- */}}
{{- if not (regexMatch "^sa-[0-9a-z]+$" (toString .Values.admiral.serviceAccountId)) }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  admiral.serviceAccountId is required, as an sa- id.\n  admiral agent create prints it:\n    --set admiral.serviceAccountId=<sa- id>\n" }}
{{- end }}

{{/* --- TLS --- */}}
{{- if and .Values.admiral.insecure (include "admiral-k8s-agent.caConfigMap" .) }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  admiral.insecure and admiral.ca.configMap rule each other out.\n" }}
{{- end }}

{{/* --- Log format --- */}}
{{- $logFormat := include "admiral-k8s-agent.logFormat" . }}
{{- if not (has $logFormat (list "json" "text")) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  logFormat must be json or text (got %q).\n" $logFormat) }}
{{- end }}

{{/* --- Replicas --- */}}
{{- $replicas := int .Values.replicas }}
{{- if and (hasKey .Values "replicas") (lt $replicas 1) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  replicas must be at least 1 (got %v).\n" .Values.replicas) }}
{{- end }}
{{- if and (gt $replicas 1) (ne (include "admiral-k8s-agent.leaderElect" .) "true") }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  replicas above 1 need leaderElect, or every pod claims work.\n" }}
{{- end }}

{{/* --- Plan concurrency --- */}}
{{- $pc := int .Values.planConcurrency }}
{{- if or (lt $pc 1) (gt $pc 64) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  planConcurrency must be between 1 and 64 (got %v).\n" .Values.planConcurrency) }}
{{- end }}

{{/* --- Apply concurrency --- */}}
{{- $ac := int .Values.applyConcurrency }}
{{- if or (lt $ac 1) (gt $ac 64) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  applyConcurrency must be between 1 and 64 (got %v).\n" .Values.applyConcurrency) }}
{{- end }}

{{/* --- Apply health timeout --- */}}
{{- if or (not .Values.applyHealthTimeout) (not (regexMatch "^([0-9]+h)?([0-9]+m)?([0-9]+s)?$" (toString .Values.applyHealthTimeout))) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  applyHealthTimeout %q is not a duration this chart reads.\n  Write it in hours, minutes and seconds:\n    --set applyHealthTimeout=5m\n" (toString .Values.applyHealthTimeout)) }}
{{- end }}

{{/* --- Shutdown drain --- */}}
{{- if not (regexMatch "^([0-9]+h)?([0-9]+m)?([0-9]+s)?$" (toString .Values.shutdownDrain)) }}
  {{- fail (printf "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  shutdownDrain %q is not a duration this chart reads.\n  Write it in hours, minutes and seconds:\n    --set shutdownDrain=25s\n    --set shutdownDrain=1m30s\n" (toString .Values.shutdownDrain)) }}
{{- end }}
{{- if not .Values.shutdownDrain }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  shutdownDrain is required, for example:\n    --set shutdownDrain=25s\n" }}
{{- end }}

{{- end }}
