.PHONY: help dev-up dev-down dev-logs build-all build-% deploy-local deploy-eks clean \
        k8s-deploy k8s-deploy-registry k8s-deploy-dockerhub build-dockerhub k8s-apply-dockerhub \
        infra-setup

# Kind cluster name (default: wealist)
KIND_CLUSTER ?= wealist
# Local registry (for Docker Hub rate limit bypass)
LOCAL_REGISTRY ?= localhost:5001

# Default target
help:
	@echo "Wealist Project - Available commands:"
	@echo ""
	@echo "  Development (Docker Compose):"
	@echo "    make dev-up          - Start all services with Docker Compose"
	@echo "    make dev-down        - Stop all services"
	@echo "    make dev-logs        - View logs from all services"
	@echo "    make dev-restart     - Restart all services"
	@echo ""
	@echo "  Build:"
	@echo "    make build-all       - Build all service images (:local tag)"
	@echo "    make build-<service> - Build specific service"
	@echo ""
	@echo "  Kind Cluster:"
	@echo "    make kind-setup         - Create cluster + local registry (recommended)"
	@echo "    make infra-setup        - Load infra images (postgres, redis, etc.) to registry"
	@echo "    make kind-create        - Create simple cluster (no registry)"
	@echo "    make kind-delete        - Delete cluster"
	@echo ""
	@echo "  Kubernetes (Local/Kind) - Choose ONE method:"
	@echo "    [Method 1: kind load - Simple, fast]"
	@echo "    make k8s-deploy         - Build + kind load + deploy all"
	@echo ""
	@echo "    [Method 2: Local Registry - Docker Hub limit bypass]"
	@echo "    make k8s-deploy-registry - Build + push to registry + deploy all"
	@echo ""
	@echo "    [Method 3: Docker Hub - Push to Docker Hub]"
	@echo "    DOCKER_HUB_ID=<id> make k8s-deploy-dockerhub - Build + push + deploy"
	@echo ""
	@echo "    [Manual]"
	@echo "    make k8s-apply          - Apply manifests only (images must exist)"
	@echo "    make k8s-delete         - Delete all k8s resources"
	@echo ""
	@echo "  Kubernetes (EKS):"
	@echo "    make k8s-apply-eks      - Apply all k8s manifests (EKS)"
	@echo "    make k8s-delete-eks     - Delete all k8s resources (EKS)"
	@echo ""
	@echo "  Utility:"
	@echo "    make status          - Show status of containers and pods"
	@echo "    make clean           - Clean build artifacts and volumes"
	@echo "    make test-health     - Test health endpoints"

# =============================================================================
# Development (Docker Compose)
# =============================================================================

dev-up:
	./docker/scripts/dev.sh up

dev-down:
	./docker/scripts/dev.sh down

dev-logs:
	./docker/scripts/dev.sh logs

dev-restart:
	./docker/scripts/dev.sh restart

dev-build:
	./docker/scripts/dev.sh build

# =============================================================================
# Build Docker Images
# =============================================================================

SERVICES := user-service auth-service board-service chat-service noti-service storage-service video-service frontend

build-all: $(addprefix build-,$(SERVICES))

build-user-service:
	docker build -t user-service:local -f services/user-service/docker/Dockerfile services/user-service

build-auth-service:
	docker build -t auth-service:local -f services/auth-service/Dockerfile services/auth-service

build-board-service:
	docker build -t board-service:local -f services/board-service/docker/Dockerfile services/board-service

build-chat-service:
	docker build -t chat-service:local -f services/chat-service/docker/Dockerfile services/chat-service

build-noti-service:
	docker build -t noti-service:local -f services/noti-service/docker/Dockerfile services/noti-service

build-storage-service:
	docker build -t storage-service:local -f services/storage-service/docker/Dockerfile services/storage-service

build-video-service:
	docker build -t video-service:local -f services/video-service/docker/Dockerfile services/video-service

build-frontend:
	docker build -t frontend:local -f services/frontend/Dockerfile services/frontend

# =============================================================================
# Kind (Local Kubernetes Cluster)
# =============================================================================

# Full setup with local registry (recommended - bypasses Docker Hub limits)
kind-setup:
	@echo "Setting up Kind cluster with local registry..."
	./docker/scripts/dev/0.setup-cluster.sh
	@echo ""
	@echo "Next: make infra-setup"

# Load infrastructure images to local registry (postgres, redis, livekit, coturn)
infra-setup:
	@echo "Loading infrastructure images to local registry..."
	./docker/scripts/dev/1.load_infra_images.sh
	@echo ""
	@echo "Next: make k8s-deploy-registry"

# Simple cluster without registry (for quick testing)
kind-create:
	kind create cluster --name $(KIND_CLUSTER) --config docker/scripts/dev/kind-config.yaml
	@echo "Installing nginx ingress controller..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s || true
	@echo "Kind cluster '$(KIND_CLUSTER)' created successfully"
	@echo ""
	@echo "Next: make k8s-deploy"

kind-delete:
	kind delete cluster --name $(KIND_CLUSTER)
	@docker rm -f kind-registry 2>/dev/null || true

kind-load-all: $(addprefix kind-load-,$(SERVICES))
	@echo "All images loaded to kind cluster '$(KIND_CLUSTER)'"

kind-load-user-service:
	kind load docker-image user-service:local --name $(KIND_CLUSTER)

kind-load-auth-service:
	kind load docker-image auth-service:local --name $(KIND_CLUSTER)

kind-load-board-service:
	kind load docker-image board-service:local --name $(KIND_CLUSTER)

