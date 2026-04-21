{{/*
Validate admiral-infra-agent chart configuration.
Produces clear error messages when required settings are missing.
*/}}
{{- define "admiral-infra-agent.validateValues" -}}

{{/* --- Admiral server address --- */}}
{{- if not .Values.agent.server }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  agent.server is required.\n  Set it to the Admiral control plane address (host:port):\n    --set agent.server=admiral.example.com:443\n" }}
{{- end }}

{{/* --- Runner token --- */}}
{{- if and (not .Values.agent.existingSecret) (not .Values.agent.token) }}
  {{- fail "\n\nADMIRAL INFRA-AGENT CONFIGURATION ERROR:\n  A runner token is required. Either:\n    1. Provide an existing secret:  agent.existingSecret=<secret-name>\n    2. Set the token inline:        agent.token=adms_...\n\n  Provision the token via the Admiral server UI or API.\n" }}
{{- end }}

{{- end }}
