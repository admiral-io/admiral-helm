#!/usr/bin/env bash
set -eux

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure the helm-values-schema-json plugin is installed
if ! helm schema --help &>/dev/null; then
    echo "Installing helm-values-schema-json plugin..."
    helm plugin install https://github.com/losisin/helm-values-schema-json.git
fi

echo -e "\n-- Generating values.schema.json for all charts --\n"

for chart_dir in "$REPO_ROOT"/charts/*/; do
    chart_name="$(basename "$chart_dir")"
    if [ -f "$chart_dir/values.yaml" ]; then
        echo "Generating schema for $chart_name"
        (cd "$chart_dir" && helm schema)
    fi
done

echo -e "\nDone."
