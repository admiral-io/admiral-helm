{{/*
Validate admiral-infra-agent chart configuration.
Produces clear error messages when required settings are missing.
*/}}
{{- define "admiral-infra-agent.validateValues" -}}

{{/* --- Admiral address --- */}}
{{- if not .Values.admiral.server }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  admiral.server is required.\n  Set it to Admiral's address (host:port):\n    --set admiral.server=admiral.example.com:443\n" }}
{{- end }}

{{/* --- Service account --- */}}
{{- if not (regexMatch "^sa-[0-9a-z]+$" (toString .Values.admiral.serviceAccountId)) }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  admiral.serviceAccountId is required, as an sa- id.\n  admiral agent create prints it:\n    --set admiral.serviceAccountId=<sa- id>\n" }}
{{- end }}

{{/* --- TLS --- */}}
{{- if .Values.admiral.insecure }}
  {{- if .Values.admiral.ca.configMap }}
    {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  admiral.insecure and admiral.ca.configMap rule each other out.\n" }}
  {{- end }}
  {{- if not (regexMatch "^(localhost|127\\.[0-9.]+|\\[::1\\])(:[0-9]+)?$" .Values.admiral.server) }}
    {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  admiral.insecure connects only to a loopback address, not %q.\n  The agent's token would cross the network in clear.\n" .Values.admiral.server) }}
  {{- end }}
{{- end }}

{{/* --- Log format --- */}}
{{- if not (has .Values.logFormat (list "json" "text")) }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  logFormat must be json or text (got %q).\n" (toString .Values.logFormat)) }}
{{- end }}

{{/* --- Replicas --- */}}
{{- $replicas := int .Values.replicas }}
{{- if lt $replicas 1 }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  replicas must be at least 1 (got %v).\n" .Values.replicas) }}
{{- end }}
{{- if and (gt $replicas 1) (ne (include "admiral-infra-agent.leaderElect" .) "true") }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  replicas above 1 need leaderElect, or every pod claims work.\n" }}
{{- end }}
{{- if and (gt $replicas 1) .Values.persistence.enabled }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  persistence.enabled runs one replica: the pods would share one data directory.\n" }}
{{- end }}

{{/* --- Concurrency --- */}}
{{- $pc := int .Values.planConcurrency }}
{{- if or (lt $pc 1) (gt $pc 64) }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  planConcurrency must be between 1 and 64 (got %v).\n" .Values.planConcurrency) }}
{{- end }}
{{- $ac := int .Values.applyConcurrency }}
{{- if or (lt $ac 1) (gt $ac 64) }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  applyConcurrency must be between 1 and 64 (got %v).\n" .Values.applyConcurrency) }}
{{- end }}

{{/* --- Artifact size --- */}}
{{- $mib := int .Values.maxArtifactMiB }}
{{- if or (lt $mib 1) (gt $mib 512) }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  maxArtifactMiB must be between 1 and 512 (got %v).\n" .Values.maxArtifactMiB) }}
{{- end }}

{{/* --- Shutdown drain --- */}}
{{- if or (not .Values.shutdownDrain) (not (regexMatch "^([0-9]+h)?([0-9]+m)?([0-9]+s)?$" (toString .Values.shutdownDrain))) }}
  {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  shutdownDrain %q is not a duration this chart reads.\n  Write it in hours, minutes and seconds:\n    --set shutdownDrain=24h\n    --set shutdownDrain=1h30m\n" (toString .Values.shutdownDrain)) }}
{{- end }}

{{/* --- Config file. The agent refuses unknown keys at start, so catch them here. --- */}}
{{- range $k, $_ := .Values.config }}
  {{- if not (has $k (list "allowed_providers" "terraform" "hooks")) }}
    {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  config.%s is not a key the agent reads.\n  It reads allowed_providers, terraform and hooks.\n" $k) }}
  {{- end }}
{{- end }}
{{- range (.Values.config | default dict).hooks }}
  {{- $hook := . }}
  {{- range $k, $_ := . }}
    {{- if not (has $k (list "name" "phase" "command" "timeout")) }}
      {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  hook %q has %s, which is not a key the agent reads.\n  A hook has name, phase, command and timeout.\n" (toString $hook.name) $k) }}
    {{- end }}
  {{- end }}
  {{- if not (has .phase (list "pre_init" "post_plan" "post_apply")) }}
    {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  hook %q has phase %q.\n  A hook runs at pre_init, post_plan or post_apply.\n" (toString .name) (toString .phase)) }}
  {{- end }}
  {{- if not .command }}
    {{- fail (printf "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  hook %q has no command.\n" (toString .name)) }}
  {{- end }}
{{- end }}

{{- end }}
