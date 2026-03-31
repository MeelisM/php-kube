#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-php-kube}"
APP_IMAGE="${APP_IMAGE:-php-kube-app:local}"
DB_IMAGE="${DB_IMAGE:-php-kube-db:local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
source "${SCRIPT_DIR}/lib/k3s-common.sh"

read_env_value() {
  local key="$1"
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"

    case "$line" in
      ""|\#*)
        continue
        ;;
    esac

    if [[ "$line" == export\ *=* ]]; then
      line="${line#export }"
    fi

    if [[ "$line" == "$key="* ]]; then
      printf '%s' "${line#*=}"
      return 0
    fi
  done <"${ENV_FILE}"

  return 1
}

require_kubectl
resolve_k3s_bin

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo ".env file is required. Create it first (for example: cp .env.example .env)."
  exit 1
fi

required_keys=(DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD MYSQL_ROOT_PASSWORD)
for key in "${required_keys[@]}"; do
  if ! value="$(read_env_value "${key}")" || [ -z "${value}" ]; then
    echo "Missing required key in .env: ${key}"
    exit 1
  fi
done

DB_HOST="$(read_env_value DB_HOST)"
DB_PORT="$(read_env_value DB_PORT)"
DB_NAME="$(read_env_value DB_NAME)"
DB_USER="$(read_env_value DB_USER)"
DB_PASSWORD="$(read_env_value DB_PASSWORD)"
MYSQL_ROOT_PASSWORD="$(read_env_value MYSQL_ROOT_PASSWORD)"

if ! sudo "${K3S_BIN}" ctr version >/dev/null 2>&1; then
  if command -v systemctl >/dev/null 2>&1; then
    echo "k3s runtime is not reachable; trying to start k3s service..."
    sudo systemctl start k3s || true
    sleep 3
  fi
fi

ensure_user_kubeconfig

if ! sudo "${K3S_BIN}" ctr version >/dev/null 2>&1; then
  echo "k3s container runtime is not reachable."
  echo "Make sure k3s server is running (for example: sudo systemctl start k3s)."
  exit 1
fi

docker build -t "${APP_IMAGE}" "${PROJECT_ROOT}"
docker build -t "${DB_IMAGE}" -f "${PROJECT_ROOT}/db/Dockerfile" "${PROJECT_ROOT}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

docker save "${APP_IMAGE}" -o "${TMP_DIR}/php-kube-app.tar"
docker save "${DB_IMAGE}" -o "${TMP_DIR}/php-kube-db.tar"

sudo "${K3S_BIN}" ctr images import "${TMP_DIR}/php-kube-app.tar"
sudo "${K3S_BIN}" ctr images import "${TMP_DIR}/php-kube-db.tar"

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

kubectl create configmap app-config \
  --namespace "${NAMESPACE}" \
  --from-literal DB_HOST="${DB_HOST}" \
  --from-literal DB_PORT="${DB_PORT}" \
  --from-literal DB_NAME="${DB_NAME}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl create secret generic db-secret \
  --namespace "${NAMESPACE}" \
  --from-literal DB_USER="${DB_USER}" \
  --from-literal DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl apply --namespace "${NAMESPACE}" -k "${PROJECT_ROOT}/k8s"
kubectl --namespace "${NAMESPACE}" set image deployment/app app="${APP_IMAGE}"
kubectl --namespace "${NAMESPACE}" set image statefulset/db db="${DB_IMAGE}"

kubectl rollout status statefulset/db -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/app -n "${NAMESPACE}" --timeout=180s

echo "Kubernetes resources are ready in namespace ${NAMESPACE}."
echo "Access API at: http://localhost:30080/health"
echo "KUBECONFIG is set in this run to ${USER_K3S_CONFIG}"
