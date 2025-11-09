#!/bin/bash
set -e

CLUSTER_NAME="mycluster"

echo "=== IoT Bonus: GitLab + ArgoCD Integration ==="

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
# Install tools in parallel
# ================================
echo "Checking dependencies..."

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
fi

{
    if ! command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
        curl -Lo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
        sudo install -m 755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
} &

{
    if ! command -v k3d &> /dev/null; then
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi
} &

{
    if ! command -v argocd &> /dev/null; then
        VERSION=$(curl -Ls https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
        curl -sSLo argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v${VERSION}/argocd-linux-amd64"
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
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
        --port "8082:8082@loadbalancer" \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<100Mi,nodefs.available<100Mi@server:0" \
        --wait
fi

# ================================
# Install GitLab
# ================================
echo ""
echo "=== Installing GitLab ==="
./scripts/setup_gitlab.sh

# ================================
# Setup Integration
# ================================
echo ""
echo "=== Setting up ArgoCD Integration ==="
./scripts/setup_gitlab_integration.sh

# ================================
# Final instructions
# ================================
GITLAB_PASSWORD=$(kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "Not ready yet")

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Access Points:"
echo "  GitLab:  http://localhost:8082"
echo "  ArgoCD:  http://localhost:8080"
echo ""
echo "GitLab Credentials:"
echo "  Username: root"
echo "  Password: $GITLAB_PASSWORD"
echo ""
echo "Next: Create project 'wil42-config' in GitLab and push manifests"