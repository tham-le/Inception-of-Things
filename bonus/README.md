# Inception of Things - Bonus Part

This bonus part demonstrates a complete GitOps workflow using **local GitLab** instead of external GitHub, integrated with ArgoCD.

## Quick Start

```bash
cd bonus
./scripts/setup_all.sh
```

**Access Points:**
- GitLab: http://localhost:8082 (username: `root`, password: shown in output)
- ArgoCD: http://localhost:8080 (same as Part 3)

## Setup Steps

1. **Run the setup script** - Installs GitLab, ArgoCD, and creates namespaces
2. **Access GitLab** - Create a project called `wil42-config`
3. **Push manifests** - Follow the git commands shown in the setup output
4. **Watch ArgoCD sync** - Application will automatically deploy from local GitLab

## What's Included

- Local GitLab instance running in Kubernetes (minimal configuration)
- ArgoCD integration for GitOps workflow
- Dedicated `gitlab` namespace
- Sample manifests ready to deploy

## File Structure

```bash
bonus/
├── scripts/
│   ├── setup_all.sh                 # Main setup script
│   ├── setup_gitlab.sh              # GitLab installation
│   ├── setup_gitlab_integration.sh  # ArgoCD integration
│   └── verify_setup.sh              # Verification
├── confs/
│   ├── manifests/                   # Kubernetes manifests
│   ├── values.yaml                  # GitLab Helm values (optimized)
│   └── application.yaml             # ArgoCD application
└── README.md
```

## Troubleshooting

**GitLab not accessible:**
```bash
kubectl get pods -n gitlab
kubectl logs -f deployment/gitlab-webservice-default -n gitlab
```

**Check all components:**
```bash
./scripts/verify_setup.sh
```

## Key Features

- ✅ Fully local setup (no external dependencies)
- ✅ Optimized for development (reduced resource usage)
- ✅ Complete GitOps workflow demonstration
- ✅ ArgoCD auto-sync from local GitLab repository
