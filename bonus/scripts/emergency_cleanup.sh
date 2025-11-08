#!/bin/bash
set -e

echo "=== EMERGENCY CLUSTER CLEANUP ==="

# Stop all port-forwards that might be running
echo "Stopping any existing port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || echo "No port-forwards running"

# Completely remove ArgoCD to free resources
echo "Completely removing ArgoCD installation..."
kubectl delete namespace argocd --force --grace-period=0 2>/dev/null || echo "ArgoCD namespace not found"

# Clean up all failed/evicted/completed pods across all namespaces
echo "Cleaning up failed, evicted, and completed pods..."
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces --force --grace-period=0 2>/dev/null || echo "No failed pods"
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces --force --grace-period=0 2>/dev/null || echo "No completed pods"

# Find and delete evicted pods specifically
kubectl get pods --all-namespaces | grep Evicted | awk '{print $2 " -n " $1}' | xargs -r kubectl delete pod --force --grace-period=0 2>/dev/null || echo "No evicted pods found"

# Clean up any stuck pods
kubectl get pods --all-namespaces | grep "ContainerStatusUnknown\|Init:ContainerStatusUnknown" | awk '{print $2 " -n " $1}' | xargs -r kubectl delete pod --force --grace-period=0 2>/dev/null || echo "No stuck pods found"

# Wait for cleanup to complete
echo "Waiting for cleanup to complete..."
sleep 15

# Show current resource usage
echo "Current cluster state after cleanup:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl get pods --all-namespaces | grep -v "Running\|Completed" || echo "All pods cleaned up"

echo "=== CLUSTER CLEANUP COMPLETE ==="
echo "Now installing minimal ArgoCD..."

# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD with minimal resources
echo "Installing ArgoCD with minimal resource requirements..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait a moment for initial creation
sleep 10

# Reduce ArgoCD resource requirements
echo "Reducing ArgoCD resource requirements..."

# Scale down components to minimal replicas
kubectl scale deployment argocd-server --replicas=1 -n argocd
kubectl scale deployment argocd-repo-server --replicas=1 -n argocd
kubectl scale deployment argocd-dex-server --replicas=1 -n argocd
kubectl scale deployment argocd-redis --replicas=1 -n argocd
kubectl scale deployment argocd-applicationset-controller --replicas=1 -n argocd
kubectl scale deployment argocd-notifications-controller --replicas=1 -n argocd

# Patch deployments with minimal resource requests
echo "Setting minimal resource limits..."

# ArgoCD Server
kubectl patch deployment argocd-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","resources":{"requests":{"memory":"128Mi","cpu":"50m"},"limits":{"memory":"256Mi","cpu":"200m"}}}]}}}}'

# ArgoCD Repo Server  
kubectl patch deployment argocd-repo-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-repo-server","resources":{"requests":{"memory":"128Mi","cpu":"50m"},"limits":{"memory":"256Mi","cpu":"200m"}}}]}}}}'

# ArgoCD Application Controller
kubectl patch statefulset argocd-application-controller -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-application-controller","resources":{"requests":{"memory":"256Mi","cpu":"100m"},"limits":{"memory":"512Mi","cpu":"500m"}}}]}}}}'

# ArgoCD Redis
kubectl patch deployment argocd-redis -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"redis","resources":{"requests":{"memory":"64Mi","cpu":"25m"},"limits":{"memory":"128Mi","cpu":"100m"}}}]}}}}'

# ArgoCD Dex Server
kubectl patch deployment argocd-dex-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"dex","resources":{"requests":{"memory":"64Mi","cpu":"25m"},"limits":{"memory":"128Mi","cpu":"100m"}}}]}}}}'

# Other components
kubectl patch deployment argocd-applicationset-controller -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-applicationset-controller","resources":{"requests":{"memory":"64Mi","cpu":"25m"},"limits":{"memory":"128Mi","cpu":"100m"}}}]}}}}'

kubectl patch deployment argocd-notifications-controller -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-notifications-controller","resources":{"requests":{"memory":"64Mi","cpu":"25m"},"limits":{"memory":"128Mi","cpu":"100m"}}}]}}}}'

echo "Waiting for ArgoCD to stabilize..."
sleep 30

echo "ArgoCD status:"
kubectl get pods -n argocd

echo "=== READY FOR GITLAB INSTALLATION ==="
echo "ArgoCD has been installed with minimal resources."
echo "You can now run ./setup_gitlab.sh to install GitLab."
