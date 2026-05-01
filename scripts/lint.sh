#!/usr/bin/env bash
set -eux

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo -e "\n-- Building chart dependencies --\n"
for chart in "$SRCROOT"/charts/*/; do
  if [ -f "$chart/Chart.lock" ]; then
    helm dependency build "$chart"
  fi
done

echo -e "\n-- Linting all Helm Charts --\n"
docker run \
     -v "$SRCROOT:/workdir" \
     -w /workdir \
     -e GIT_CONFIG_GLOBAL=/tmp/gitconfig \
     --entrypoint sh \
     quay.io/helmpack/chart-testing:v3.14.0 \
     -c 'git config --global --add safe.directory /workdir && ct lint --config .github/configs/ct-lint.yaml --lint-conf .github/configs/lintconf.yaml --skip-helm-dependencies --debug'
