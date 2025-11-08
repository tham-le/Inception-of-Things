#!/bin/bash

echo "=== BONUS SETUP VERIFICATION ==="

# ================================
# Check GitLab
# ================================
echo "1. Checking GitLab status..."
if kubectl get pods -n gitlab | grep -q "gitlab-webservice.*Running"; then
    echo "GitLab is running"
    echo " Access: http://localhost:8082"
else
    echo "GitLab is not running properly"
    kubectl get pods -n gitlab
fi

# ================================
# Check GitLab Runner
# ================================
echo ""
echo "2. Checking GitLab Runner..."
if kubectl get pods -n gitlab | grep -q "runner"; then
    echo "GitLab Runner is available"
else
    echo "GitLab Runner not found (may need manual configuration)"
fi

# ================================
# Check ArgoCD
# ================================
echo ""
echo "3. Checking ArgoCD..."
if kubectl get pods -n argocd | grep -q "argocd-server.*Running"; then
    echo "ArgoCD is running"
    echo "   Access: http://localhost:8080"
else
    echo "ArgoCD is not running properly"
fi

# ================================
# Check cluster resources
# ================================
echo ""
echo "4. Checking cluster resources..."
echo "Nodes:"
kubectl get nodes

echo ""
echo "Namespaces:"
kubectl get namespaces | grep -E "(gitlab|argocd|dev)"

echo ""
echo "Services (GitLab & ArgoCD):"
kubectl get svc -n gitlab -o wide
kubectl get svc -n argocd -o wide

# ================================
# Check network connectivity
# ================================
echo ""
echo "5. Checking network connectivity..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8082 | grep -q "200\|302"; then
    echo "GitLab web interface is accessible"
else
    echo "GitLab web interface may not be ready yet"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
    echo "ArgoCD web interface is accessible"
else
    echo "ArgoCD web interface may not be ready yet"
fi

# ================================
# Show credentials
# ================================
echo ""
echo "6. Access credentials..."
echo "GitLab:"
echo "  URL: http://localhost:8082"
echo "  Username: root"
echo "  Password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode 2>/dev/null || echo 'Not available yet')"

echo ""
echo "ArgoCD:"
echo "  URL: http://localhost:8080"
echo "  Username: admin"
echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Not available yet')"

# ================================
# Final status
# ================================
echo ""
echo "=== SUMMARY ==="
echo "GitLab installed locally with Helm"
echo "Dedicated 'gitlab' namespace created"
echo "GitLab Runner configured for CI/CD"
echo "Integration with existing ArgoCD setup"
echo "GitOps workflow: GitLab → CI/CD → ArgoCD → Kubernetes"
echo ""
echo "Next steps:"
echo "1. Access GitLab and create the wil42-config project"
echo "2. Push your manifests to the GitLab repository"
echo "3. Configure CI/CD variables (KUBE_CONFIG)"
echo "4. Create ArgoCD application pointing to GitLab repo"
echo "5. Test the complete GitOps workflow!"
