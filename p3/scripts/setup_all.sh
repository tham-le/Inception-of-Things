#!/bin/bash
set -e

# ================================
# Check disk space and cleanup
# ================================
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=2000000  # 2GB in KB

echo "Current disk usage: $(df -h / | awk 'NR==2 {print $5}') used"

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "WARNING: Low disk space ($(($AVAILABLE_SPACE/1024))MB available, 2GB recommended)"
    echo "Starting aggressive cleanup..."
    
    # Clean Docker
    if command -v docker &> /dev/null; then
        echo "Cleaning Docker images, containers, networks..."
        docker system prune -a -f --volumes 2>/dev/null || true
        docker builder prune -a -f 2>/dev/null || true
    fi
    
    # Clean k3d
    if command -v k3d &> /dev/null; then
        echo "Cleaning existing k3d clusters..."
        k3d cluster delete --all 2>/dev/null || true
    fi
    
    # Clean kubectl
    if command -v kubectl &> /dev/null; then
        echo "Cleaning kubectl cache..."
        rm -rf ~/.kube/cache 2>/dev/null || true
    fi
    
    # Clean system
    echo "Cleaning system files..."
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo apt-get autoclean -y 2>/dev/null || true
    sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    sudo rm -rf /var/log/*.log.* /var/log/*/*.log.* 2>/dev/null || true
    sudo journalctl --vacuum-time=1d 2>/dev/null || true
    
    echo "Cleanup completed. New disk usage: $(df -h / | awk 'NR==2 {print $5}') used"
fi

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
        --port "8888:30080@loadbalancer" \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<100Mi,nodefs.available<100Mi@server:0"

fi

# ================================
# Install ArgoCD
# ================================
# Check if ArgoCD CLI is already installed
if ! command -v argocd &> /dev/null; then
    echo "Install ArgoCD CLI..."
    # Option 1: Use latest stable version (more reliable)
    VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
    
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    # fi
else
    echo "[OK] ArgoCD CLI already installed : $(argocd version --client --short 2>/dev/null || echo 'version unknown')"
fi


# ================================
# Namespaces
# ================================
echo "Create namespaces..."
kubectl apply -f confs/namespaces.yaml


# ================================
# Application via ArgoCD
# ================================
echo "Install ArgoCD CRDs and components..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
echo "Deploy application directly to dev namespace..."
kubectl apply -f confs/manifests/ -n dev

echo "Deploy ArgoCD application configuration..."
kubectl apply -f confs/application.yaml -n argocd

# expose agrocd
echo "waiting for argocd pods to start.."
kubectl wait --for=condition=Ready pods --all --timeout=300s -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" 2>&1 > /tmp/argocd-log &

# ================================
# Fin
# ================================
echo "Cluster K3D + ArgoCD + App deployed"
echo "Use './scripts/argocd_access.sh' to get login credentials and manage access."
