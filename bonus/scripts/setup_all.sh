#!/bin/bash
set -e

echo "=== INCEPTION OF THINGS - BONUS PART ==="
echo "Setting up local GitLab + ArgoCD integration..."

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
# Clean up resources and install ArgoCD
# ================================
echo "Checking for resource issues and cleaning up if needed..."
if kubectl get pods -n argocd 2>/dev/null | grep -q "Evicted\|Pending\|ContainerStatusUnknown"; then
    echo "Detected resource issues with ArgoCD. Running emergency cleanup..."
    ./scripts/emergency_cleanup.sh
else
    echo "No resource issues detected, proceeding with ArgoCD installation..."
fi

# Check if ArgoCD CLI is already installed
if ! command -v argocd &> /dev/null; then
    echo "Install ArgoCD CLI..."
    # Option 1: Use latest stable version (more reliable)
    VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
    
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
else
    echo "[OK] ArgoCD CLI already installed : $(argocd version --client --short 2>/dev/null || echo 'version unknown')"
fi

# ================================
# Install GitLab
# ================================
echo ""
echo "=== 1. INSTALLING GITLAB ==="
./scripts/setup_gitlab.sh

# ================================
# Wait for GitLab to be fully ready
# ================================
echo ""
echo "=== 2. WAITING FOR GITLAB TO BE READY ==="

# Check GitLab readiness
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    if kubectl get pods -n gitlab | grep gitlab-webservice | grep -q Running; then
        echo "GitLab webservice is running!"
        sleep 30  # Give it extra time to fully initialize
        break
    fi
    echo "Waiting for GitLab... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 30
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "WARNING: GitLab may still be starting up. Continue with manual setup."
fi

# ================================
# Setup integration
# ================================
echo ""
echo "=== 3. SETTING UP INTEGRATION ==="
./scripts/setup_gitlab_integration.sh

# ================================
# Final instructions
# ================================
echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Next steps:"
echo "1. Access GitLab: http://localhost:8082"
echo "2. Login with username 'root' and the password shown above"
echo "3. Create a project called 'wil42-config'"
echo "4. Follow the Git commands shown above to push your manifests"
echo "5. Create the ArgoCD application to sync with your local GitLab"
echo ""
echo "This demonstrates GitOps with local GitLab instead of external GitHub!"
echo ""
echo "Access points:"
echo "- GitLab: http://localhost:8082"
echo "- ArgoCD: http://localhost:8080"
echo "- Your app: http://localhost (after sync)"
