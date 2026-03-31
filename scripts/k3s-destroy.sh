#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-php-kube}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/k3s-common.sh"

require_kubectl
resolve_k3s_bin
ensure_user_kubeconfig

if [ "${CONFIRM_DESTROY:-}" != "yes" ]; then
  echo "Refusing destructive cluster wipe without confirmation."
  echo "Run: make k8s-destroy CONFIRM_DESTROY=yes"
  exit 1
fi

echo "Deleting namespace ${NAMESPACE}, please wait..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo "Namespace ${NAMESPACE} deleted (including app, db, and PVC data)."
echo "k3s runtime is kept installed."
