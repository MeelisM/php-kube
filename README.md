# php-kube

## Table of Contents

- [What is implemented](#what-is-implemented)
- [Project structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Environment file](#environment-file)
- [Local Docker run (optional)](#local-docker-run-optional)
- [Kubernetes run (k3s)](#kubernetes-run-k3s)
- [Useful commands](#useful-commands)
- [Config and secrets source](#config-and-secrets-source)
- [Persistence check (PVC)](#persistence-check-pvc)
- [One-command happy path](#one-command-happy-path)
- [Postman collections](#postman-collections)
- [Manual kubeconfig setup](#manual-kubeconfig-setup)
- [Extra thoughts](#extra-thoughts)

## What is implemented

- PHP API with MySQL connectivity.
- Endpoints:
  - `GET /health`
  - `GET /api/items`
  - `POST /api/items` with JSON body `{"name":"..."}`
- DB schema initialization during DB container startup (image-baked init script).
- Dockerized app and database images.
- Kubernetes deployment with:
  - `Deployment` for PHP app
  - `StatefulSet` for MySQL
  - `PersistentVolumeClaim` for MySQL data
  - `Service` resources for app and DB
  - `ConfigMap` + `Secret` for configuration
  - Readiness/liveness probes
- Reproducible k3s automation scripts

## Project structure

- `app/` PHP source code
- `db/` MySQL image and initialization script
- `docker-compose.yml` local Docker setup
- `k8s/` Kubernetes manifests and kustomization
- `postman/` Postman collection and environment for API testing
- `scripts/` cluster automation scripts

## Prerequisites

- `docker`
- `make`
- `k3s` (preinstalled, running)
- `kubectl`

The automation in this repository starts from an already-installed k3s environment.

## Environment file

Copy the template once:

```bash
cp .env.example .env
```

Required keys:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `MYSQL_ROOT_PASSWORD`

## Local Docker run (optional)

1. Start services:

```bash
docker compose up --build
```

2. Test API:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/items
curl -X POST http://localhost:8080/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"A random item"}'
curl http://localhost:8080/api/items
```

3. Stop services:

```bash
docker compose down
```

## Kubernetes run (k3s)

Prerequisites from the section above must already be installed.

Bring everything up:

```bash
make k8s-up
```

`make k8s-up` also prepares user kubeconfig automatically (`~/.kube/k3s-config`) for this project workflow. If it does not, see [Manual kubeconfig setup](#manual-kubeconfig-setup) to troubleshoot.

Optional custom namespace:

```bash
make k8s-up NAMESPACE=my-namespace
```

Or directly:

```bash
bash scripts/k3s-up.sh
```

Access API locally (NodePort):

```bash
curl http://127.0.0.1:30080/health
curl http://127.0.0.1:30080/api/items
curl -X POST http://127.0.0.1:30080/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Another random item"}'
curl http://127.0.0.1:30080/api/items
```

See workload status:

```bash
make k8s-pods
make k8s-services
make k8s-status
```

Basic logs/observability:

```bash
make k8s-logs-app
make k8s-logs-db
```

Cleanup app layer only (keeps namespace, DB StatefulSet, PVC/data, and k3s installed):

```bash
make k8s-down
```

Destroy all project resources (deletes namespace, including DB PVC/data):

```bash
CONFIRM_DESTROY=yes make k8s-destroy
```

If namespace deletion gets stuck in `Terminating`, `k8s-destroy` times out and prints a manual finalizer command. That command forcibly clears namespace finalizers so Kubernetes can finish deletion. Use it only when normal deletion is stuck.

```bash
export KUBECONFIG="$HOME/.kube/k3s-config"
kubectl get namespace php-kube -o json | jq 'del(.spec.finalizers[])' | kubectl replace --raw /api/v1/namespaces/php-kube/finalize -f -
```

## Useful commands

```bash
make k8s-pods # list pods in the project namespace.
make k8s-services # list services.
make k8s-status # show all namespaced resources.
make k8s-logs-app # show app deployment logs.
make k8s-logs-db # show database statefulset logs.
```

## Config and secrets source

- `make k8s-up` reads values from root `.env`.
- Kubernetes `ConfigMap` `app-config` is created at deploy time with `DB_HOST`, `DB_PORT`, `DB_NAME`.
- Kubernetes `Secret` `db-secret` is created at deploy time with `DB_USER`, `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`.

## Persistence check (PVC)

1. Start app and DB with `make k8s-up`.
2. Insert a record with `POST /api/items`.
3. Run `make k8s-down`, then `make k8s-up` again.
4. Call `GET /api/items` and verify the inserted record is still present.

## One-command happy path

1. `make k8s-up`
2. Test `http://127.0.0.1:30080/health` and `http://127.0.0.1:30080/api/items`

## Postman collections

The collection includes request scripts that validate API behavior for all the endpoints. Ready-to-use Postman assets are in `postman/`.

- API Tests
  - GET All Items
  - POST Create Item
  - GET Health
- Test Suites
  - Suite 1 - Health
  - Suite 2 - Create Item
  - Suite 3 - Get Items and Verify

## Manual kubeconfig setup

This section is optional and mainly useful for troubleshooting or direct raw `kubectl` usage outside the provided `make` targets.

```bash
export KUBECONFIG="$HOME/.kube/k3s-config"
```

If that file does not exist yet, create it once:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
sudo chown "$(id -u):$(id -g)" ~/.kube/k3s-config
chmod 600 ~/.kube/k3s-config
export KUBECONFIG="$HOME/.kube/k3s-config"
```

## Extra thoughts

- I assumed that, in the case of `k3s`, it is already installed on the host machine since the instructions did not mention the host OS. Automated k3s installation can be complicated in that case because operating systems require different SELinux policy versions.

- I set up CPU-based horizontal scaling with the metrics server, but it required a lot of patching. This was either due to my local development environment or the host operating system (OpenSUSE Tumbleweed). Need to also disable firewall or open `port 10250`. In the end, I decided not to implement it.

- For local access I kept the app on a NodePort instead of wiring Ingress hostnames to avoid asking for `/etc/hosts` changes. In a real setup I’d keep the Service as `ClusterIP` and front it with Ingress/Gateway.
