#!/bin/bash
set -e

# ================================
# Verify utils
# ================================

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "[INFO] Install Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "[OK] Docker already installed : $(docker --version)"
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "[INFO] Install kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
else
    echo "[OK] kubectl already installed : $(kubectl version --client)"
fi

# Check k3d
if ! command -v k3d &> /dev/null; then
    echo "[INFO] Install k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "[OK] k3d already installed : $(k3d version)"
fi

# ================================
# Create cluster K3D
# ================================
CLUSTER_NAME="mycluster"

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already created..."
else
    echo "Create cluster $CLUSTER_NAME..."
    k3d cluster create $CLUSTER_NAME --wait \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<100Mi,nodefs.available<100Mi@server:0"

fi

echo "Remove disk pressure taint if present..."
kubectl taint nodes --all node.kubernetes.io/disk-pressure:NoSchedule- || true

# ================================
# Namespaces
# ================================
echo "Create namespaces..."
kubectl apply -f confs/namespaces.yaml

# ================================
# Install ArgoCD
# ================================
echo "Install d'ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# ================================
# Application via ArgoCD
# ================================
echo "Deploy application directly to dev namespace..."
kubectl apply -f confs/app/ -n dev

echo "Deploy ArgoCD application configuration..."
kubectl apply -f confs/application.yaml -n argocd



# ================================
# Fin
# ================================
echo "Cluster K3D + ArgoCD + App deployed"
