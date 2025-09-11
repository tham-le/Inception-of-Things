#!/bin/bash
set -e

NAMESPACE="argocd"
SERVICE="argocd-server"
LOCAL_PORT=8080

sudo apt install jq -y

echo "=== admin ArgoCD password ==="
PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "Got admin password"

echo "=== Lancement du port-forward ArgoCD ==="
echo "Access via https://localhost:$LOCAL_PORT"
echo "Login : admin"
echo "Password : $PASSWORD"
echo "Press Ctrl+C to stop port-forward."

kubectl port-forward svc/$SERVICE -n $NAMESPACE $LOCAL_PORT:443