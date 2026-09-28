# admiral-k8s-agent

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

Connects a Kubernetes cluster to Admiral.

## What it installs

The [Admiral Kubernetes Agent](https://github.com/admiral-io/admiral-k8s-agent) runs in your cluster, takes work from Admiral, and reports what it finds. It plans changes by server-side apply dry run and reports the cluster's version, API groups and what it may write. It opens outbound connections only.

The chart installs one agent:

- a Deployment with a single replica
- a ServiceAccount, whose projected token (audience `admiral.audience`) is the agent's identity to Admiral. The agent holds no long-lived credential.
- RBAC for what the agent may plan, and a binding to `system:service-account-issuer-discovery` so it can read the cluster's token signing keys
- optionally, an egress-only NetworkPolicy

In Admiral, register the cluster and note its cluster ID, then register each agent by its namespace and service account. Several agents in one cluster share the cluster's ID.

```bash
helm repo add admiral https://charts.admiral.io
helm repo update
```

The chart is also published as `oci://ghcr.io/admiral-io/admiral-helm/admiral-k8s-agent`.

## One agent for the cluster

The default. The agent may plan in every namespace through one ClusterRole.

```bash
helm install admiral-k8s-agent admiral/admiral-k8s-agent \
  --namespace admiral-system --create-namespace \
  --set admiral.server=admiral.example.com:443 \
  --set admiral.clusterId=<cluster id> \
  --set serviceAccount.name=admiral-k8s-agent
```

## Several agents in one cluster

To keep workloads apart, run one release per agent, each in its own namespace and limited with `rbac.namespaces` to the namespaces it may plan in. The chart then creates a Role in each of those namespaces instead of granting every namespace. In Admiral, grant each agent only to the environments that should use it. See [layouts](https://github.com/admiral-io/admiral-k8s-agent/blob/master/docs/layouts.md) for the full walkthrough.

```bash
helm install agent-payments admiral/admiral-k8s-agent \
  --namespace admiral-payments --create-namespace \
  --set admiral.server=admiral.example.com:443 \
  --set admiral.clusterId=<cluster id> \
  --set serviceAccount.name=admiral-k8s-agent \
  --set 'rbac.namespaces={payments-prod}'
```

Every cluster-scoped object the chart creates is named after both the release and its namespace, so releases do not collide.

## Enrollment

If Admiral cannot fetch your cluster's service-account signing keys (a private cluster, or kind), the agent can send them once. Create a single-use enrollment key in Admiral and store it in the release namespace before you install:

```bash
kubectl --namespace admiral-system create secret generic admiral-k8s-agent-enrollment \
  --from-literal=key=<enrollment key>
```

Then add `--set enrollment.existingSecret=admiral-k8s-agent-enrollment`. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts.

## Permissions

A dry-run apply is authorized as a real write, so the default rules grant `get`, `list`, `patch` and `create` on every resource. Narrow them with `rbac.namespaces` and `rbac.rules`. Whatever you grant, the agent needs `get` on the `kube-system` namespace to start. See [permissions](https://github.com/admiral-io/admiral-k8s-agent/blob/master/docs/permissions.md) for each call the agent makes and why.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| admiral | object | `{"audience":"admiral.io","clusterId":"","insecure":false,"server":""}` | How the agent reaches Admiral and which cluster it reports as. |
| admiral.audience | string | `"admiral.io"` | Audience of the projected service-account token the agent presents to Admiral. It must match the audience your Admiral installation expects. |
| admiral.clusterId | string | `""` | The cluster's ID in Admiral, shown when you register the cluster. Sets `ADMIRAL_CLUSTER_ID`. Required. |
| admiral.insecure | bool | `false` | Connect to Admiral without TLS. For local development only. Sets `ADMIRAL_INSECURE`. |
| admiral.server | string | `""` | Admiral's address (`host:port`). Sets `ADMIRAL_SERVER`. Required. |
| affinity | object | `{}` | Affinity rules for pod assignment |
| enrollment | object | `{"existingSecret":"","existingSecretKey":"key"}` | Enrollment sends the cluster's service-account signing keys to Admiral once, for a cluster whose keys Admiral cannot fetch (a private cluster, or kind). Create a single-use enrollment key in Admiral, store it in a Secret in the release namespace, and name that Secret here. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts. |
| enrollment.existingSecret | string | `""` | Name of a Secret holding the enrollment key. Empty means the agent does not enroll. |
| enrollment.existingSecretKey | string | `"key"` | Key within `existingSecret` that holds the enrollment key. Sets `ADMIRAL_ENROLLMENT_KEY`. |
| extraArgs | list | `[]` | Extra arguments appended to the agent's `run` command |
| extraEnv | list | `[]` | Extra environment variables for the agent container. The agent honors `HTTPS_PROXY`. |
| fullnameOverride | string | `""` | Override the full release name |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-k8s-agent","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-k8s-agent"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"enabled":false,"extraEgress":[]}` | NetworkPolicy that limits the agent's outbound traffic to DNS (port 53), the Kubernetes API server (ports 443 and 6443, since many clusters serve the API on 6443 behind the `kubernetes` Service), and Admiral (the port in `admiral.server`, 443 when none is given). The rules match by port only, because the chart cannot know the addresses behind them. Inbound traffic is left alone: the agent accepts none except its health checks. |
| networkPolicy.enabled | bool | `false` | Create the NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules, for example to reach an HTTPS proxy |
| nodeSelector | object | `{}` | Node selector for pod assignment |
| planConcurrency | int | `2` | How many plans the agent runs at once, from 1 to 64. Sets `ADMIRAL_PLAN_CONCURRENCY`. |
| podAnnotations | object | `{}` | Annotations to add to the pod |
| podLabels | object | `{}` | Labels to add to the pod |
| podSecurityContext | object | `{"fsGroup":65532,"runAsGroup":65532,"runAsNonRoot":true,"runAsUser":65532,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. Meets the Kubernetes restricted Pod Security Standard. The image runs as uid and gid 65532. |
| priorityClassName | string | `""` | Priority class for the pod |
| rbac | object | `{"create":true,"namespaces":[],"rules":[]}` | What the agent may do in the cluster. A plan reads live objects and runs a server-side apply dry run. Kubernetes authorizes that dry run as a real write, a patch for an object that exists and a create for one that does not, so the agent needs `get`, `patch` and `create` on every kind it plans. |
| rbac.create | bool | `true` | Create the RBAC objects. Set false to bind the service account yourself. |
| rbac.namespaces | list | `[]` | Namespaces the agent may plan in. Empty grants the rules in every namespace through one ClusterRole. When set, the chart creates a Role and RoleBinding in each listed namespace, plus a small ClusterRole that lets the agent get the `kube-system` namespace (it reports that namespace's UID at startup) and list namespaces (to find where it may write). The listed namespaces must already exist. |
| rbac.rules | list | `[]` | Rules for the ClusterRole, or for each Role when `namespaces` is set. Empty uses `get`, `list`, `patch` and `create` on every resource. Replaces the default entirely; values are not merged. |
| resources | object | `{}` | Resource requests and limits |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true}` | Container security context |
| serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account the agent runs as. Its projected token is the agent's identity to Admiral. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| shutdownDrain | string | `"25s"` | How long running work may finish after the pod is asked to stop. Sets `ADMIRAL_SHUTDOWN_DRAIN`. Write it in hours, minutes and seconds (`25s`, `1m30s`). The pod's termination grace period is set 5 seconds above it. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| verbose | bool | `false` | Log at debug level. Adds `--verbose`. |
