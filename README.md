# Inception-of-Things (IoT)

A System Administration project focused on learning Kubernetes fundamentals using K3s, K3d, Vagrant, and ArgoCD.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Parts Overview](#parts-overview)
- [Installation & Setup](#installation--setup)
- [Part 1: K3s and Vagrant](#part-1-k3s-and-vagrant)
- [Part 2: K3s and Three Simple Applications](#part-2-k3s-and-three-simple-applications)
- [Part 3: K3d and ArgoCD](#part-3-k3d-and-argocd)
- [Bonus: GitLab Integration](#bonus-gitlab-integration)
- [Evaluation](#evaluation)
- [Resources](#resources)

## 🎯 Overview

This project introduces Kubernetes concepts through practical implementation using:
- **K3s**: Lightweight Kubernetes distribution
- **K3d**: K3s in Docker for local development
- **Vagrant**: Virtual machine management
- **ArgoCD**: GitOps continuous deployment tool

The project is structured in three mandatory parts plus an optional bonus section.

## 🔧 Prerequisites

- Virtual machine environment
- Basic understanding of:
  - Linux system administration
  - Containerization concepts
  - Git/GitHub
- Required tools (will be installed during setup):
  - Vagrant
  - VirtualBox (or chosen provider)
  - Docker
  - kubectl
  - K3s/K3d

## 📁 Project Structure

```
inception-of-things/
├── p1/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p2/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p3/
│   ├── scripts/
│   └── confs/
└── bonus/ (optional)
    ├── scripts/
    └── confs/
```

## 🚀 Parts Overview

### Part 1: K3s and Vagrant
Set up two virtual machines with K3s cluster (controller + worker node)


### Part 2: K3s and Three Simple Applications  
Deploy three web applications with Ingress routing based on hostnames
#### Step 1: How to Test

```bash
cd /media/sf_iot/p1
vagrant destroy -f
vagrant up
```

#### Step 2: Verify SSH Access and Machine Configurations

##### Test for Server
```bash
vagrant ssh thi-leS
hostname
# Expected Output: thi-leS

# Check the IP address
ip a show eth1
# Expected Output: inet 192.168.56.110/24..."

# get the status of the cluster nodes
kubectl get nodes -o wide

# Expected Output: 
# The thi-leS node should have control-plane,master in its ROLES.
# The thi-leSW node should have <none> in its ROLES.
# The INTERNAL-IP column should match the required IPs (192.168.56.110 and 192.168.56.111).
#Kubernetes normalizes all Node names to be lowercase

exit
```

##### Test for  Worker
```bash
vagrant ssh thi-leSW
hostname
# Expected Output: thi-leSW

# Check the IP address
ip a show eth1
# Expected Output:  "inet 192.168.56.111/24..."

# Exit the worker
exit
```

### Part 3: K3d and ArgoCD
Implement GitOps workflow with ArgoCD for continuous deployment

### Bonus: GitLab Integration
Add local GitLab instance integrated with the K3s cluster
