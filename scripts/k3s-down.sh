#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-php-kube}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/k3s-common.sh"

require_kubectl
resolve_k3s_bin
ensure_user_kubeconfig

echo "Removing app resources in namespace ${NAMESPACE}, keeping db PVC/data..."
kubectl delete deployment app --namespace "${NAMESPACE}" --ignore-not-found=true
kubectl delete service app --namespace "${NAMESPACE}" --ignore-not-found=true
kubectl delete configmap app-config --namespace "${NAMESPACE}" --ignore-not-found=true
kubectl delete secret db-secret --namespace "${NAMESPACE}" --ignore-not-found=true

echo "Removed app resources from namespace ${NAMESPACE}."
echo "Database StatefulSet/PVC and namespace were kept."
