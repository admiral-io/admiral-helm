# Chart Conventions

This document defines the conventions that **all** Admiral Helm charts must follow.
Consistency across charts reduces cognitive load for both contributors and consumers.

## Values Naming

All charts use [Bitnami-style](https://github.com/bitnami/charts/blob/main/CONTRIBUTING.md) naming for common knobs.

### Image

```yaml
image:
  repository: ghcr.io/admiral-io/<name>
  pullPolicy: IfNotPresent
  tag: ""            # defaults to Chart.appVersion

imagePullSecrets: []
```

### Pod Configuration

```yaml
replicaCount: 1

podAnnotations: {}
podLabels: {}
podSecurityContext: {}
securityContext: {}

nodeSelector: {}
tolerations: []
affinity: {}
topologySpreadConstraints: []
```

### ServiceAccount

```yaml
serviceAccount:
  create: true
  automount: true
  annotations: {}    # Workload Identity / IRSA annotations go here
  name: ""
```

### Naming Overrides

```yaml
nameOverride: ""
fullnameOverride: ""
```

### Extensibility

Use the `extra*` prefix for escape-hatch fields. **Never** use bare names like
`volumes` or `volumeMounts`; always prefix with `extra`.

```yaml
extraEnvVars: []
extraEnvVarsCM: ""
extraEnvVarsSecret: ""
extraVolumes: []
extraVolumeMounts: []
initContainers: []
sidecars: []
```

All `extra*` fields that accept template expressions must be rendered through the
chart's `tplvalues.render` helper.

### Service

```yaml
service:
  type: ClusterIP
  port: 80
```

### Autoscaling

```yaml
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Pod Disruption Budget

```yaml
pdb:
  create: false
  minAvailable: ""
  maxUnavailable: ""
```

### Network Policy

```yaml
networkPolicy:
  enabled: false
  allowExternalEgress: true
  extraEgress: []
  extraIngress: []
```

Charts that accept inbound traffic add `allowExternal: true` (admiral server).
Agent charts that are egress-only omit `allowExternal`.

### Resources & Probes

```yaml
resources: {}

livenessProbe: {}   # or chart-specific defaults
readinessProbe: {}  # or chart-specific defaults
```

### Ingress & Gateway API

Charts that expose HTTP endpoints support both Ingress and HTTPRoute:

```yaml
ingress:
  enabled: false
  className: ""
  host: ""
  annotations: {}
  tls:
    enabled: false
    secretName: ""

httpRoute:
  enabled: false
  annotations: {}
  parentRefs: []
  hostnames: []
  rules: []
```

## Template Requirements

Every chart **must** include the following templates:

| File | Purpose |
|------|---------|
| `_helpers.tpl` | Naming, labels, selector labels, service account name, `tplvalues.render` |
| `_validation.tpl` | `fail` with clear error messages for missing required config |
| `NOTES.txt` | Post-install instructions |

### Helper Functions

Each chart defines helpers prefixed with the chart name to avoid collisions when
used as a subchart:

```
<chart-name>.name
<chart-name>.fullname
<chart-name>.chart
<chart-name>.labels
<chart-name>.selectorLabels
<chart-name>.serviceAccountName
<chart-name>.tplvalues.render
```

## Labels

All resources **must** include the standard Kubernetes labels via the chart's
`labels` helper:

```yaml
helm.sh/chart: <chart>-<version>
app.kubernetes.io/name: <name>
app.kubernetes.io/instance: <release>
app.kubernetes.io/version: <appVersion>
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/component: <component>   # REQUIRED
```

The `component` label is **mandatory** and must identify the workload:

| Chart | Component |
|-------|-----------|
| admiral (server) | `server` |
| admiral (dex) | `dex` |
| admiral (migrations) | `migrations` |
| admiral-infra-agent | `infra-agent` |
| admiral-k8s-agent | `k8s-agent` |

## Validation

Charts must validate required configuration at render time using `fail` in
`_validation.tpl`. Error messages must:

1. Name the chart clearly (e.g., `ADMIRAL CONFIGURATION ERROR`)
2. Explain what is missing
3. List the possible solutions with example `--set` flags
4. Reference the demo values file when applicable

## Secret Management

Follow this precedence for credentials:

1. `existingSecret` — user provides a pre-created Secret (production)
2. Inline value (e.g., `password`) — chart generates a Secret (dev/demo)
3. Workload Identity / IRSA — no secret needed, configured via `serviceAccount.annotations`

Charts must support all three paths. When using `existingSecret`, the key within
the secret must be configurable (e.g., `existingSecretPasswordKey`).

## Cloud Provider Authentication

For services that access cloud APIs (GCS, S3, etc.), charts must support:

1. **Workload Identity / IRSA** (recommended) — configured via `serviceAccount.annotations`,
   no credentials mounted. The credential fields in the ConfigMap/env are omitted entirely.
2. **Static credentials** — provided via `existingSecret`, mounted as env vars or files.

Validation must **not** fail when neither credentials nor secret is provided, as
Workload Identity requires neither. If you want to warn, use `NOTES.txt`.

## ConfigMap & Configuration

Charts that produce application configuration files should:

1. Render all non-secret values directly through Helm templates
2. Inject secrets via environment variables using `secretKeyRef`
3. Support `existingConfigMap` to let consumers provide their own config entirely
4. Use a checksum annotation to trigger rollouts on config changes:
   ```yaml
   checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
   ```

## Testing

Every chart must include:

- `templates/tests/test-connection.yaml` — basic pod connectivity test
- Valid `values.schema.json` — JSON Schema for IDE validation and `helm lint`

## Documentation

- Every `values.yaml` entry must have a `# --` helm-docs comment
- Run `helm-docs` before committing (CI enforces this)
- Chart.yaml must include `appVersion` tracking the application release
