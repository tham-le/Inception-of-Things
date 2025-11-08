#!/bin/bash
set -e

echo "=== GitLab + ArgoCD Integration Setup ==="

# ================================
# Prerequisites check
# ================================
if ! command -v argocd &> /dev/null; then
    echo "Warning: ArgoCD CLI not found. Installing..."
    VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "ArgoCD namespace not found. Installing ArgoCD..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
fi

# Check if ArgoCD CRDs are available
if ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    echo "ArgoCD CRDs not found. Installing CRDs..."
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/application-crd.yaml
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/appproject-crd.yaml
    sleep 10
fi


# Check if GitLab is running
if ! kubectl get pods -n gitlab | grep -q "gitlab-webservice"; then
    echo "Error: GitLab not found. Please run setup_gitlab.sh first."
    exit 1
fi

# ================================
# Create dev namespace
# ================================
echo "Creating dev namespace..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# ================================
# Setup local Git repository
# ================================
echo "Setting up local Git repository with manifests..."

# Create a temporary directory for the Git repo
REPO_DIR="/tmp/wil42-config"
rm -rf $REPO_DIR
mkdir -p $REPO_DIR/manifests

# Get the script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$(dirname "$SCRIPT_DIR")/confs"

echo "Script directory: $SCRIPT_DIR"
echo "Looking for configs in: $CONFS_DIR"

# Copy manifests with better path resolution
if [ -d "$CONFS_DIR/manifests" ]; then
    cp $CONFS_DIR/manifests/* $REPO_DIR/manifests/
    echo "Copied manifests from $CONFS_DIR/manifests"
    ls -la $REPO_DIR/manifests/
else
    echo "Warning: manifests directory not found at $CONFS_DIR/manifests"
    echo "Creating sample wil42 manifests..."

fi

# Copy GitLab CI configuration
if [ -f "$CONFS_DIR/.gitlab-ci.yaml" ]; then
    cp $CONFS_DIR/.gitlab-ci.yaml $REPO_DIR/.gitlab-ci.yml
    echo "Copied GitLab CI configuration"
fi

# Set git config and initialize repository
cd $REPO_DIR
git config --global init.defaultBranch main
git config --global user.email "yuboktae@student.42.fr"
git config --global user.name "yuboktae"
git init
git add .

# Check if there are files to commit
if [ -n "$(git status --porcelain)" ]; then
    git commit -m "Initial commit with Kubernetes manifests and GitLab CI"
    echo "Git repository initialized with files:"
    git log --oneline
    ls -la $REPO_DIR
else
    echo "Error: No files to commit. Check manifest copying."
    exit 1
fi

echo "Git repository created at: $REPO_DIR"

# ================================
# Deploy ArgoCD Application
# ================================
echo "Deploying ArgoCD Application configuration..."

# Apply the application.yaml to create the ArgoCD app
if [ -f "$CONFS_DIR/application.yaml" ]; then
    echo "Applying ArgoCD application from application.yaml..."
    kubectl apply -f $CONFS_DIR/application.yaml
    echo "ArgoCD application 'wil42' created successfully"
fi


# ================================
# Get GitLab credentials and final instructions
# ================================
echo "Getting GitLab credentials..."
GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode 2>/dev/null || echo "Password not ready yet")

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "🔗 Access Points:"
echo "   GitLab:  http://localhost:8082"  
echo "   ArgoCD:  http://localhost:8080"
echo ""
echo "🔑 GitLab Credentials:"
echo "   Username: root"
echo "   Password: $GITLAB_PASSWORD"
echo ""
echo "📋 Next Steps:"
echo "1. Access GitLab and create project 'wil42-config'"
echo "2. Push the prepared repository:"
echo "   cd $REPO_DIR"
echo "   git remote add origin http://localhost:8082/root/wil42-config.git"
echo "   git push -u origin main"
echo ""
echo "3. ArgoCD will automatically sync the application"
echo "4. Check deployment: kubectl get pods -n dev"
echo ""
echo "Repository ready at: $REPO_DIR"