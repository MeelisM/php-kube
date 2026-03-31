#!/bin/bash

SYSTEM_K3S_CONFIG="/etc/rancher/k3s/k3s.yaml"
USER_K3S_CONFIG="${HOME}/.kube/k3s-config"

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required. Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
  fi
}

resolve_k3s_bin() {
  if command -v k3s >/dev/null 2>&1; then
    K3S_BIN="$(command -v k3s)"
  elif [ -x /usr/local/bin/k3s ]; then
    K3S_BIN="/usr/local/bin/k3s"
  elif [ -x /usr/bin/k3s ]; then
    K3S_BIN="/usr/bin/k3s"
  else
    K3S_BIN=""
  fi

  if [ -z "${K3S_BIN}" ]; then
    echo "k3s is required. Install: https://k3s.io/"
    exit 1
  fi
}

ensure_user_kubeconfig() {
  mkdir -p "${HOME}/.kube"

  if [ ! -r "${USER_K3S_CONFIG}" ]; then
    if [ ! -f "${SYSTEM_K3S_CONFIG}" ]; then
      echo "k3s kubeconfig not found at ${SYSTEM_K3S_CONFIG}."
      exit 1
    fi

    if [ -r "${SYSTEM_K3S_CONFIG}" ]; then
      cp "${SYSTEM_K3S_CONFIG}" "${USER_K3S_CONFIG}"
    else
      sudo cp "${SYSTEM_K3S_CONFIG}" "${USER_K3S_CONFIG}"
      sudo chown "$(id -u):$(id -g)" "${USER_K3S_CONFIG}"
    fi

    chmod 600 "${USER_K3S_CONFIG}"
  fi

  export KUBECONFIG="${USER_K3S_CONFIG}"
}
