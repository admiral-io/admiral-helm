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

{{/*
Name for objects outside the release namespace: the ClusterRoles, the
ClusterRoleBindings, and the Roles in rbac.namespaces. It carries the release
namespace so two releases with the same name in different namespaces do not
collide.
*/}}
{{- define "admiral-k8s-agent.clusterScopedName" -}}
{{- printf "%s-%s" (include "admiral-k8s-agent.fullname" .) .Release.Namespace }}
{{- end }}

{{/*
RBAC rules for the ClusterRole, or for each Role when rbac.namespaces is set.
*/}}
{{- define "admiral-k8s-agent.rbacRules" -}}
{{- if .Values.rbac.rules }}
{{- toYaml .Values.rbac.rules }}
{{- else -}}
# Every kind is named. A wildcard resource also matches subresources such as
# serviceaccounts/token, pods/exec and nodes/proxy, which amount to
# cluster-admin. The same list as the agent's manifests/rbac/role.yaml.
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "patch", "create"]
- apiGroups: [""]
  resources:
    - configmaps
    - limitranges
    - persistentvolumeclaims
    - persistentvolumes
    - resourcequotas
    - secrets
    - serviceaccounts
    - services
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["daemonsets", "deployments", "statefulsets"]
  verbs: ["get", "patch", "create", "delete"]
# Watch lets an apply see a hook Job or Pod finish even when it is deleted
# at once, as a Job with ttlSecondsAfterFinished: 0 is. List lets a wait say
# why a workload's pods are not ready.
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "patch", "create", "delete", "watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "patch", "create", "delete", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingressclasses", "ingresses", "networkpolicies"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings", "clusterroles", "rolebindings", "roles"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["scheduling.k8s.io"]
  resources: ["priorityclasses"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "patch", "create", "delete"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "patch", "create", "delete"]
{{- end }}
{{- end }}

{{/*
shutdownDrain in whole seconds. _validation.tpl has already checked its form.
*/}}
{{- define "admiral-k8s-agent.shutdownDrainSeconds" -}}
{{- $total := 0 }}
{{- range regexFindAll "[0-9]+[hms]" (toString .Values.shutdownDrain) -1 }}
{{- $n := atoi (regexReplaceAll "[hms]$" . "") }}
{{- if hasSuffix "h" . }}{{- $n = mul $n 3600 }}{{- else if hasSuffix "m" . }}{{- $n = mul $n 60 }}{{- end }}
{{- $total = add $total $n }}
{{- end }}
{{- $total }}
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

{{/*
Values added after a release was installed are missing under
`helm upgrade --reuse-values`, so each falls back to its default here.
*/}}
{{- define "admiral-k8s-agent.logFormat" -}}
{{- .Values.logFormat | default "json" }}
{{- end }}

{{- define "admiral-k8s-agent.replicas" -}}
{{- .Values.replicas | default 1 }}
{{- end }}

{{/*
"true" or "false". A missing leaderElect means true; default cannot tell a
missing value from false.
*/}}
{{- define "admiral-k8s-agent.leaderElect" -}}
{{- if hasKey .Values "leaderElect" }}{{ .Values.leaderElect }}{{ else }}true{{ end }}
{{- end }}

{{- define "admiral-k8s-agent.caConfigMap" -}}
{{- (.Values.admiral.ca | default dict).configMap | default "" }}
{{- end }}

{{- define "admiral-k8s-agent.caKey" -}}
{{- (.Values.admiral.ca | default dict).key | default "ca.crt" }}
{{- end }}
