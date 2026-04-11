# admiral

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.0.1](https://img.shields.io/badge/AppVersion-v0.0.1-informational?style=flat-square)

Open source platform orchestrator that bridges IaC and app deployments. Dependency graph across the full stack, environment-aware config, and deterministic rollbacks.

## Overview

Admiral requires three backing services: a **PostgreSQL** database, **S3-compatible object storage**, and an **OIDC provider**. This chart can deploy all three automatically for evaluation, or connect to your existing infrastructure for production.

| Component | Demo (built-in) | Production (external) |
|-----------|----------------|----------------------|
| Database | PostgreSQL subchart | Any PostgreSQL instance via `externalDatabase` |
| Object Storage | MinIO subchart | S3, GCS, or any S3-compatible store via `objectStorage` |
| OIDC | Dex (built-in templates) | Okta, Keycloak, or any OIDC provider via `oauth2` |

## Quick Start (Local / KinD)

```bash
# Create a KinD cluster with ingress support
curl -sL https://raw.githubusercontent.com/admiral-io/admiral-helm/master/kind/cluster.yaml | kind create cluster --name admiral --config=-

# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl rollout status deployment ingress-nginx-controller --namespace ingress-nginx --timeout=120s

# Add the Admiral Helm repository
helm repo add admiral https://charts.admiral.io
helm repo update admiral

# Install Admiral with demo dependencies
helm install admiral admiral/admiral -f https://raw.githubusercontent.com/admiral-io/admiral-helm/refs/heads/master/charts/admiral/demo-values.yaml

# Open in browser
open http://admiral.127.0.0.1.nip.io
```

If you have the repo cloned, you can also run `make dev` to do all of the above.

**Demo credentials:** `admin@example.com` / `shipitnow`

## Production Deployment

By default, all dependencies are **disabled**. You must configure external services or enable the built-in subcharts. The chart validates your configuration and provides clear error messages for missing settings.

See [`values/production-example.yaml`](../../values/production-example.yaml) for a complete production reference.

```bash
helm install admiral charts/admiral -f my-values.yaml
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.min.io | minio | 5.4.0 |
| oci://registry-1.docker.io/bitnamicharts | postgresql | 18.5.14 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod assignment |
| autoscaling | object | `{"enabled":false,"maxReplicas":100,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | Horizontal Pod Autoscaler configuration |
| autoscaling.enabled | bool | `false` | Enable HPA |
| autoscaling.maxReplicas | int | `100` | Maximum replicas |
| autoscaling.minReplicas | int | `1` | Minimum replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| buckets | object | `{"manifests":"manifests","revisions":"revisions"}` | Bucket names for admiral services |
| buckets.manifests | string | `"manifests"` | Bucket name for manifests |
| buckets.revisions | string | `"revisions"` | Bucket name for revisions |
| dex | object | `{"config":{"enablePasswordDB":true,"issuer":"","storage":{"config":{"inCluster":true},"type":"kubernetes"},"web":{"http":"0.0.0.0:5556"}},"enabled":false,"extraEnvVars":[],"extraVolumeMounts":[],"extraVolumes":[],"image":{"pullPolicy":"IfNotPresent","repository":"ghcr.io/dexidp/dex","tag":"latest"},"pdb":{"create":false,"maxUnavailable":"","minAvailable":""},"resources":{"requests":{"cpu":"50m","memory":"64Mi"}},"service":{"port":5556},"serviceAccount":{"annotations":{},"create":true}}` | Dex OIDC provider configuration. Deployed as built-in templates (not a subchart) for full config control. |
| dex.config | object | `{"enablePasswordDB":true,"issuer":"","storage":{"config":{"inCluster":true},"type":"kubernetes"},"web":{"http":"0.0.0.0:5556"}}` | Dex configuration. Rendered as a ConfigMap. staticClients and staticPasswords are auto-managed by chart templates. |
| dex.config.issuer | string | `""` | Issuer URL. Auto-computed from ingress.host if empty. |
| dex.enabled | bool | `false` | Deploy Dex. Set to false to use an external OIDC provider. |
| dex.extraEnvVars | list | `[]` | Extra environment variables for Dex pod |
| dex.extraVolumeMounts | list | `[]` | Extra volume mounts for Dex container |
| dex.extraVolumes | list | `[]` | Extra volumes for Dex pod |
| dex.image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/dexidp/dex","tag":"latest"}` | Dex container image |
| dex.pdb | object | `{"create":false,"maxUnavailable":"","minAvailable":""}` | Pod Disruption Budget for Dex |
| dex.pdb.create | bool | `false` | Create a PDB for Dex |
| dex.resources | object | `{"requests":{"cpu":"50m","memory":"64Mi"}}` | Resource requests/limits for Dex |
| dex.service | object | `{"port":5556}` | Dex service configuration |
| dex.serviceAccount | object | `{"annotations":{},"create":true}` | Dex service account |
| dex.serviceAccount.create | bool | `true` | Create a service account for Dex |
| externalDatabase | object | `{"database":"admiral","existingSecret":"","existingSecretPasswordKey":"db-password","host":"","password":"","port":5432,"sslMode":"disable","username":"admiral"}` | External database configuration (used when postgresql.enabled=false) Pattern: Bitnami Gitea/Airflow |
| externalDatabase.database | string | `"admiral"` | External database name |
| externalDatabase.existingSecret | string | `""` | Name of existing secret containing the database password |
| externalDatabase.existingSecretPasswordKey | string | `"db-password"` | Key within the existing secret containing the password |
| externalDatabase.host | string | `""` | External database host |
| externalDatabase.password | string | `""` | External database password (ignored if existingSecret is set) |
| externalDatabase.port | int | `5432` | External database port |
| externalDatabase.sslMode | string | `"disable"` | SSL mode for external database connection |
| externalDatabase.username | string | `"admiral"` | External database user |
| extraEnvVars | list | `[]` | Extra environment variables for the admiral server container |
| extraEnvVarsCM | string | `""` | Name of a ConfigMap containing extra environment variables |
| extraEnvVarsSecret | string | `""` | Name of a Secret containing extra environment variables |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the admiral server container |
| extraVolumes | list | `[]` | Extra volumes for the admiral server pod |
| fullnameOverride | string | `""` | Override the full release name |
| httpRoute | object | See values below | Gateway API HTTPRoute configuration. Requires Gateway API CRDs and a suitable controller installed in the cluster. |
| httpRoute.annotations | object | `{}` | HTTPRoute annotations |
| httpRoute.enabled | bool | `false` | Enable HTTPRoute |
| httpRoute.hostnames | list | `["admiral.example.com"]` | Hostnames for HTTP header matching |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Gateway parent references |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}]}]` | Routing rules and filters |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-server","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-server"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"host":"admiral.127.0.0.1.nip.io","tls":{"enabled":false,"secretName":""}}` | Ingress configuration |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.host | string | `"admiral.127.0.0.1.nip.io"` | Ingress hostname. Used for nip.io in KinD demo. |
| ingress.tls | object | `{"enabled":false,"secretName":""}` | TLS configuration |
| ingress.tls.enabled | bool | `false` | Enable TLS |
| ingress.tls.secretName | string | `""` | Name of existing TLS secret |
| initContainers | list | `[]` | Extra init containers for the admiral server pod |
| livenessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":10}` | Liveness probe configuration |
| metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false,"honorLabels":false,"interval":"30s","labels":{},"metricRelabelings":[],"namespace":"","relabelings":[],"scrapeTimeout":""}}` | Metrics and monitoring configuration |
| metrics.enabled | bool | `false` | Enable metrics exposure |
| metrics.serviceMonitor | object | `{"enabled":false,"honorLabels":false,"interval":"30s","labels":{},"metricRelabelings":[],"namespace":"","relabelings":[],"scrapeTimeout":""}` | Prometheus ServiceMonitor configuration |
| metrics.serviceMonitor.enabled | bool | `false` | Create a ServiceMonitor resource (requires Prometheus Operator) |
| metrics.serviceMonitor.honorLabels | bool | `false` | Honor labels from the target |
| metrics.serviceMonitor.interval | string | `"30s"` | Scrape interval |
| metrics.serviceMonitor.labels | object | `{}` | Additional labels for the ServiceMonitor |
| metrics.serviceMonitor.metricRelabelings | list | `[]` | Metric relabeling rules |
| metrics.serviceMonitor.namespace | string | `""` | Namespace for the ServiceMonitor (defaults to release namespace) |
| metrics.serviceMonitor.relabelings | list | `[]` | Relabeling rules |
| metrics.serviceMonitor.scrapeTimeout | string | `""` | Scrape timeout |
| migrations | object | `{"args":["--config","/etc/admiral/config.yaml","migrate","--force"],"image":{"repository":"","tag":""},"mode":"hook","resources":{}}` | Migration job configuration |
| migrations.args | list | `["--config","/etc/admiral/config.yaml","migrate","--force"]` | Migration args (passed to the container entrypoint /app/admiral-server) |
| migrations.image | object | `{"repository":"","tag":""}` | Migration container image (defaults to main app image if empty) |
| migrations.mode | string | `"hook"` | Migration mode: hook (pre-install/pre-upgrade), job (manual), skip (disabled) |
| migrations.resources | object | `{}` | Resource requests/limits for migration job |
| minio | object | See subchart values | MinIO subchart configuration (official minio/minio chart) |
| minio.buckets | list | `[{"name":"manifests","policy":"none","purge":false},{"name":"revisions","policy":"none","purge":false}]` | Buckets to create on startup |
| minio.enabled | bool | `false` | Deploy MinIO subchart. Set to false to use external object storage. |
| minio.existingSecret | string | `""` | Name of existing secret with rootUser and rootPassword keys |
| minio.mode | string | `"standalone"` | MinIO mode (standalone for demo, distributed for production) |
| minio.persistence | object | `{"enabled":true,"existingClaim":"","size":"1Gi","storageClass":""}` | Persistence configuration |
| minio.persistence.existingClaim | string | `""` | Use an existing PVC instead of creating one |
| minio.persistence.size | string | `"1Gi"` | PVC size for MinIO data |
| minio.persistence.storageClass | string | `""` | Storage class name. Leave empty for cluster default. |
| minio.replicas | int | `1` | Number of replicas (1 for standalone) |
| minio.resources | object | `{"requests":{"cpu":"100m","memory":"128Mi"}}` | Resource requests/limits |
| minio.rootPassword | string | `""` | MinIO root password (auto-generated if empty) |
| minio.rootUser | string | `"admiral"` | MinIO root user |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"allowExternal":true,"allowExternalEgress":true,"enabled":false,"extraEgress":[],"extraIngress":[]}` | Network Policy configuration (Bitnami convention) |
| networkPolicy.allowExternal | bool | `true` | Allow connections from outside the cluster |
| networkPolicy.allowExternalEgress | bool | `true` | Allow outbound connections to any destination |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules |
| networkPolicy.extraIngress | list | `[]` | Additional ingress rules |
| nodeSelector | object | `{}` | Node selector for pod assignment |
| oauth2 | object | `{"clientId":"admiral","clientSecret":"","clientSecretKey":"client-secret","demoPassword":"","existingSecret":"","issuer":"","name":"dex","redirectUrl":"","refreshTokenTTL":"12h","scopes":"openid,offline_access,email,profile","signingSecret":"","signingSecretKey":"signing-secret"}` | OAuth2/OIDC configuration for the admiral server |
| oauth2.clientId | string | `"admiral"` | OIDC client ID |
| oauth2.clientSecret | string | `""` | OAuth2 client secret (auto-generated in demo mode if empty) |
| oauth2.clientSecretKey | string | `"client-secret"` | Key in existingSecret for the client secret |
| oauth2.demoPassword | string | `""` | Demo user password for Dex (auto-generated if empty and dex.enabled) |
| oauth2.existingSecret | string | `""` | Name of existing secret containing OAuth2 credentials. Must contain keys specified by clientSecretKey and signingSecretKey. |
| oauth2.issuer | string | `""` | OIDC issuer URL. Auto-computed when dex.enabled=true. |
| oauth2.name | string | `"dex"` | Provider name (dex, keycloak, okta, etc.) |
| oauth2.redirectUrl | string | `""` | OAuth2 redirect URL. Auto-computed from ingress.host if empty. |
| oauth2.refreshTokenTTL | string | `"12h"` | Refresh token TTL |
| oauth2.scopes | string | `"openid,offline_access,email,profile"` | OIDC scopes (comma-separated) |
| oauth2.signingSecret | string | `""` | OAuth2 signing secret (auto-generated in demo mode if empty) |
| oauth2.signingSecretKey | string | `"signing-secret"` | Key in existingSecret for the signing secret |
| objectStorage | object | `{"gcs":{"existingSecret":"","projectId":"","secretKey":"credentials-json"},"s3":{"accessKeyKey":"rootUser","endpoint":"","existingSecret":"","region":"us-east-1","secretKeyKey":"rootPassword","useSSL":false},"type":"s3"}` | Object storage configuration |
| objectStorage.gcs | object | `{"existingSecret":"","projectId":"","secretKey":"credentials-json"}` | GCS configuration |
| objectStorage.gcs.existingSecret | string | `""` | Name of existing secret containing GCS service account key JSON |
| objectStorage.gcs.projectId | string | `""` | GCP project ID |
| objectStorage.gcs.secretKey | string | `"credentials-json"` | Key in secret for the credentials JSON |
| objectStorage.s3 | object | `{"accessKeyKey":"rootUser","endpoint":"","existingSecret":"","region":"us-east-1","secretKeyKey":"rootPassword","useSSL":false}` | S3/MinIO configuration |
| objectStorage.s3.accessKeyKey | string | `"rootUser"` | Key in secret for access key |
| objectStorage.s3.endpoint | string | `""` | S3 endpoint URL. Auto-computed from MinIO subchart when minio.enabled=true. |
| objectStorage.s3.existingSecret | string | `""` | Name of existing secret containing S3 credentials. Auto-computed from MinIO subchart when minio.enabled=true. |
| objectStorage.s3.region | string | `"us-east-1"` | S3 region |
| objectStorage.s3.secretKeyKey | string | `"rootPassword"` | Key in secret for secret key |
| objectStorage.s3.useSSL | bool | `false` | Use SSL for S3 connections |
| objectStorage.type | string | `"s3"` | Storage type: s3 (includes MinIO) or gcs |
| pdb | object | `{"create":false,"maxUnavailable":"","minAvailable":""}` | Pod Disruption Budget for the admiral server (Bitnami convention) |
| pdb.create | bool | `false` | Create a PDB resource |
| pdb.maxUnavailable | string | `""` | Maximum number of unavailable pods |
| pdb.minAvailable | string | `""` | Minimum number of available pods |
| podAnnotations | object | `{}` | Annotations to add to pods |
| podLabels | object | `{}` | Labels to add to pods |
| podSecurityContext | object | `{}` | Pod security context |
| postgresql | object | See subchart values | PostgreSQL subchart configuration |
| postgresql.auth.database | string | `"admiral"` | Database name |
| postgresql.auth.existingSecret | string | `""` | Name of existing secret containing the database password. Key must be `password` for the user and `postgres-password` for the admin. |
| postgresql.auth.password | string | `""` | Database password (auto-generated if empty) |
| postgresql.auth.username | string | `"admiral"` | Database user |
| postgresql.enabled | bool | `false` | Deploy PostgreSQL subchart. Set to false to use an external database. |
| postgresql.primary.persistence.enabled | bool | `true` | Enable persistence using PVC |
| postgresql.primary.persistence.existingClaim | string | `""` | Use an existing PVC instead of creating one |
| postgresql.primary.persistence.size | string | `"1Gi"` | PVC size for PostgreSQL data |
| postgresql.primary.persistence.storageClass | string | `""` | Storage class name. Leave empty for cluster default. |
| readinessProbe | object | `{"httpGet":{"path":"/readyz","port":"http"},"initialDelaySeconds":5,"periodSeconds":5}` | Readiness probe configuration |
| replicaCount | int | `1` | Number of replicas for the admiral server deployment |
| resources | object | `{}` | Resource requests/limits for the admiral server |
| securityContext | object | `{}` | Container security context |
| server | object | `{"accessLog":{"statusCodeFilters":[2,4,12,14]},"enablePprof":false,"logLevel":"error","port":8080,"stats":{"flushInterval":"1s","goRuntimeCollectionInterval":"5s","reporterType":"prometheus"},"timeouts":{"default":"15s"}}` | Admiral server configuration |
| server.accessLog | object | `{"statusCodeFilters":[2,4,12,14]}` | Access log configuration |
| server.accessLog.statusCodeFilters | list | `[2,4,12,14]` | gRPC status code filters |
| server.enablePprof | bool | `false` | Enable pprof profiling endpoint |
| server.logLevel | string | `"error"` | Log level (debug, info, warn, error) |
| server.port | int | `8080` | Server listen port |
| server.stats | object | `{"flushInterval":"1s","goRuntimeCollectionInterval":"5s","reporterType":"prometheus"}` | Stats/metrics configuration |
| server.stats.flushInterval | string | `"1s"` | Metrics flush interval |
| server.stats.goRuntimeCollectionInterval | string | `"5s"` | Go runtime stats collection interval |
| server.stats.reporterType | string | `"prometheus"` | Reporter type (prometheus) |
| server.timeouts | object | `{"default":"15s"}` | Server timeout configuration |
| server.timeouts.default | string | `"15s"` | Default request timeout |
| service | object | `{"port":80,"type":"ClusterIP"}` | Service configuration |
| service.port | int | `80` | Service port |
| service.type | string | `"ClusterIP"` | Service type |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | Service account configuration |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account. Use for Workload Identity (GKE) or IRSA (EKS):   iam.gke.io/gcp-service-account: "sa@project.iam.gserviceaccount.com"   eks.amazonaws.com/role-arn: "arn:aws:iam::123456789:role/my-role" |
| serviceAccount.automount | bool | `true` | Automatically mount the service account token |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| session | object | `{"cookie":{"domain":"","httpOnly":true,"name":"session","persist":true,"sameSite":"lax","secure":false},"idleTimeout":"30m","lifetime":"24h"}` | Session management configuration |
| session.cookie | object | `{"domain":"","httpOnly":true,"name":"session","persist":true,"sameSite":"lax","secure":false}` | Cookie settings |
| session.cookie.domain | string | `""` | Cookie domain (empty = auto) |
| session.cookie.httpOnly | bool | `true` | HTTP-only flag |
| session.cookie.name | string | `"session"` | Cookie name |
| session.cookie.persist | bool | `true` | Persist sessions across browser restarts |
| session.cookie.sameSite | string | `"lax"` | SameSite attribute (strict, lax, none) |
| session.cookie.secure | bool | `false` | Secure flag (set to true when using TLS) |
| session.idleTimeout | string | `"30m"` | Session idle timeout |
| session.lifetime | string | `"24h"` | Session lifetime |
| sidecars | list | `[]` | Extra sidecar containers for the admiral server pod |
| tolerations | list | `[]` | Tolerations for pod assignment |
