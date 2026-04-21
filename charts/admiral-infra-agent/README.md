# admiral-infra-agent

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

Admiral infrastructure agent — runs Terraform/OpenTofu jobs on behalf of the Admiral control plane.

## Overview

The Admiral infra-agent is a long-lived worker that polls the Admiral control plane for Terraform / OpenTofu jobs, runs them in an isolated workspace, and reports results back. It exposes **no HTTP endpoints** — it is a pure client, so this chart deploys only a `Deployment` plus a few supporting resources (ServiceAccount, Secret, optional PDB / NetworkPolicy / HPA).

## Quick Start

```bash
helm install my-agent oci://ghcr.io/admiral-io/charts/admiral-infra-agent \
  --set agent.server=admiral.example.com:443 \
  --set agent.token=adms_...
```

For production, reference the runner token via a pre-created Secret:

```bash
kubectl create secret generic admiral-runner-token \
  --from-literal=runner-token=adms_...

helm install my-agent oci://ghcr.io/admiral-io/charts/admiral-infra-agent \
  --set agent.server=admiral.example.com:443 \
  --set agent.existingSecret=admiral-runner-token
```

## Cloud credentials

Terraform modules invoked by the agent pick up credentials from the pod's environment. Prefer **Workload Identity / IRSA** over static keys — set the appropriate annotation on `serviceAccount.annotations` and the cloud SDK will do the rest:

```yaml
serviceAccount:
  annotations:
    # EKS IRSA
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/admiral-infra-agent
    # GKE Workload Identity
    iam.gke.io/gcp-service-account: admiral-infra-agent@PROJECT.iam.gserviceaccount.com
```

Static credentials (AWS keys, Vault tokens, etc.) can be injected via `extraEnvVarsSecret`.

## Protecting active jobs

On `SIGTERM`, the agent stops claiming new jobs and drains in-flight Terraform runs before exiting. The chart sets `terminationGracePeriodSeconds: 300` by default; tune to the longest job you expect to run. For production, also enable the PodDisruptionBudget:

