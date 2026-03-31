SHELL := /bin/bash
NAMESPACE ?= php-kube

.PHONY: dev down logs k8s-up k8s-down k8s-destroy k8s-status k8s-pods k8s-services k8s-logs-app k8s-logs-db

dev:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f

k8s-up:
	NAMESPACE=$(NAMESPACE) bash scripts/k3s-up.sh

k8s-down:
	NAMESPACE=$(NAMESPACE) bash scripts/k3s-down.sh

k8s-destroy:
	NAMESPACE=$(NAMESPACE) bash scripts/k3s-destroy.sh

k8s-status:
	bash scripts/k3s-kubectl.sh get all -n $(NAMESPACE)

k8s-pods:
	bash scripts/k3s-kubectl.sh get pods -n $(NAMESPACE)

k8s-services:
	bash scripts/k3s-kubectl.sh get svc -n $(NAMESPACE)

k8s-logs-app:
	bash scripts/k3s-kubectl.sh logs -n $(NAMESPACE) deployment/app

k8s-logs-db:
	bash scripts/k3s-kubectl.sh logs -n $(NAMESPACE) statefulset/db
