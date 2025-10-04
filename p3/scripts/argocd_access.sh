#!/bin/bash
set -e

NAMESPACE="argocd"
SERVICE="argocd-server"
LOCAL_PORT=8080

echo "=== Getting ArgoCD admin password ==="
PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")
        
if [ -z "$PASSWORD" ]; then
    echo "ERROR: Could not retrieve ArgoCD password"
    exit 1
fi

echo "Got admin password: $PASSWORD"
echo "Username: admin"
echo "Password: $PASSWORD"
HOST_ONLY_IP=$(hostname -I | tr ' ' '\n' | grep "^192\.168\." | head -1)
if [ ! -z "$HOST_ONLY_IP" ]; then
    echo "From physical PC: http://$HOST_ONLY_IP:8080"
fi