```yaml
replicaCount: 2
pdb:
  create: true
  minAvailable: 1
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod assignment |
| agent | object | `{"existingSecret":"","existingSecretKey":"runner-token","extraArgs":[],"insecure":false,"pollInterval":"5s","server":"","token":"","verbose":false,"workspaceDir":"/workspace"}` | Admiral infra-agent runtime configuration. Maps directly to the binary's flags and env vars (see `admiral-infra-agent run --help`). |
| agent.existingSecret | string | `""` | Name of an existing Secret containing the runner token. Takes precedence over `token`. The Secret must contain the key given by `existingSecretKey`. |
| agent.existingSecretKey | string | `"runner-token"` | Key within `existingSecret` that holds the runner token |
| agent.extraArgs | list | `[]` | Additional CLI args appended to the `run` subcommand |
| agent.insecure | bool | `false` | Skip TLS verification against the Admiral server (plaintext gRPC + HTTP). Only enable for local/dev clusters. Maps to --insecure. |
| agent.workspaceDir | string | `"/workspace"` | Root directory for per-job workspaces. The entrypoint pre-sets this to /workspace in the image; override if you mount a different writable path. Maps to ADMIRAL_WORKSPACE_DIR / --workspace-dir. |
| autoscaling | object | `{"enabled":false,"maxReplicas":10,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | Horizontal Pod Autoscaler configuration. CPU-based scaling works because Terraform runs are CPU-heavy, but consider KEDA with a queue-length metric for finer control. |
| autoscaling.enabled | bool | `false` | Enable HPA |
| autoscaling.maxReplicas | int | `10` | Maximum replicas |
| autoscaling.minReplicas | int | `1` | Minimum replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| extraEnvVars | list | `[]` | Extra environment variables for the agent container. Use this for cloud credentials that Terraform will pick up:   - name: AWS_REGION     value: us-east-1   - name: VAULT_ADDR     value: https://vault.example.com |
| extraEnvVarsCM | string | `""` | Name of a ConfigMap containing extra environment variables (envFrom) |
| extraEnvVarsSecret | string | `""` | Name of a Secret containing extra environment variables (envFrom). Common pattern: put AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or VAULT_TOKEN here. Prefer IRSA/Workload Identity via serviceAccount.annotations over static keys. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the agent container. |
| extraVolumes | list | `[]` | Extra volumes for the agent pod. Example: mount a Secret containing ~/.aws/credentials or a kubeconfig. |
| fullnameOverride | string | `""` | Override the full release name |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-infra-agent","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-infra-agent"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| initContainers | list | `[]` | Extra init containers for the agent pod |
| livenessProbe | object | `{}` | Liveness probe. The agent exposes no HTTP endpoint, so use an exec probe. Disabled by default because an unresponsive agent is still useful (it will finish its current job) and probe failures force-kill the process. |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"allowExternalEgress":true,"enabled":false,"extraEgress":[],"extraIngress":[]}` | Network Policy configuration. The agent only needs egress (DNS, Admiral control plane, cloud-provider APIs, Terraform module sources). Ingress is not required. |
| networkPolicy.allowExternalEgress | bool | `true` | Allow outbound connections to any destination. Set false to restrict to explicit destinations; then use `extraEgress` to whitelist Admiral, cloud APIs, git servers, etc. |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules |
| networkPolicy.extraIngress | list | `[]` | Additional ingress rules (usually none for a worker) |
| nodeSelector | object | `{}` | Node selector for pod assignment |
| pdb | object | `{"create":false,"maxUnavailable":"","minAvailable":1}` | Pod Disruption Budget. Recommended for production: protects active job runs from voluntary evictions (node drains, cluster upgrades). Note that with replicaCount=1 a PDB with minAvailable=1 will block node drains entirely — run at least 2 replicas, or use `maxUnavailable: 1` instead. |
| pdb.create | bool | `false` | Create a PDB resource |
| pdb.maxUnavailable | string | `""` | Maximum number of unavailable pods |
| pdb.minAvailable | int | `1` | Minimum number of available pods |
| podAnnotations | object | `{}` | Annotations to add to pods |
| podLabels | object | `{}` | Labels to add to pods. Set `azure.workload.identity/use: "true"` here when using Azure Workload Identity. |
| podSecurityContext | object | `{}` | Pod security context |
| readinessProbe | object | `{}` | Readiness probe. The agent is a poll-based client and has no concept of "not ready to serve traffic", so this is rarely needed. |
| replicaCount | int | `1` | Number of replicas for the infra-agent deployment. Each replica independently polls the Admiral control plane for jobs, so more replicas = more concurrent job capacity. |
| resources | object | `{}` | Resource requests/limits. Terraform runs are CPU- and I/O-heavy; size accordingly. |
| securityContext | object | `{}` | Container security context. The image already runs as uid/gid 65532 (nonroot). |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | Service account configuration. To grant the agent cloud-provider permissions without mounting long-lived credentials, set the corresponding annotation and the AWS/GCP SDK (invoked by Terraform) will pick up tokens automatically. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account.  EKS IRSA:   eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/admiral-infra-agent"  GKE Workload Identity:   iam.gke.io/gcp-service-account: "admiral-infra-agent@PROJECT.iam.gserviceaccount.com"  Azure Workload Identity (requires pod label azure.workload.identity/use: "true"):   azure.workload.identity/client-id: "CLIENT_ID" |
| serviceAccount.automount | bool | `true` | Automatically mount the service account token. Must stay true for EKS IRSA and GKE Workload Identity to work. |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| sidecars | list | `[]` | Extra sidecar containers for the agent pod |
| terminationGracePeriodSeconds | int | `300` | Grace period for the pod to finish its active Terraform/OpenTofu job on SIGTERM before Kubernetes force-kills it. The agent drains in-flight jobs before exiting; set this at least as long as your longest expected job. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| tools | object | `{"terraformVersion":"","tofuVersion":""}` | Terraform / OpenTofu versions installed at container startup by entrypoint.sh. Leave empty to use whatever the image was built with (usually `latest`). Accepts any version string tfenv/tofuenv recognises (e.g. "1.9.8"). |
| tools.terraformVersion | string | `""` | Terraform version (consumed via TERRAFORM_VERSION env var) |
| tools.tofuVersion | string | `""` | OpenTofu version (consumed via TOFU_VERSION env var) |
