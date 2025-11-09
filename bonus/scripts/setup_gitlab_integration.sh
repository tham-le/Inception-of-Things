#!/bin/bash
set -e

echo "=== GitLab + ArgoCD Integration Setup ==="

# ================================
# Install ArgoCD if needed
# ================================
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "Installing ArgoCD..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
fi

# Create dev namespace
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# ================================
# Setup local Git repository
# ================================
REPO_DIR="/tmp/wil42-config"
rm -rf $REPO_DIR
mkdir -p $REPO_DIR/manifests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$(dirname "$SCRIPT_DIR")/confs"

if [ -d "$CONFS_DIR/manifests" ]; then
    cp $CONFS_DIR/manifests/* $REPO_DIR/manifests/
fi

[ -f "$CONFS_DIR/.gitlab-ci.yaml" ] && cp $CONFS_DIR/.gitlab-ci.yaml $REPO_DIR/.gitlab-ci.yml

cd $REPO_DIR
git config --global init.defaultBranch main
git config --global user.email "yuboktae@student.42.fr"
git config --global user.name "yuboktae"
git init
git add .

if [ -n "$(git status --porcelain)" ]; then
    git commit -m "Initial commit with Kubernetes manifests"
fi

# ================================
# Deploy ArgoCD Application
# ================================
[ -f "$CONFS_DIR/application.yaml" ] && kubectl apply -f $CONFS_DIR/application.yaml

# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" > /dev/null 2>&1 &

GITLAB_PASSWORD=$(kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "Not ready")

echo ""
echo "=== Integration Ready ==="
echo "Repository: $REPO_DIR"
echo ""
echo "Push to GitLab:"
echo "  cd $REPO_DIR"
echo "  git remote add origin http://localhost:8082/root/wil42-config.git"
echo "  git push -u origin main"