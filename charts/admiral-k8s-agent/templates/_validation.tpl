{{/*
Validate admiral-k8s-agent chart configuration.
Produces clear error messages when required settings are missing.
*/}}
{{- define "admiral-k8s-agent.validateValues" -}}

{{/* --- Admiral address --- */}}
{{- if not .Values.admiral.server }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  admiral.server is required.\n  Set it to Admiral's address (host:port):\n    --set admiral.server=admiral.example.com:443\n" }}
{{- end }}

{{/* --- Agent ID --- */}}
{{- if not (regexMatch "^agt-[0-9a-z]+$" (toString .Values.admiral.agentId)) }}
  {{- fail "\n\nADMIRAL K8S-AGENT CONFIGURATION ERROR:\n  admiral.agentId is required, as an agt- id.\n  Create the agent in Admiral and set its ID:\n    --set admiral.agentId=<agt- id>\n" }}
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
