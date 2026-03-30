# Admiral Helm Charts

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Chart Publish](https://github.com/mberwanger/admiral-helm/actions/workflows/publish.yaml/badge.svg?branch=master)](https://github.com/mberwanger/admiral-helm/actions/workflows/publish.yaml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/admiral)](https://artifacthub.io/packages/search?repo=admiral)

Admiral Helm is a collection charts for admiral project. The charts can be added using following command:

```bash
helm repo add admiral https://charts.admiral.io
```

The charts published currently by this repository are the following:

| Chart name | Status | Description |
| ---------- | ------ | ----------- |
| [admiral](charts/admiral) | Alpha | Admiral platform orchestrator for Kubernetes |
| [admiral-agent](charts/admiral-agent) | Alpha | Admiral agent for cluster registration and workload discovery |
| [admiral-operator](charts/admiral-operator) | Alpha | Admiral Kubernetes operator for managing deployments |

## Security Policy

Please refer to [SECURITY.md](https://github.com/admiral-io/admiral-helm/blob/master/SECURITY.md) for details on how to report security issues.

## Changelog

Releases are managed independently for each helm chart, and changelogs are tracked on each release.
