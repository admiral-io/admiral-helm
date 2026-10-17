# admiral-k8s-agent

![Version: 0.9.0](https://img.shields.io/badge/Version-0.9.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.2.0](https://img.shields.io/badge/AppVersion-v0.2.0-informational?style=flat-square)

Runs an Admiral agent in Kubernetes over an outbound-only connection, and plans and applies changes with server-side apply.

[Admiral](https://admiral.io/?utm_source=artifacthub&utm_medium=referral&utm_campaign=admiral-k8s-agent) is a control plane for coordinating infrastructure and application delivery across environments. This chart installs the self-hosted agent that connects one of your clusters to it.

## What it installs

The Admiral Kubernetes Agent runs in your cluster, takes work from Admiral, and reports what it finds. It plans changes by server-side apply dry run, applies them component by component once approved, and reports the cluster's version, API groups and what it may write. It opens outbound connections only.

The chart installs one agent:

- a Deployment, one replica by default. Its pods elect a leader through a Lease, and only the leader claims jobs, so more replicas add failover, not throughput.
- a ServiceAccount, whose projected token (audience `admiral.audience`) is the agent's identity to Admiral. The agent holds no long-lived credential.
- RBAC for what the agent may deploy, a Role to hold its Lease in the release namespace, and a binding to `system:service-account-issuer-discovery` so it can read the cluster's token signing keys
- optionally, an egress-only NetworkPolicy

In Admiral, run `admiral agent create` for each agent. It prints the Admiral service account the agent signs in as, an `sa-` id, and a single-use enrollment key (see [Enrollment](#enrollment)). The agent connects to `api.admiral.io:443`; set `admiral.server` for another Admiral.

```bash
helm repo add admiral https://charts.admiral.io
helm repo update
```

The chart is also published as `oci://ghcr.io/admiral-io/admiral-helm/admiral-k8s-agent`.

## One agent for the cluster

The default. The agent may deploy to every namespace through one ClusterRole.

```bash
helm install admiral-k8s-agent admiral/admiral-k8s-agent \
  --namespace admiral-system --create-namespace \
  --set admiral.serviceAccountId=<sa- id> \
  --set serviceAccount.name=admiral-k8s-agent
```

## Several agents in one cluster

To keep workloads apart, run one release per agent, each in its own namespace and limited with `rbac.namespaces` to the namespaces it may deploy to. The chart then creates a Role in each of those namespaces instead of granting every namespace. In Admiral, grant each agent only to the environments that should use it.

```bash
helm install agent-payments admiral/admiral-k8s-agent \
  --namespace admiral-payments --create-namespace \
  --set admiral.serviceAccountId=<sa- id> \
  --set serviceAccount.name=admiral-k8s-agent \
  --set 'rbac.namespaces={payments-prod}'
```

Every cluster-scoped object the chart creates is named after both the release and its namespace, so releases do not collide.

## Enrollment

Enrollment sends the cluster's service-account signing keys to Admiral once, so Admiral learns which issuer signs the agent's token and which subject to expect. Store the enrollment key that `admiral agent create` printed in the release namespace before you install:

```bash
kubectl --namespace admiral-system create secret generic admiral-k8s-agent-enrollment \
  --from-literal=key=<enrollment key>
```

Then add `--set enrollment.existingSecret=admiral-k8s-agent-enrollment`. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts.

## Permissions

A dry-run apply is authorized as a real write, and an apply deletes what a component no longer renders, finished hooks and objects it replaces. So the default rules grant `get`, `patch`, `create` and `delete` on the built-in kinds most charts render, and `watch` on Jobs and Pods so an apply sees a hook finish even when its TTL deletes it at once. Without `watch`, the agent polls instead. Each kind is named, because a wildcard also grants subresources such as `pods/exec` and `serviceaccounts/token`, which amount to cluster-admin. Narrow the rules with `rbac.namespaces` and `rbac.rules`, and limit what plans and applies may touch with `allowedNamespaces`. Whatever you grant, the agent needs `get` on the `kube-system` namespace to start.

Without `rbac.namespaces`, the agent's ClusterRole is aggregated. To let it manage a custom resource, add a ClusterRole for the resource's group with the label `admiral.io/aggregate-to-agent: "true"`. Name the resources, never `*`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admiral-k8s-agent-widgets
  labels:
    admiral.io/aggregate-to-agent: "true"
rules:
  - apiGroups: ["example.com"]
    resources: ["widgets"]
    verbs: ["get", "patch", "create", "delete"]
```

Every cluster-wide agent in the cluster picks up a role with that label. With `rbac.namespaces`, add the rules to `rbac.rules` instead.

## Pod Security

The pod meets the `restricted` Pod Security Standard. Enforce it on the release namespace:

```bash
kubectl label namespace admiral-system \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

## Upgrading

An upgrade starts the new pod before stopping the old one, and stops the old one only once the new one can read the Lease and is connected to Admiral. A new pod that cannot reach Admiral leaves the old agent running. Running jobs get `shutdownDrain` to finish, then the old pod releases the Lease and the new one takes over.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| admiral | object | `{"audience":"admiral.io","ca":{"configMap":"","key":"ca.crt"},"insecure":false,"server":"api.admiral.io:443","serviceAccountId":""}` | How the agent reaches Admiral and which agent it is. |
| admiral.audience | string | `"admiral.io"` | Audience of the projected service-account token the agent presents to Admiral. It must match the audience your Admiral installation expects. |
| admiral.ca | object | `{"configMap":"","key":"ca.crt"}` | Trust a private certificate authority for Admiral, beside the system's. Names a ConfigMap in the release namespace holding PEM certificates. Sets `ADMIRAL_CA_FILE`. |
| admiral.ca.configMap | string | `""` | Name of the ConfigMap. Empty trusts the system's authorities only. |
| admiral.ca.key | string | `"ca.crt"` | Key within the ConfigMap that holds the certificates. |
| admiral.insecure | bool | `false` | Connect to Admiral without TLS. For local development only: the agent warns at start and will not enroll this way. Sets `ADMIRAL_INSECURE`. |
| admiral.server | string | `"api.admiral.io:443"` | Admiral's address (`host:port`). Sets `ADMIRAL_SERVER`. |
| admiral.serviceAccountId | string | `""` | The Admiral service account the agent signs in as, an `sa-` id, which `admiral agent create` prints. Sets `ADMIRAL_SERVICE_ACCOUNT_ID`. Required. |
| affinity | object | `{}` | Affinity rules for pod assignment |
| allowedNamespaces | list | `[]` | The only namespaces plans and applies may read or write. A plan or apply that touches another namespace fails. Empty means any namespace the agent's RBAC allows. Sets `ADMIRAL_ALLOWED_NAMESPACES`. |
| applyConcurrency | int | `1` | How many applies the agent runs at once, from 1 to 64. Sets `ADMIRAL_APPLY_CONCURRENCY`. |
| applyHealthTimeout | string | `"5m"` | How long one component's objects, and each of its hooks, may take to become ready during an apply. Sets `ADMIRAL_APPLY_HEALTH_TIMEOUT`. Write it in hours, minutes and seconds (`5m`, `1h`). |
| enrollment | object | `{"existingSecret":"","existingSecretKey":"key"}` | Enrollment sends the cluster's service-account signing keys to Admiral once, so Admiral learns which issuer signs the agent's token and which subject to expect. `admiral agent create` prints a single-use enrollment key. Store it in a Secret in the release namespace, and name that Secret here. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts. |
| enrollment.existingSecret | string | `""` | Name of a Secret holding the enrollment key. Empty means the agent does not enroll. |
| enrollment.existingSecretKey | string | `"key"` | Key within `existingSecret` that holds the enrollment key. The key is mounted as a file, so it does not show in the pod's environment. Sets `ADMIRAL_ENROLLMENT_KEY_FILE`. |
| extraArgs | list | `[]` | Extra arguments appended to the agent's `run` command |
| extraEnv | list | `[]` | Extra environment variables for the agent container. The agent honors `HTTPS_PROXY`. |
| fullnameOverride | string | `""` | Override the full release name |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-k8s-agent","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-k8s-agent"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| kubeBurst | int | `100` | Requests the agent may send at once above `kubeQPS`. Sets `ADMIRAL_KUBE_BURST`. |
| kubeQPS | int | `50` | Requests per second the agent sends the Kubernetes API, shared by all its jobs. Sets `ADMIRAL_KUBE_QPS`. |
| leaderElect | bool | `true` | Elect one leader among the agent's pods through the Lease `admiral-k8s-agent-<service account id>` in the release namespace. The others stand by and take over when it stops. With `rbac.create`, the chart grants get, create and update on Leases in the release namespace. Set false only for one replica that should not hold a Lease. Sets `ADMIRAL_LEADER_ELECT`. |
| logFormat | string | `"json"` | Log format, `json` or `text`. Sets `ADMIRAL_LOG_FORMAT`. |
| maxArtifactSize | string | `"16Mi"` | The most a job's artifact may expand to, from `1Mi` to `512Mi`. A larger artifact fails its job. A plan holds about 16 times this, so raise the memory limit with it. Sets `ADMIRAL_MAX_ARTIFACT_SIZE`. |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"enabled":false,"extraEgress":[]}` | NetworkPolicy that limits the agent's outbound traffic to DNS (port 53), the Kubernetes API server (ports 443 and 6443, since many clusters serve the API on 6443 behind the `kubernetes` Service), and Admiral (the port in `admiral.server`, 443 when none is given). The rules match by port only, because the chart cannot know the addresses behind them. Inbound traffic is left alone: the agent accepts none except its health checks. |
| networkPolicy.enabled | bool | `false` | Create the NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules, for example to reach an HTTPS proxy |
| nodeSelector | object | `{"kubernetes.io/os":"linux"}` | Node selector for pod assignment. The image is built for Linux only. |
| planConcurrency | int | `2` | How many plans the agent runs at once, from 1 to 64. Sets `ADMIRAL_PLAN_CONCURRENCY`. |
| podAnnotations | object | `{}` | Annotations to add to the pod |
| podLabels | object | `{}` | Labels to add to the pod |
| podSecurityContext | object | `{"fsGroup":65532,"runAsGroup":65532,"runAsNonRoot":true,"runAsUser":65532,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. Meets the Kubernetes restricted Pod Security Standard. The image runs as uid and gid 65532. |
| priorityClassName | string | `""` | Priority class for the pod |
| rbac | object | `{"create":true,"namespaces":[],"rules":[]}` | What the agent may do in the cluster. A plan reads live objects and runs a server-side apply dry run; an apply does the same for real. Kubernetes authorizes either as a patch for an object that exists and a create for one that does not. An apply also deletes: objects a component no longer renders, finished hooks, and objects it replaces. So the agent needs `get`, `patch`, `create` and `delete` on every kind it manages, and `watch` on the Jobs and Pods it runs as hooks. |
| rbac.create | bool | `true` | Create the RBAC objects. Set false to bind the service account yourself. |
| rbac.namespaces | list | `[]` | Namespaces the agent may deploy to. Empty grants the rules in every namespace through one aggregated ClusterRole. To manage a custom resource then, add a ClusterRole for its group labeled `admiral.io/aggregate-to-agent: "true"`. When set, the chart creates a Role and RoleBinding in each listed namespace, plus a small ClusterRole that lets the agent get the `kube-system` namespace (it reports that namespace's UID at startup) and list namespaces (to find where it may write). The listed namespaces must already exist. |
| rbac.rules | list | `[]` | Rules for the ClusterRole, or for each Role when `namespaces` is set. Empty grants `get`, `patch`, `create` and `delete` on the built-in kinds most charts render, each named, with no wildcard, and `watch` on Jobs and Pods, which lets an apply see a hook finish even when its TTL deletes it at once. Replaces the default entirely; values are not merged. Rules without `watch` work, and the agent polls hooks instead. |
| replicas | int | `1` | Pods for this agent. Only the elected leader claims jobs, so more than one adds failover, not throughput. Needs `leaderElect`. |
| resources | object | `{"limits":{"cpu":"500m","memory":"1Gi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Resource requests and limits. The 1Gi limit covers two plans and an apply at the default `maxArtifactSize`. To accept larger artifacts or run more jobs at once, raise it by 16 times the extra size for each job slot. The agent sets Go's soft memory limit to 90% of the container's. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true}` | Container security context |
| serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account the agent runs as. Its projected token is the agent's identity to Admiral. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| shutdownDrain | string | `"25s"` | How long running work may finish after the pod is asked to stop. Sets `ADMIRAL_SHUTDOWN_DRAIN`. Write it in hours, minutes and seconds (`25s`, `1m30s`). The pod's termination grace period is set 5 seconds above it. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| verbose | bool | `false` | Log at debug level. Adds `--verbose`. |
