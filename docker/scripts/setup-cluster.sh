#!/bin/bash
# scripts/setup-cluster.sh

set -e

echo "🚀 Creating Kind cluster..."
kind create cluster --name wealist --config kind-config.yaml

echo "⏳ Installing Ingress Nginx Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "✅ Cluster ready!"
