#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/k3s-common.sh"

require_kubectl
ensure_user_kubeconfig

kubectl "$@"
