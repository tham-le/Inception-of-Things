#!/bin/bash
set -e

CLUSTER_NAME="mycluster"
KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"

echo "=== IoT Part 3: K3d + ArgoCD Setup ==="

# ================================
# Cleanup if low on space
# ================================
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 2000000 ]; then
    echo "Low disk space. Cleaning up..."
    docker system prune -a -f --volumes 2>/dev/null || true
    k3d cluster delete --all 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
fi

# ================================
# Install tools (parallel where possible)
# ================================
echo "Checking dependencies..."

# Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
fi

# kubectl and k3d in parallel
{
    if ! command -v kubectl &> /dev/null; then
        echo "Installing kubectl..."
        KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
        curl -Lo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
        sudo install -m 755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
} &

{
    if ! command -v k3d &> /dev/null; then
        echo "Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi
} &

wait

# ================================
# Create K3d cluster
# ================================
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Creating k3d cluster..."
    k3d cluster create $CLUSTER_NAME \
        --port "8888:30080@loadbalancer" \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<100Mi,nodefs.available<100Mi@server:0" \
        --wait
fi

# ================================
# Install ArgoCD
# ================================
if ! command -v argocd &> /dev/null; then
    echo "Installing ArgoCD CLI..."
    VERSION=$(curl -Ls https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
    curl -sSLo argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v${VERSION}/argocd-linux-amd64"
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

# ================================
# Deploy namespaces and ArgoCD
# ================================
echo "Creating namespaces..."
kubectl apply -f confs/namespaces.yaml

echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "Deploying application to dev namespace..."
kubectl apply -f confs/manifests/ -n dev

echo "Deploying ArgoCD application config..."
kubectl apply -f confs/application.yaml -n argocd

echo "Waiting for ArgoCD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "Starting ArgoCD port-forward..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" > /dev/null 2>&1 &

echo ""
echo "=== Setup Complete ==="
echo "Use './scripts/argocd_access.sh' to get credentials and access ArgoCD"