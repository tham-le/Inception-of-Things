#!/bin/bash

echo "=== CLEANING GITLAB INSTALLATION ==="

# Stop any port-forward processes
echo "Stopping port-forward processes..."
pkill -f "kubectl port-forward.*gitlab" || echo "No port-forward processes found"

# Uninstall GitLab
echo "Uninstalling GitLab Helm release..."
helm uninstall gitlab -n gitlab 2>/dev/null || echo "No GitLab release found"

# Delete PVCs (Persistent Volume Claims)
echo "Deleting persistent volume claims..."
kubectl delete pvc --all -n gitlab 2>/dev/null || echo "No PVCs found"

# Delete the namespace (this will remove everything)
echo "Deleting GitLab namespace..."
kubectl delete namespace gitlab --ignore-not-found=true

# Wait for namespace deletion
echo "Waiting for namespace deletion..."
while kubectl get namespace gitlab 2>/dev/null; do
    echo "Waiting for namespace gitlab to be deleted..."
    sleep 5
done

# Clean up any remaining resources
echo "Cleaning up any remaining resources..."
kubectl get all --all-namespaces | grep gitlab || echo "No GitLab resources found"

# Remove helm repo if needed
echo "GitLab repository kept for future use"

echo ""
echo "GitLab cleanup complete!"
echo "You can now run ./setup_gitlab.sh again"
