#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-php-kube}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/k3s-common.sh"

require_kubectl
ensure_user_kubeconfig

if [ "${CONFIRM_DESTROY:-}" != "yes" ]; then
  echo "Refusing destructive cluster wipe without confirmation."
  echo "Run: make k8s-destroy CONFIRM_DESTROY=yes"
  exit 1
fi

echo "Deleting namespace ${NAMESPACE}, please wait..."
kubectl delete namespace "${NAMESPACE}" --wait=false --ignore-not-found=true

wait_secs=60
interval=3
elapsed=0
finalize_attempted=false

while kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; do
  if [ ${elapsed} -ge ${wait_secs} ]; then
    if [ "${finalize_attempted}" = false ]; then
      echo "Namespace ${NAMESPACE} is still deleting after ${wait_secs}s."
      echo "Attempting automatic finalizer removal..."
      kubectl patch namespace "${NAMESPACE}" --type=merge -p '{"spec":{"finalizers":[]}}' >/dev/null 2>&1 || true
      finalize_attempted=true
      elapsed=0
      continue
    fi

    echo "Namespace ${NAMESPACE} is still terminating after automatic finalizer removal attempt."
    echo "To force-remove finalizers manually (destructive), run:"
    echo "export KUBECONFIG=\"$HOME/.kube/k3s-config\""
    echo "kubectl get namespace ${NAMESPACE} -o json | jq 'del(.spec.finalizers[])' | kubectl replace --raw /api/v1/namespaces/${NAMESPACE}/finalize -f -"
    exit 1
  fi

  phase=$(kubectl get namespace "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  echo "Waiting for namespace ${NAMESPACE} to finish deletion (phase=${phase}, elapsed=${elapsed}s)..."
  sleep ${interval}
  elapsed=$((elapsed + interval))
done

echo "Namespace ${NAMESPACE} deleted (including app, db, and PVC data)."
echo "k3s runtime is kept installed."
