#!/bin/bash
set -e

echo "=== BONUS: GitLab + ArgoCD Integration ==="

# ================================
# 1. Prerequisites Check
# ================================
CLUSTER_NAME="mycluster"
NAMESPACE="argocd"

echo "Checking prerequisites..."

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "k3d cluster $CLUSTER_NAME already created."
else
    echo "Create cluster $CLUSTER_NAME..."
    k3d cluster create $CLUSTER_NAME --wait \
        --port "8888:30080@loadbalancer" \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<100Mi,nodefs.available<100Mi@server:0"
fi

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



# Kill any existing port-forwards
echo "Cleaning up old port-forwards..."
pkill -f "port-forward.*argocd" 2>/dev/null || true
pkill -f "port-forward.*gitlab" 2>/dev/null || true

# Clean up old GitLab installation
echo "Cleaning up old GitLab installation..."
helm uninstall gitlab -n gitlab 2>/dev/null || true
kubectl delete namespace gitlab --timeout=60s 2>/dev/null || true
sleep 5

# ================================
# 2. Install Helm (if needed)
# ================================
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ================================
# 3. Create GitLab Namespace
# ================================
echo "Creating GitLab namespace..."
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# ================================
# 4. Install GitLab with Helm
# ================================
echo "Installing GitLab (this takes 15-20 minutes)..."
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update

# Get script directory for values.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="$(dirname "$SCRIPT_DIR")/confs/values.yaml"

helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 1800s \
  --values "$VALUES_FILE"

# ================================
# 5. Wait for GitLab
# ================================
echo "Waiting for GitLab pods to be ready..."
echo "⏳ This may take 15-30 minutes on low-resource machines..."
echo "   You can monitor progress with: kubectl get pods -n gitlab -w"

# Wait for webservice specifically (with longer timeout for low resources)
kubectl wait --for=condition=Ready pod \
  -l app=webservice \
  -n gitlab \
  --timeout=500s || {
    echo "WARNING: Some pods may still be initializing"
    echo "Checking pod status..."
    kubectl get pods -n gitlab
    echo ""
    echo "If pods are in 'Pending' or 'ContainerCreating', just wait a bit longer."
    echo "If pods are 'CrashLoopBackOff', you may need more RAM."
  }

# Give it extra time to stabilize
echo "Allowing pods to stabilize (this ensures GitLab is fully ready)..."
sleep 60

# ================================
# 6. Setup Persistent Port-Forward for GitLab
# ================================
echo "Setting up persistent port-forward for GitLab..."

# Create a background port-forward with auto-restart
cat > /tmp/gitlab_portforward.sh <<'EOF'
#!/bin/bash
while true; do
  echo "[$(date)] Starting GitLab port-forward..."
  kubectl port-forward service/gitlab-webservice-default 8082:8181 \
    -n gitlab \
    --address="0.0.0.0" 2>&1 | tee -a /tmp/gitlab_portforward.log
  echo "[$(date)] Port-forward died, restarting in 5s..."
  sleep 5
done
EOF

chmod +x /tmp/gitlab_portforward.sh
nohup /tmp/gitlab_portforward.sh > /dev/null 2>&1 &
GITLAB_PF_PID=$!
echo "GitLab port-forward running (PID: $GITLAB_PF_PID)"

# ================================
# 7. Setup Persistent Port-Forward for ArgoCD
# ================================
echo "Setting up persistent port-forward for ArgoCD..."

cat > /tmp/argocd_portforward.sh <<'EOF'
#!/bin/bash
while true; do
  echo "[$(date)] Starting ArgoCD port-forward..."
  kubectl port-forward svc/argocd-server 8080:443 \
    -n argocd \
    --address="0.0.0.0" 2>&1 | tee -a /tmp/argocd_portforward.log
  echo "[$(date)] Port-forward died, restarting in 5s..."
  sleep 5
done
EOF

chmod +x /tmp/argocd_portforward.sh
nohup /tmp/argocd_portforward.sh > /dev/null 2>&1 &
ARGOCD_PF_PID=$!
echo "ArgoCD port-forward running (PID: $ARGOCD_PF_PID)"

# Save PIDs for cleanup
echo "$GITLAB_PF_PID" > /tmp/gitlab_pf.pid
echo "$ARGOCD_PF_PID" > /tmp/argocd_pf.pid

# Wait for port-forwards to be ready
echo "Waiting for services to be accessible..."
sleep 10

# ================================
# 8. Setup Git Repository
# ================================
echo "Setting up local Git repository..."
REPO_DIR="/tmp/wil42-config"
rm -rf $REPO_DIR
mkdir -p $REPO_DIR/manifests

CONFS_DIR="$(dirname "$SCRIPT_DIR")/confs"
cp $CONFS_DIR/manifests/* $REPO_DIR/manifests/ 2>/dev/null || echo "No manifests found"
[ -f "$CONFS_DIR/.gitlab-ci.yaml" ] && cp "$CONFS_DIR/.gitlab-ci.yaml" $REPO_DIR/.gitlab-ci.yaml

cd $REPO_DIR
git config --global init.defaultBranch main
git config --global user.email "yuboktae@student.42.fr"
git config --global user.name "yuboktae"
git init
git add .
git commit -m "Initial commit"

# ================================
# 9. Create dev namespace
# ================================
echo "Creating dev namespace..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# ================================
# 10. Deploy ArgoCD Application
# ================================
echo "Creating ArgoCD application..."

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
echo "Deploy application directly to dev namespace..."
kubectl apply -f "$CONFS_DIR/manifests/" -n dev

echo "Deploy ArgoCD application configuration..."
kubectl apply -f "$CONFS_DIR/application.yaml" -n argocd

# ================================
# 11. Get Credentials
# ================================
echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "GitLab Access:"
echo "  URL: http://localhost:8082"
echo "  Username: root"
echo "  Password: (retrieving...)"
sleep 5
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode 2>/dev/null || echo "Run this to get password: kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode")
echo "  Password: $GITLAB_PASS"
echo ""
echo "ArgoCD Access:"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not available")
echo "  Password: $ARGOCD_PASS"
echo ""
echo "Next Steps:"
echo "1. Access GitLab at http://localhost:8082"
echo "2. Create project 'wil42-config'"
echo "3. Push the repository:"
echo "   cd $REPO_DIR"
echo "   git remote add origin http://localhost:8082/root/wil42-config.git"
echo "   git push -u origin main"
echo ""
echo "Repository ready at: $REPO_DIR"
echo ""
echo "Port-forward logs:"
echo "  GitLab: tail -f /tmp/gitlab_portforward.log"
echo "  ArgoCD: tail -f /tmp/argocd_portforward.log"
echo ""
echo "To stop port-forwards: kill \$(cat /tmp/gitlab_pf.pid) \$(cat /tmp/argocd_pf.pid)"