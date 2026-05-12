# admiral-k8s-agent

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

Admiral Kubernetes agent — connects a cluster to the Admiral control plane.

## Overview

The Admiral k8s-agent is a long-lived worker that polls the Admiral control plane for work, inspects the local Kubernetes cluster on its behalf, and reports results back. It exposes **no HTTP endpoints** — it is a pure client, so this chart deploys only a `Deployment` plus a few supporting resources (ServiceAccount, ClusterRole/Binding, Secret, optional PDB / NetworkPolicy / HPA).

## Quick Start

```bash
helm install my-agent oci://ghcr.io/admiral-io/charts/admiral-k8s-agent \
  --set agent.server=admiral.example.com:443 \
  --set agent.token=adms_...
```

For production, reference the runner token via a pre-created Secret:

```bash
kubectl create secret generic admiral-runner-token \
  --from-literal=runner-token=adms_...

helm install my-agent oci://ghcr.io/admiral-io/charts/admiral-k8s-agent \
  --set agent.server=admiral.example.com:443 \
  --set agent.existingSecret=admiral-runner-token
```

## Cluster RBAC

The agent needs cluster-wide read access to introspect workloads, networking, and discovery resources. The chart creates a `ClusterRole` and `ClusterRoleBinding` by default. To tighten or extend the default permission set, override `rbac.rules` wholesale — the list is **not** merged with the defaults:

```yaml
rbac:
  create: true
  rules:
    - apiGroups: [""]
      resources: ["pods", "namespaces"]
      verbs: ["get", "list", "watch"]
```

To bind the agent to a ClusterRole you manage out-of-band, set `rbac.create: false` and create the binding yourself.

## Protecting active work

