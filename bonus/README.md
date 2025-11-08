# Inception of Things - Bonus Part

This bonus part demonstrates a complete GitOps workflow using **local GitLab** instead of external GitHub, integrated with ArgoCD for continuous deployment.

## Architecture

```
Local GitLab → GitLab CI/CD → ArgoCD → Kubernetes (k3d)
```

## What's Included

### Infrastructure
- **Local GitLab instance** running in Kubernetes via Helm
- **GitLab Runner** for CI/CD execution
- **ArgoCD integration** for GitOps deployment
- **Dedicated `gitlab` namespace**

### CI/CD Pipeline Features
- **Manifest validation** - Ensures Kubernetes YAML files are valid
- **Automated deployment** - Deploys on push to main branch
- **ArgoCD integration** - Syncs via GitOps methodology
- **Manual controls** - Rollback and cleanup capabilities
- **Health checks** - Verifies deployment status

## Quick Start

1. **Prerequisites**: Ensure Part 3 is running (ArgoCD + k3d cluster)

2. **Run the setup**:
   ```bash
   cd bonus/scripts
   ./setup_all.sh
   ```

3. **Access GitLab**:
   - URL: http://localhost:8082
   - Username: `root`
   - Password: (shown in setup output)

4. **Create project and push code**:
   ```bash
   # Follow the instructions shown after setup
   # Create 'wil42-config' project in GitLab
   # Push manifests to the repository
   ```

5. **Configure CI/CD**:
   - Add `KUBE_CONFIG` variable in GitLab project settings
   - Value provided in setup output (base64 encoded kubeconfig)

6. **Create ArgoCD application**:
   ```bash
   argocd app create wil42 \
     --repo http://localhost:8082/root/wil42-config.git \
     --path manifests \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace dev \
     --sync-policy automated
   ```

## File Structure

```
bonus/
├── scripts/
│   ├── setup_all.sh                 # Main orchestrator script
│   ├── setup_gitlab.sh              # GitLab installation via Helm
│   ├── setup_gitlab_integration.sh  # Integration setup
│   └── verify_setup.sh              # Setup verification
├── confs/
│   ├── manifests/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── .gitlab-ci.yaml             # GitLab CI/CD pipeline
│   └── application.yaml            # Deploy ArgoCD application
|     
└── README.md                       # This file
```

## GitLab CI/CD Pipeline

The pipeline includes these stages:

### 1. **Validate Stage**
- `validate-manifests`: Validates Kubernetes YAML files
- `lint-yaml`: YAML syntax checking

### 2. **Build Stage**
- `build-info`: Collects build metadata

### 3. **Deploy Stage**
- `deploy-to-dev`: Deploys via ArgoCD (manual trigger)
- `rollback`: Rollback capability (manual)
- `cleanup`: Resource cleanup (manual)
- `status-check`: Health verification (manual)

## Key Features

### **Local GitLab Instance**
- Runs entirely on your local machine
- No external dependencies
- Full GitLab features available

### **GitOps Workflow**
- Code changes trigger CI/CD pipeline
- ArgoCD handles deployment synchronization
- Declarative configuration management

### **Security & Isolation**
- Dedicated namespace for GitLab
- Proper RBAC configuration
- Isolated from other components

### **Complete Integration**
- Works with existing Part 3 setup
- Same manifests, different source
- Demonstrates GitOps flexibility

## Access Points

After setup completion:

| Service | URL | Credentials |
|---------|-----|-------------|
| GitLab | http://localhost:8082 | root / (from setup) |
| ArgoCD | http://localhost:8080 | admin / (from Part 3) |
| Application | http://localhost | - |

## Troubleshooting

### Common Issues

1. **GitLab not accessible**:
   ```bash
   kubectl get pods -n gitlab
   kubectl logs -f deployment/gitlab-webservice-default -n gitlab
   ```

2. **CI/CD pipeline fails**:
   - Check `KUBE_CONFIG` variable is set correctly
   - Verify GitLab Runner has proper permissions

3. **ArgoCD sync issues**:
   ```bash
   argocd app get wil42
   argocd app sync wil42 --prune
   ```

### Verification Commands

```bash
# Check all components
./scripts/verify_setup.sh

# Manual verification
kubectl get all -n gitlab
kubectl get all -n argocd
kubectl get all -n dev
```

## Benefits of This Approach

1. **Complete Control**: Everything runs locally
2. **Production-like**: Mirrors real GitOps workflows
3. **Learning**: Understand GitLab + ArgoCD integration
4. **Flexibility**: Easy to modify and experiment
5. **Security**: No external service dependencies

## Next Steps

1. Experiment with different deployment strategies
2. Add more sophisticated CI/CD stages
3. Implement GitLab environments and approvals
4. Add monitoring and alerting
5. Explore GitLab's advanced features (merge requests, issues, etc.)

This setup demonstrates a complete, production-ready GitOps workflow using entirely local infrastructure!
