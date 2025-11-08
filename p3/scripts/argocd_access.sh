#!/bin/bash
set -e

NAMESPACE="argocd"
SERVICE="argocd-server"
LOCAL_PORT=8080

echo "=== Checking ArgoCD Status ==="

# Check if ArgoCD namespace exists
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "ArgoCD namespace not found"
    echo "ArgoCD was skipped due to resource constraints"
    echo ""
    echo "Your application should be accessible directly:"
    echo "- Application: http://localhost:8888"
    echo "- Check status: kubectl get pods -n dev"
    exit 0
fi

# Check if ArgoCD pods exist
ARGOCD_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$ARGOCD_PODS" -eq 0 ]; then
    echo "No ArgoCD pods found"
    echo "ArgoCD was skipped due to resource constraints"
    echo ""
    echo "Your application should be accessible directly:"
    echo "- Application: http://localhost:8888"
    echo "- Check status: kubectl get pods -n dev"
    exit 0
fi

echo "ArgoCD namespace found with $ARGOCD_PODS pods"

# Try to get password
PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")
        
if [ -z "$PASSWORD" ]; then
    echo "Could not retrieve ArgoCD password (secret not found)"
    echo "This might be because ArgoCD is not fully running"
    echo ""
    echo "Check ArgoCD status:"
    kubectl get pods -n $NAMESPACE
    echo ""
    echo "Your application should still be accessible directly:"
    echo "- Application: http://localhost:8888"
    exit 0
fi

echo "Got ArgoCD admin password: $PASSWORD"
echo "Username: admin"
echo "Password: $PASSWORD"
HOST_ONLY_IP=$(hostname -I | tr ' ' '\n' | grep "^192\.168\." | head -1)
if [ ! -z "$HOST_ONLY_IP" ]; then
    echo "From physical PC: http://$HOST_ONLY_IP:8080"
fi

echo ""
echo "Note: Start port-forward if not already running:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:80 --address=\"0.0.0.0\""