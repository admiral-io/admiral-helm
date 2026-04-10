#!/usr/bin/env bash
# hack/kind-up.sh — Set up a local KinD cluster with Admiral for demo/evaluation.
# Usage: ./hack/kind-up.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-admiral}"
RELEASE_NAME="${RELEASE_NAME:-admiral}"
NAMESPACE="${NAMESPACE:-default}"

# --- Pre-flight checks ---
for cmd in kind helm kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done

# --- Create KinD cluster (or reuse existing) ---
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "KinD cluster '${CLUSTER_NAME}' already exists, reusing."
else
  echo "Creating KinD cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${REPO_ROOT}/kind/cluster.yaml"
fi

# --- Install ingress-nginx ---
echo "Installing ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress-nginx to be ready..."
kubectl rollout status deployment ingress-nginx-controller --namespace ingress-nginx --timeout=120s

# --- Build chart dependencies ---
echo "Building chart dependencies..."
helm dependency build "${REPO_ROOT}/charts/admiral"

# --- Install Admiral ---
echo "Installing Admiral..."
helm upgrade --install "${RELEASE_NAME}" "${REPO_ROOT}/charts/admiral" \
  -f "${REPO_ROOT}/charts/admiral/demo-values.yaml" \
  --namespace "${NAMESPACE}" \
  --wait \
  --timeout 5m

echo ""
echo "==========================================="
echo "  Admiral is ready!"
echo "==========================================="
echo ""
echo "  URL: http://admiral.127.0.0.1.nip.io"
echo ""
echo "  Demo credentials:"
echo "    Email:    admin@example.com"
echo "    Password: $(kubectl get secret --namespace ${NAMESPACE} ${RELEASE_NAME}-oauth2 -o jsonpath='{.data.dex-demo-password}' 2>/dev/null | base64 -d || echo '(run helm install first)')"
echo ""
echo "  NOTE: It may take 1-2 minutes for the ingress to become ready."
echo ""
echo "  To tear down: make dev-down"
echo ""
