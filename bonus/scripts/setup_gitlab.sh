#!/bin/bash
set -e

echo "=== Installing GitLab CE Locally ==="

# ================================
# Install Helm if not present
# ================================
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm already installed: $(helm version --short)"
fi

# ================================
# Create GitLab namespace
# ================================
echo "Creating GitLab namespace..."
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# ================================
# Install GitLab via Helm chart
# ================================
echo "Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || echo "Repository already exists"
helm repo update

# ================================
# Clean previous installation and free resources
# ================================
echo "Cleaning any previous GitLab installation..."
helm uninstall gitlab -n gitlab 2>/dev/null || echo "No previous installation found"
kubectl delete pvc --all -n gitlab 2>/dev/null || echo "No PVCs to delete"

echo "Checking cluster resources and cleaning up failed pods..."
# Clean up evicted, failed, and completed pods to free resources
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces 2>/dev/null || echo "No failed pods to clean"
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces 2>/dev/null || echo "No completed pods to clean"

# Show available resources
echo "Current cluster resources:"
kubectl top nodes || echo "Metrics server not available"

# Aggressively optimize ArgoCD resources for GitLab installation
echo "Optimizing ArgoCD resources for GitLab installation..."
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "Scaling down ArgoCD components to free memory for GitLab..."
    kubectl scale deployment argocd-server --replicas=1 -n argocd 2>/dev/null || echo "argocd-server not found"
    kubectl scale deployment argocd-repo-server --replicas=1 -n argocd 2>/dev/null || echo "argocd-repo-server not found"
    kubectl scale deployment argocd-dex-server --replicas=1 -n argocd 2>/dev/null || echo "argocd-dex-server not found"
    kubectl scale deployment argocd-applicationset-controller --replicas=1 -n argocd 2>/dev/null || echo "argocd-applicationset-controller not found"
    kubectl scale deployment argocd-notifications-controller --replicas=1 -n argocd 2>/dev/null || echo "argocd-notifications-controller not found"
    kubectl scale deployment argocd-redis --replicas=1 -n argocd 2>/dev/null || echo "argocd-redis not found"
    
    # Clean up problematic ArgoCD pods
    echo "Cleaning up problematic ArgoCD pods..."
    kubectl delete pods --field-selector=status.phase=Failed -n argocd 2>/dev/null || echo "No failed ArgoCD pods"
    kubectl delete pods --field-selector=status.phase=Succeeded -n argocd 2>/dev/null || echo "No completed ArgoCD pods"
    
    # Force delete stuck pods
    kubectl get pods -n argocd | grep -E "Evicted|ImagePullBackOff|Error|Completed" | awk '{print $1}' | xargs -r kubectl delete pod -n argocd --force --grace-period=0 2>/dev/null || echo "No stuck pods to force delete"
    
    echo "Waiting 30 seconds for ArgoCD cleanup to complete..."
    sleep 30
fi

# ================================
# Check available resources before GitLab installation
# ================================
echo "Checking available cluster resources..."
AVAILABLE_MEMORY=$(kubectl top nodes 2>/dev/null | awk 'NR>1 {gsub(/[^0-9]/, "", $4); print $4}' | head -1)
if [ ! -z "$AVAILABLE_MEMORY" ] && [ "$AVAILABLE_MEMORY" -lt 1000 ]; then
    echo "WARNING: Very low memory available ($AVAILABLE_MEMORY Mi). GitLab installation may fail."
    echo "Consider freeing up more resources or increasing cluster memory."
fi

# ================================
# Install GitLab with custom values
# ================================
echo "Installing GitLab CE (extremely minimal for resource-constrained environments)..."
echo "Note: This installation uses minimal resources and may have limited performance"
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 1800s \
  --values ./confs/values.yaml

# ================================
# Wait for GitLab to be ready
# ================================
echo "Waiting for GitLab pods to be ready (this may take 15-20 minutes with minimal resources)..."
kubectl wait --for=condition=Ready pod -l app=webservice --timeout=1200s -n gitlab || echo "Webservice may still be starting..."

# ================================
# Post-installation cleanup
# ================================
echo "Performing post-installation cleanup..."
# Clean up any failed pods that might have appeared during installation
kubectl delete pods --field-selector=status.phase=Failed -n gitlab 2>/dev/null || echo "No failed GitLab pods to clean"
kubectl delete pods --field-selector=status.phase=Succeeded -n gitlab 2>/dev/null || echo "No completed GitLab pods to clean"

# Show final resource usage
echo "Final cluster resource usage:"
kubectl top nodes || echo "Metrics server not available"
kubectl get pods -n gitlab --no-headers | wc -l | xargs -I {} echo "GitLab pods running: {}"
kubectl get pods -n argocd --no-headers | grep Running | wc -l | xargs -I {} echo "ArgoCD pods running: {}"

# ================================
# Expose GitLab
# ================================
echo "Exposing GitLab service..."
echo "Note: Configure VirtualBox port forwarding for GitLab access:"
echo "  Host Port 8082 → Guest Port 8082"
# Create log directory if it doesn't exist
sudo mkdir -p /var/log
sudo touch /var/log/gitlab-webserver.log
sudo chmod 666 /var/log/gitlab-webserver.log
kubectl port-forward service/gitlab-webservice-default 8082:8181 -n gitlab --address="0.0.0.0" > /var/log/gitlab-webserver.log 2>&1 &

# ================================
# Get GitLab credentials
# ================================
echo "Getting GitLab root password..."
echo "GitLab URL: http://localhost:8082"
echo "Username: root"

# Wait for secret to be available
MAX_ATTEMPTS=20
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    if kubectl get secret gitlab-gitlab-initial-root-password -n gitlab >/dev/null 2>&1; then
        echo -n "Password: "
        kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode
        echo ""
        break
    fi
    echo "Waiting for GitLab secret to be created... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 15
done

echo "=== GitLab Setup Complete ==="
echo "Access GitLab at: http://localhost:8082"
echo "Login with username 'root' and the password shown above"
echo "Next: Run configure_gitlab_projetc.sh to set up wil42-config repository"