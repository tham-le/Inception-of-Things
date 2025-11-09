#!/bin/bash
set -e

echo "=== [BONUS] GitLab Installation ==="

# Install Helm if needed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Create namespace
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# Create dummy object storage secret (required by GitLab even when backups disabled)
kubectl create secret generic gitlab-object-storage -n gitlab \
  --from-literal=connection="" \
  --dry-run=client -o yaml | kubectl apply -f -

# Add GitLab repo
echo "Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update

# Get script directory for values.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="$(dirname "$SCRIPT_DIR")/confs/values.yaml"

echo "Installing GitLab (minimal configuration)..."
if [ -f "$VALUES_FILE" ]; then
    helm upgrade --install gitlab gitlab/gitlab -n gitlab \
        -f "$VALUES_FILE" \
        --timeout 20m \
        --wait
else
    echo "Warning: values.yaml not found at $VALUES_FILE, using minimal inline config"
    helm upgrade --install gitlab gitlab/gitlab -n gitlab \
        --set global.hosts.domain="localhost" \
        --set global.edition=ce \
        --set global.ingress.enabled=false \
        --set certmanager.install=false \
        --set prometheus.install=false \
        --set gitlab-runner.install=false \
        --set registry.enabled=false \
        --set global.minio.enabled=false \
        --set gitlab.sidekiq.resources.requests.memory=500Mi \
        --set gitlab.webservice.resources.requests.memory=600Mi \
        --set postgresql.persistence.enabled=false \
        --set redis.master.persistence.enabled=false \
        --timeout 20m \
        --wait
fi

echo ""
echo "=== GitLab Installation Complete ==="
echo "Get root password:"
echo "  kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d"