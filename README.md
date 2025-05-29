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

### Part 3: K3d and ArgoCD
Implement GitOps workflow with ArgoCD for continuous deployment

### Bonus: GitLab Integration
Add local GitLab instance integrated with the K3s cluster