kind-load-chat-service:
	kind load docker-image chat-service:local --name $(KIND_CLUSTER)

kind-load-noti-service:
	kind load docker-image noti-service:local --name $(KIND_CLUSTER)

kind-load-storage-service:
	kind load docker-image storage-service:local --name $(KIND_CLUSTER)

kind-load-video-service:
	kind load docker-image video-service:local --name $(KIND_CLUSTER)

kind-load-frontend:
	kind load docker-image frontend:local --name $(KIND_CLUSTER)

# =============================================================================
# Kubernetes - Local (Kustomize + Kind)
# =============================================================================

# -----------------------------------------------------------------------------
# Method 1: kind load (Simple, fast - no registry needed)
# -----------------------------------------------------------------------------
k8s-deploy: build-all kind-load-all k8s-apply
	@echo ""
	@echo "✅ Deployment complete!"
	@echo "   Check status: make status"
	@echo "   Add to /etc/hosts: 127.0.0.1 wealist.local"

# -----------------------------------------------------------------------------
# Method 2: Local Registry (Docker Hub rate limit bypass)
# Requires: make kind-setup first
# -----------------------------------------------------------------------------
k8s-deploy-registry: build-registry k8s-apply-registry
	@echo ""
	@echo "✅ Deployment complete!"
	@echo "   Check status: make status"
	@echo "   Add to /etc/hosts: 127.0.0.1 wealist.local"

# Build and push to local registry
build-registry:
	@echo "Building and pushing to local registry ($(LOCAL_REGISTRY))..."
	./docker/scripts/dev/2.build_services_and_load.sh

# Apply manifests (registry mode - all-in-one)
k8s-apply-registry:
	kubectl apply -k k8s/overlays/develop-registry/all-services

# -----------------------------------------------------------------------------
# Method 3: Docker Hub (Push to public/private Docker Hub registry)
# Requires: DOCKER_HUB_ID environment variable
# -----------------------------------------------------------------------------
k8s-deploy-dockerhub: build-dockerhub k8s-apply-dockerhub
	@echo ""
	@echo "Deployment complete!"
	@echo "   Check status: make status"
	@echo "   Add to /etc/hosts: 127.0.0.1 wealist.local"

# Build and push to Docker Hub
build-dockerhub:
	@if [ -z "$(DOCKER_HUB_ID)" ]; then \
		echo "Error: DOCKER_HUB_ID is required"; \
		echo "Usage: DOCKER_HUB_ID=your-id make k8s-deploy-dockerhub"; \
		exit 1; \
	fi
	DOCKER_HUB_ID=$(DOCKER_HUB_ID) IMAGE_TAG=$(or $(IMAGE_TAG),latest) ./docker/scripts/docker-hub/build-and-push.sh

# Generate kustomization and apply (Docker Hub mode)
k8s-apply-dockerhub:
	@if [ -z "$(DOCKER_HUB_ID)" ]; then \
		echo "Error: DOCKER_HUB_ID is required"; \
		echo "Usage: DOCKER_HUB_ID=your-id make k8s-apply-dockerhub"; \
		exit 1; \
	fi
	DOCKER_HUB_ID=$(DOCKER_HUB_ID) IMAGE_TAG=$(or $(IMAGE_TAG),latest) ./docker/scripts/docker-hub/generate-kustomization.sh
	kubectl apply -k k8s/overlays/develop
	kubectl apply -k infrastructure/overlays/develop
	kubectl apply -k k8s/overlays/develop-dockerhub/all-services

# -----------------------------------------------------------------------------
# Manual apply/delete
# -----------------------------------------------------------------------------
k8s-apply:
	@echo "Applying all k8s manifests..."
	kubectl apply -k k8s/overlays/develop/all-services

k8s-delete:
	kubectl delete -k k8s/overlays/develop/all-services --ignore-not-found
	kubectl delete -k infrastructure/overlays/develop --ignore-not-found
	kubectl delete -k k8s/overlays/develop --ignore-not-found

# Preview kustomize output
kustomize-all:
	kubectl kustomize k8s/overlays/develop/all-services

kustomize-infra:
	kubectl kustomize infrastructure/overlays/develop

# =============================================================================
# Kubernetes - EKS
# =============================================================================

k8s-apply-eks:
	kubectl apply -k infrastructure/overlays/eks
	kubectl apply -k services/user-service/k8s/overlays/eks
	kubectl apply -k services/auth-service/k8s/overlays/eks
	kubectl apply -k services/board-service/k8s/overlays/eks
	kubectl apply -k services/chat-service/k8s/overlays/eks
	kubectl apply -k services/noti-service/k8s/overlays/eks
	kubectl apply -k services/storage-service/k8s/overlays/eks
	kubectl apply -k services/video-service/k8s/overlays/eks
	kubectl apply -k services/frontend/k8s/overlays/eks

k8s-delete-eks:
	kubectl delete -k services/frontend/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/video-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/storage-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/noti-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/chat-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/board-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/auth-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k services/user-service/k8s/overlays/eks --ignore-not-found
	kubectl delete -k infrastructure/overlays/eks --ignore-not-found

# =============================================================================
# Utility
# =============================================================================

clean:
	./docker/scripts/clean.sh

test-health:
	./docker/scripts/test-health.sh

monitoring:
	./docker/scripts/monitoring.sh

# Status check
status:
	@echo "=== Docker Containers ==="
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Kubernetes Pods (wealist-dev) ==="
	kubectl get pods -n wealist-dev 2>/dev/null || echo "Namespace not found"