On `SIGTERM`, the agent stops claiming new work and drains in-flight operations before exiting. The chart sets `terminationGracePeriodSeconds: 60` by default. For production, also enable the PodDisruptionBudget:

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
| agent | object | `{"existingSecret":"","existingSecretKey":"runner-token","extraArgs":[],"insecure":false,"pollInterval":"5s","server":"","token":"","verbose":false}` | Admiral k8s-agent runtime configuration. Maps directly to the binary's flags and env vars (see `admiral-k8s-agent run --help`). |
| agent.existingSecret | string | `""` | Name of an existing Secret containing the runner token. Takes precedence over `token`. The Secret must contain the key given by `existingSecretKey`. |
| agent.existingSecretKey | string | `"runner-token"` | Key within `existingSecret` that holds the runner token |
| agent.extraArgs | list | `[]` | Additional CLI args appended to the `run` subcommand |
| agent.insecure | bool | `false` | Skip TLS verification against the Admiral server (plaintext gRPC + HTTP). Only enable for local/dev clusters. Maps to --insecure. |
| autoscaling | object | `{"enabled":false,"maxReplicas":10,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | Horizontal Pod Autoscaler configuration. |
| autoscaling.enabled | bool | `false` | Enable HPA |
| autoscaling.maxReplicas | int | `10` | Maximum replicas |
| autoscaling.minReplicas | int | `1` | Minimum replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| extraEnvVars | list | `[]` | Extra environment variables for the agent container.   - name: HTTPS_PROXY     value: http://proxy.example.com:3128 |
| extraEnvVarsCM | string | `""` | Name of a ConfigMap containing extra environment variables (envFrom) |
| extraEnvVarsSecret | string | `""` | Name of a Secret containing extra environment variables (envFrom). Prefer IRSA/Workload Identity via serviceAccount.annotations over static keys. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the agent container. |
| extraVolumes | list | `[]` | Extra volumes for the agent pod. |
| fullnameOverride | string | `""` | Override the full release name |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-k8s-agent","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-k8s-agent"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| initContainers | list | `[]` | Extra init containers for the agent pod |
| livenessProbe | object | `{}` | Liveness probe. The agent exposes no HTTP endpoint, so use an exec probe. Disabled by default because an unresponsive agent is still useful (it will finish its current work) and probe failures force-kill the process. |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"allowExternalEgress":true,"enabled":false,"extraEgress":[],"extraIngress":[]}` | Network Policy configuration. The agent only needs egress (DNS, Admiral control plane, Kubernetes API). Ingress is not required. |
| networkPolicy.allowExternalEgress | bool | `true` | Allow outbound connections to any destination. Set false to restrict to explicit destinations; then use `extraEgress` to whitelist Admiral, the Kubernetes API server, etc. |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules |
| networkPolicy.extraIngress | list | `[]` | Additional ingress rules (usually none for a worker) |
| nodeSelector | object | `{}` | Node selector for pod assignment |
| pdb | object | `{"create":false,"maxUnavailable":"","minAvailable":1}` | Pod Disruption Budget. Recommended for production: protects active operations from voluntary evictions (node drains, cluster upgrades). Note that with replicaCount=1 a PDB with minAvailable=1 will block node drains entirely — run at least 2 replicas, or use `maxUnavailable: 1` instead. |
| pdb.create | bool | `false` | Create a PDB resource |
| pdb.maxUnavailable | string | `""` | Maximum number of unavailable pods |
| pdb.minAvailable | int | `1` | Minimum number of available pods |
| podAnnotations | object | `{}` | Annotations to add to pods |
| podLabels | object | `{}` | Labels to add to pods. Set `azure.workload.identity/use: "true"` here when using Azure Workload Identity. |
| podSecurityContext | object | `{}` | Pod security context |
| rbac | object | `{"create":true,"rules":[{"apiGroups":[""],"resources":["configmaps","endpoints","events","namespaces","nodes","persistentvolumeclaims","persistentvolumes","pods","pods/log","replicationcontrollers","resourcequotas","secrets","serviceaccounts","services"],"verbs":["get","list","watch"]},{"apiGroups":["apps"],"resources":["daemonsets","deployments","replicasets","statefulsets"],"verbs":["get","list","watch"]},{"apiGroups":["batch"],"resources":["cronjobs","jobs"],"verbs":["get","list","watch"]},{"apiGroups":["networking.k8s.io"],"resources":["ingresses","ingressclasses","networkpolicies"],"verbs":["get","list","watch"]},{"apiGroups":["gateway.networking.k8s.io"],"resources":["gateways","gatewayclasses","httproutes"],"verbs":["get","list","watch"]},{"apiGroups":["policy"],"resources":["poddisruptionbudgets"],"verbs":["get","list","watch"]},{"apiGroups":["autoscaling"],"resources":["horizontalpodautoscalers"],"verbs":["get","list","watch"]},{"apiGroups":["storage.k8s.io"],"resources":["storageclasses","volumeattachments"],"verbs":["get","list","watch"]},{"apiGroups":["rbac.authorization.k8s.io"],"resources":["clusterroles","clusterrolebindings","roles","rolebindings"],"verbs":["get","list","watch"]},{"apiGroups":["apiextensions.k8s.io"],"resources":["customresourcedefinitions"],"verbs":["get","list","watch"]}]}` | Cluster RBAC for the agent. The k8s-agent inspects cluster state on behalf of the Admiral control plane, so it needs cluster-wide read access to a broad set of resources by default. Override `rules` to tighten or extend permissions. |
| rbac.create | bool | `true` | Create the ClusterRole and ClusterRoleBinding |
| rbac.rules | list | `[{"apiGroups":[""],"resources":["configmaps","endpoints","events","namespaces","nodes","persistentvolumeclaims","persistentvolumes","pods","pods/log","replicationcontrollers","resourcequotas","secrets","serviceaccounts","services"],"verbs":["get","list","watch"]},{"apiGroups":["apps"],"resources":["daemonsets","deployments","replicasets","statefulsets"],"verbs":["get","list","watch"]},{"apiGroups":["batch"],"resources":["cronjobs","jobs"],"verbs":["get","list","watch"]},{"apiGroups":["networking.k8s.io"],"resources":["ingresses","ingressclasses","networkpolicies"],"verbs":["get","list","watch"]},{"apiGroups":["gateway.networking.k8s.io"],"resources":["gateways","gatewayclasses","httproutes"],"verbs":["get","list","watch"]},{"apiGroups":["policy"],"resources":["poddisruptionbudgets"],"verbs":["get","list","watch"]},{"apiGroups":["autoscaling"],"resources":["horizontalpodautoscalers"],"verbs":["get","list","watch"]},{"apiGroups":["storage.k8s.io"],"resources":["storageclasses","volumeattachments"],"verbs":["get","list","watch"]},{"apiGroups":["rbac.authorization.k8s.io"],"resources":["clusterroles","clusterrolebindings","roles","rolebindings"],"verbs":["get","list","watch"]},{"apiGroups":["apiextensions.k8s.io"],"resources":["customresourcedefinitions"],"verbs":["get","list","watch"]}]` | Rules for the ClusterRole. Default: cluster-wide read-only on the most common workload, networking, and discovery resources. Replace entirely to customise — values are NOT merged with the defaults. |
| readinessProbe | object | `{}` | Readiness probe. The agent is a poll-based client and has no concept of "not ready to serve traffic", so this is rarely needed. |
| replicaCount | int | `1` | Number of replicas for the k8s-agent deployment. Each replica independently polls the Admiral control plane, so more replicas = more concurrent capacity. |
| resources | object | `{}` | Resource requests/limits. |
| securityContext | object | `{}` | Container security context. The image already runs as uid/gid 65532 (nonroot). |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | Service account configuration. To grant the agent cloud-provider permissions without mounting long-lived credentials, set the corresponding annotation and the cloud SDK will pick up tokens automatically. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account.  EKS IRSA:   eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/admiral-k8s-agent"  GKE Workload Identity:   iam.gke.io/gcp-service-account: "admiral-k8s-agent@PROJECT.iam.gserviceaccount.com"  Azure Workload Identity (requires pod label azure.workload.identity/use: "true"):   azure.workload.identity/client-id: "CLIENT_ID" |
| serviceAccount.automount | bool | `true` | Automatically mount the service account token. Must stay true for EKS IRSA and GKE Workload Identity to work. |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| sidecars | list | `[]` | Extra sidecar containers for the agent pod |
| terminationGracePeriodSeconds | int | `60` | Grace period for the pod to finish in-flight work on SIGTERM before Kubernetes force-kills it. The agent drains active operations before exiting. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| topologySpreadConstraints | list | `[]` | Topology spread constraints for pod distribution across zones/nodes |
