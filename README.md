# Admiral Helm Charts

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Helm charts for running [Admiral](https://admiral.io/?utm_source=github&utm_medium=referral&utm_campaign=admiral-helm) components in your
Kubernetes clusters.

```bash
helm repo add admiral https://charts.admiral.io
helm repo update
```

| Chart | Status | Description |
| --- | --- | --- |
| [admiral-k8s-agent](charts/admiral-k8s-agent) | Alpha | Connects a Kubernetes cluster to Admiral |

Each chart is versioned and released on its own, and each release carries its
changelog.

## Admiral

[Admiral](https://admiral.io/?utm_source=github&utm_medium=referral&utm_campaign=admiral-helm) is a control plane for coordinating infrastructure and application delivery across environments. This repository is one of its
[open-source tools](https://github.com/admiral-io).

- [Documentation](https://admiral.io/docs?utm_source=github&utm_medium=referral&utm_campaign=admiral-helm)
- A bug in this repository: [open an issue](https://github.com/admiral-io/admiral-helm/issues/new/choose)
- Anything else about Admiral, or not sure where it goes: [admiral-community](https://github.com/admiral-io/admiral-community)
- A security vulnerability: email [security@admiral.io](mailto:security@admiral.io), never a public issue

## License

Apache License 2.0. See [LICENSE](LICENSE).
