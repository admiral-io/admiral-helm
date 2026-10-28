# admiral-infra-agent

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

Runs an Admiral agent in Kubernetes that plans and applies Terraform and OpenTofu components over an outbound-only connection.

[Admiral](https://admiral.io/?utm_source=artifacthub&utm_medium=referral&utm_campaign=admiral-infra-agent) is a control plane for coordinating infrastructure and application delivery across environments. This chart installs the self-hosted agent that runs its Terraform and OpenTofu components where your infrastructure credentials are.

## What it installs

The Admiral Infra Agent takes work from Admiral, plans a component and uploads the saved plan and a redacted diff, and applies exactly the plan that was reviewed. It downloads OpenTofu on first use and checks its signature, and runs the Terraform binaries you list. It opens outbound connections only, and deploys nothing into the cluster it runs in.

The chart installs one agent:

- a Deployment, one replica by default. Its pods elect a leader through a Lease, and only the leader claims jobs, so more replicas add failover, not throughput.
- a ServiceAccount, whose projected token (audience `admiral.audience`) is the agent's identity to Admiral. The agent holds no long-lived credential.
- a ClusterRole that lets the agent read the `kube-system` namespace and nothing else, a Role to hold its Lease in the release namespace, and a binding to `system:service-account-issuer-discovery` so it can read the cluster's token signing keys
- a ConfigMap for the agent's configuration file, when `config` is set
- optionally, a PersistentVolumeClaim for its data, and an egress-only NetworkPolicy

In Admiral, run `admiral agent create` for each agent. It prints the Admiral service account the agent signs in as, an `sa-` id, and a single-use enrollment key (see [Enrollment](#enrollment)). The agent connects to `api.admiral.io:443`; set `admiral.server` for another Admiral.

```bash
helm repo add admiral https://charts.admiral.io
helm repo update
```

The chart is also published as `oci://ghcr.io/admiral-io/admiral-helm/admiral-infra-agent`.

## Install

```bash
helm install admiral-infra-agent admiral/admiral-infra-agent \
  --namespace admiral-system --create-namespace \
  --set admiral.serviceAccountId=<sa- id> \
  --set serviceAccount.name=admiral-infra-agent
```

## Enrollment

Enrollment sends the cluster's service-account signing keys to Admiral once, so Admiral learns which issuer signs the agent's token and which subject to expect. Store the enrollment key that `admiral agent create` printed in the release namespace before you install:

```bash
kubectl --namespace admiral-system create secret generic admiral-infra-agent-enrollment \
  --from-literal=key=<enrollment key>
```

Then add `--set enrollment.existingSecret=admiral-infra-agent-enrollment`. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts.

## Cloud credentials

The agent's jobs use whatever identity the pod has; Admiral never holds it. Every job inherits the agent's environment, except variables starting `ADMIRAL_`, `TF_` or `TOFU_`, and gets its own home and temporary directory. Give jobs an identity in whichever way your platform supports:

- workload identity: annotate the service account with `serviceAccount.annotations`, and allow the metadata server in `networkPolicy.extraEgress` if you enable the NetworkPolicy
- static keys: put them in a Secret and add it with `extraEnvFrom`, or with `extraEnv` and `secretKeyRef`
- credential files: mount them with `extraVolumes` and `extraVolumeMounts`, and point the provider's variable at them in `extraEnv`

At startup, the agent logs each credential every job can reach, by where it is and never by its value, and reports the same list to Admiral.

## Configuration file

`config` becomes the agent's JSON configuration file. Every key is optional:

```yaml
config:
  allowed_providers:
    - registry.opentofu.org/hashicorp/*
  terraform:
    - /opt/tools/terraform
  hooks:
    - name: conftest
      phase: post_plan
      command: ["/opt/tools/conftest", "test", "--output", "json"]
      timeout: 2m
```

The image holds only the agent. Put Terraform binaries and hook tools on a volume with `extraVolumes` and `extraVolumeMounts`, filled by one of `initContainers` or an image volume, and list them by their path there. The chart checks the keys and each hook's phase, because the agent refuses an unknown key at startup.

## Data and shutdown

The agent keeps job directories, downloaded OpenTofu releases, the provider cache, and any state an apply could not save to its backend under `/var/lib/admiral`. By default that is an emptyDir, so a new pod downloads OpenTofu and providers again, and saved state the backend refused is lost with the pod. Set `persistence.enabled` to keep it on a PersistentVolumeClaim. The Deployment then runs one replica and replaces its pod rather than rolling.

When a pod is asked to stop, plans stop at once and a running apply gets `shutdownDrain` (24 hours by default) to finish. An apply still running then stops before its next component and writes state. The chart sets the pod's termination grace period to `shutdownDrain` plus 5 minutes from the same value, so the two cannot drift. A rollout or `helm upgrade --wait` can therefore take as long as the longest apply.

## Metrics

The agent serves `/healthz`, `/readyz` and Prometheus metrics at `/metrics` on port 8081, the container port named `http`. Metric names start with `admiral_infra_agent_`.

## Pod Security

The pod meets the `restricted` Pod Security Standard, with a read-only root filesystem. Enforce it on the release namespace:

```bash
kubectl label namespace admiral-system \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| admiral | object | `{"audience":"admiral.io","ca":{"configMap":"","key":"ca.crt"},"insecure":false,"server":"api.admiral.io:443","serviceAccountId":""}` | How the agent reaches Admiral and which agent it is. |
| admiral.audience | string | `"admiral.io"` | Audience of the projected service-account token the agent presents to Admiral. It must match the audience your Admiral installation expects. |
| admiral.ca | object | `{"configMap":"","key":"ca.crt"}` | Trust a private certificate authority for Admiral, beside the system's. Names a ConfigMap in the release namespace holding PEM certificates. Sets `ADMIRAL_CA_FILE`. |
| admiral.ca.configMap | string | `""` | Name of the ConfigMap. Empty trusts the system's authorities only. |
| admiral.ca.key | string | `"ca.crt"` | Key within the ConfigMap that holds the certificates. |
| admiral.insecure | bool | `false` | Connect to Admiral without TLS. For local development only: the agent connects this way only to a loopback address, and will not enroll. Sets `ADMIRAL_INSECURE`. |
| admiral.server | string | `"api.admiral.io:443"` | Admiral's address (`host:port`). Sets `ADMIRAL_SERVER`. |
| admiral.serviceAccountId | string | `""` | The Admiral service account the agent signs in as, an `sa-` id, which `admiral agent create` prints. Sets `ADMIRAL_SERVICE_ACCOUNT_ID`. Required. |
| affinity | object | `{}` | Affinity rules for pod assignment |
| applyConcurrency | int | `1` | How many applies the agent runs at once, from 1 to 64. Sets `ADMIRAL_APPLY_CONCURRENCY`. |
| config | object | `{}` | The agent's configuration file. The chart writes it to a ConfigMap and sets `ADMIRAL_CONFIG_FILE`; when empty, the agent runs without one. Keys: `allowed_providers` limits the providers `init` may install (empty allows any), `terraform` lists Terraform binaries the agent may run (the agent downloads OpenTofu itself), and `hooks` run in every job at `pre_init`, `post_plan` or `post_apply`. The image holds only the agent, so mount Terraform and hook tools with `extraVolumes` or `initContainers`. |
| enrollment | object | `{"existingSecret":"","existingSecretKey":"key"}` | Enrollment sends the cluster's service-account signing keys to Admiral once, so Admiral learns which issuer signs the agent's token and which subject to expect. `admiral agent create` prints a single-use enrollment key. Store it in a Secret in the release namespace, and name that Secret here. The key is spent on first use. You can delete the Secret afterwards, and the agent still starts. |
| enrollment.existingSecret | string | `""` | Name of a Secret holding the enrollment key. Empty means the agent does not enroll. |
| enrollment.existingSecretKey | string | `"key"` | Key within `existingSecret` that holds the enrollment key. The key is mounted as a file, so it does not show in the pod's environment. Sets `ADMIRAL_ENROLLMENT_KEY_FILE`. |
| extraArgs | list | `[]` | Extra arguments appended to the agent's `run` command |
| extraEnv | list | `[]` | Extra environment variables for the agent container. Jobs inherit them, except those starting `ADMIRAL_`, `TF_` or `TOFU_`, so this is one way to hand jobs a credential. The agent honors `HTTPS_PROXY`. |
| extraEnvFrom | list | `[]` | Extra sources of environment variables, such as a Secret of API keys. Jobs inherit them as they do `extraEnv`. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the agent container |
| extraVolumes | list | `[]` | Extra volumes for the pod, such as tools for `config.terraform` and `config.hooks`, or a credentials file |
| fullnameOverride | string | `""` | Override the full release name |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/admiral-io/admiral-infra-agent","tag":""}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/admiral-io/admiral-infra-agent"` | Image repository |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| initContainers | list | `[]` | Init containers, for example to copy a Terraform binary into one of `extraVolumes` |
| leaderElect | bool | `true` | Elect one leader among the agent's pods through the Lease `admiral-infra-agent-<service account id>` in the release namespace. The others stand by and take over when it stops. With `rbac.create`, the chart grants get, create and update on Leases in the release namespace. Set false only for one replica that should not hold a Lease. Sets `ADMIRAL_LEADER_ELECT`. |
| logFormat | string | `"json"` | Log format, `json` or `text`. Sets `ADMIRAL_LOG_FORMAT`. |
| maxArtifactMiB | int | `64` | The most a job's artifact may expand to, in MiB, from 1 to 512. A larger artifact fails its job. Sets `ADMIRAL_MAX_ARTIFACT_MIB`. |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy | object | `{"enabled":false,"extraEgress":[]}` | NetworkPolicy that limits the agent's outbound traffic to DNS (port 53), HTTPS and the Kubernetes API server (ports 443 and 6443), and Admiral (the port in `admiral.server`, 443 when none is given). Jobs reach OpenTofu's releases, provider registries, state backends and cloud APIs over 443, so the rules match by port only. Inbound traffic is left alone: the agent accepts none except its health checks and metrics scrapes. |
| networkPolicy.enabled | bool | `false` | Create the NetworkPolicy |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules, for example to reach an HTTPS proxy or a cloud metadata server |
| nodeSelector | object | `{"kubernetes.io/os":"linux"}` | Node selector for pod assignment. The image is built for Linux only. |
| persistence | object | `{"accessModes":["ReadWriteOnce"],"enabled":false,"existingClaim":"","size":"20Gi","sizeLimit":"","storageClassName":""}` | Where the agent keeps job directories, downloaded OpenTofu releases, the provider cache, and state an apply could not save to its backend (under `kept/`). Mounted at `/var/lib/admiral`. An emptyDir by default, which the pod loses when it goes, kept state included. |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Access modes of the created claim |
| persistence.enabled | bool | `false` | Keep the data on a PersistentVolumeClaim instead of an emptyDir. The Deployment then replaces its pod rather than rolling, and runs one replica. |
| persistence.existingClaim | string | `""` | Use an existing claim instead of creating one |
| persistence.size | string | `"20Gi"` | Size of the created claim |
| persistence.sizeLimit | string | `""` | Size limit of the emptyDir when `enabled` is false. Empty sets none. |
| persistence.storageClassName | string | `""` | Storage class of the created claim. Empty uses the cluster's default. |
| planConcurrency | int | `2` | How many plans the agent runs at once, from 1 to 64. Sets `ADMIRAL_PLAN_CONCURRENCY`. |
| podAnnotations | object | `{}` | Annotations to add to the pod |
| podLabels | object | `{}` | Labels to add to the pod |
| podSecurityContext | object | `{"fsGroup":65532,"runAsGroup":65532,"runAsNonRoot":true,"runAsUser":65532,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. Meets the Kubernetes restricted Pod Security Standard. The image runs as uid and gid 65532. |
| priorityClassName | string | `""` | Priority class for the pod |
| rbac | object | `{"create":true}` | What the agent may do in the cluster. It deploys nothing there, so it needs no rights on workloads. It reads the `kube-system` namespace's UID at startup, reads the cluster's token signing keys for enrollment, and holds a Lease in the release namespace to elect a leader. |
| rbac.create | bool | `true` | Create the RBAC objects. Set false to bind the service account yourself. |
| replicas | int | `1` | Pods for this agent. Only the elected leader claims jobs, so more than one adds failover, not throughput. Needs `leaderElect`, and cannot be combined with `persistence.enabled`. |
| resources | object | `{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | Resource requests and limits. OpenTofu, Terraform and their providers run inside the agent's container, so size the limits for the largest components times `planConcurrency` plus `applyConcurrency`. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true}` | Container security context. The root filesystem is read-only: the agent writes only under its data directory and `/tmp`, both volumes. |
| serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account the agent runs as. Its projected token is the agent's identity to Admiral. Annotate it to give jobs a cloud identity through your platform's workload identity. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| shutdownDrain | string | `"24h"` | How long a running apply may finish after the pod is asked to stop. Plans stop at once. Sets `ADMIRAL_SHUTDOWN_DRAIN`. Write it in hours, minutes and seconds (`24h`, `1h30m`). The default matches an apply's 24h limit. An apply still running then stops before its next component and writes state, so the pod's termination grace period is set 5 minutes above this. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| verbose | bool | `false` | Log at debug level. Adds `--verbose`. |
