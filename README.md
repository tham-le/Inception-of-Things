# Inception-of-Things (IoT)

A System Administration project focused on learning Kubernetes fundamentals using K3s, K3d, Vagrant, and ArgoCD.

## 🎯 Overview

This project introduces Kubernetes concepts through practical implementation using:

- **K3s**: Lightweight Kubernetes distribution
- **K3d**: K3s in Docker for local development
- **Vagrant**: Virtual machine management
- **ArgoCD**: GitOps continuous deployment tool

## 📁 Project Structure

```text
inception-of-things/
├── p1/          # K3s with Vagrant (2 VMs)
├── p2/          # K3s with 3 applications
├── p3/          # K3d and ArgoCD
└── bonus/       # GitLab integration (optional)
```

## 🚀 Quick Start

### Part 1: K3s and Vagrant

Set up two virtual machines with K3s cluster (controller + worker node).

```bash
cd p1
vagrant up
vagrant ssh thi-leS

# Verify cluster
kubectl get nodes -o wide
exit
```

**Expected**: Two nodes (thi-leS as control-plane, thi-leSW as worker) with IPs 192.168.56.110 and 192.168.56.111.

### Part 2: K3s and Three Applications

Deploy three web applications with Ingress routing based on hostnames.

```bash
cd p2
vagrant up
vagrant ssh thi-leS

# Verify deployment
kubectl get pods,svc,ingress
curl -H "Host: app1.com" http://localhost
    
curl -H "Host: app2.com" http://localhost

exit
```

**Test from host** (add to `/etc/hosts` first):

```text
192.168.56.110 app1.com app2.com app3.com
```

#### Test with curl from your Inception_Host_VM

```bash
# Test App 1
curl http://app1.com

# Test App 2
curl http://app2.com

# Test App 3 (The Ingress should use it as the default backend if no host matches)
curl http://app3.com
```


### Part 3: K3d and ArgoCD

Implement GitOps workflow with ArgoCD for continuous deployment.

```bash
cd p3
./scripts/setup_all.sh

# Get ArgoCD password
./scripts/argocd_access.sh

# Access ArgoCD UI at https://localhost:8080
# Test app: curl http://localhost:8888/
```

**GitOps Demo**: Change image tag in your GitHub repo from v1 to v2, push changes, and watch ArgoCD sync automatically.

### Bonus: GitLab Integration

Add local GitLab instance integrated with ArgoCD.

```bash
cd bonus
./scripts/setup_all.sh

# Access GitLab at http://localhost:8082
# Follow on-screen instructions to push manifests
```

## 📚 Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3d Documentation](https://k3d.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
