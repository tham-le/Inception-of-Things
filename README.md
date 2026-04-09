# Inception-of-Things

Kubernetes from the ground up: a three-part progression from bare VMs to a full GitOps pipeline with ArgoCD.

## Architecture

```
Part 1: K3s Cluster          Part 2: Ingress Routing       Part 3: GitOps with ArgoCD
┌──────────────┐             ┌──────────────┐              ┌──────────────────┐
│  Controller  │             │  K3s Server  │              │  K3d Cluster     │
│  (K3s server)│◄───────     │              │              │  ┌────────────┐  │
│  192.168.56  │  join       │  app1.com ──►│ app-one      │  │  ArgoCD    │  │
│  .110        │             │  app2.com ──►│ app-two      │  │  ┌──────┐  │  │
├──────────────┤             │  default  ──►│ app-three    │  │  │ dev  │  │  │
│  Worker      │             │  (Ingress)   │              │  │  │ ns   │  │  │
│  (K3s agent) │             └──────────────┘              │  │  └──────┘  │  │
│  192.168.56  │                                           │  └────────────┘  │
│  .111        │                                           └────────┬─────────┘
└──────────────┘                                                    │ sync
                                                           ┌───────▼─────────┐
                                                           │   GitHub repo   │
                                                           │   (manifests)   │
                                                           └─────────────────┘
```

## Parts

### Part 1 — K3s with Vagrant

Two Alpine VMs provisioned with Vagrant: a K3s server (controller) and a K3s agent (worker). Automatic cluster join via shared token.

```bash
cd p1 && vagrant up
vagrant ssh thi-leS
kubectl get nodes -o wide    # Both nodes visible
```

### Part 2 — Ingress routing

Three web applications deployed on K3s with hostname-based Ingress routing. `app1.com` and `app2.com` route to their own services; anything else falls through to `app-three` as the default backend.

```bash
cd p2 && vagrant up
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110    # → app-three (default)
```

### Part 3 — GitOps with ArgoCD

K3d cluster (K3s in Docker) with ArgoCD watching a GitHub repo. Push a manifest change → ArgoCD auto-syncs → app updates without manual `kubectl apply`.

```bash
cd p3 && ./scripts/setup_all.sh
./scripts/argocd_access.sh    # Get login credentials
# ArgoCD UI: https://localhost:8080
# App: http://localhost:8888
```

Change the image tag in your repo, push, and watch ArgoCD deploy it.

### Bonus — GitLab integration

Self-hosted GitLab instance integrated with ArgoCD. Same GitOps workflow, but with a local Git server instead of GitHub.

```bash
cd bonus && ./scripts/setup_all.sh
# GitLab: http://localhost:8082
```

## Setup

Requires a host VM with nested virtualization enabled. See [Set-up-VM.md](Set-up-VM.md) for detailed instructions.

**Dependencies:** VirtualBox, Vagrant, Docker, kubectl, K3d

## Structure

```
p1/              K3s cluster — 2 VMs, Vagrantfile + provisioning scripts
p2/              Ingress routing — 3 apps, deployments, services, ingress YAML
p3/              GitOps — K3d + ArgoCD setup scripts + application manifests
bonus/           GitLab — self-hosted Git + ArgoCD + CI pipeline
```

*42 Paris — K3s, K3d, Vagrant, ArgoCD, Docker.*
