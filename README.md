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
#### Step 1: Build

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

at the end

```bash
cd /media/sf_iot/p1
vagrant destroy -f
```

### Part 2: K3s and Three Simple Applications  
Deploy three web applications with Ingress routing based on hostnames
#### Step 1: Build

```bash
cd /media/sf_iot/p2
vagrant destroy -f
vagrant up
```

#### Step 2: Verify the Deployment (Inside the VM created by Vagrant)

```bash
vagrant ssh thi-leS
k get pods
k get svc
k get ingress #check the status of everythig deployed

    
curl -H "Host: app1.com" http://localhost
    
curl -H "Host: app2.com" http://localhost

exit
```

for the result:

    Pods: app-one-... (1/1 Ready), app-three-... (1/1 Ready), and three app-two-... pods (all 1/1 Ready).

    Services: app-one, app-two, app-three should exist.

    Ingress: ingress resource should be present and, crucially, the ADDRESS column should show the server's IP (192.168.56.110) or localhost.
#### Step 3: Test Externally (In the Host VM,  NOT inside the Vagrant VM )


**Set up step**: this can be done before the correction
```bash
sudo nano /etc/hosts
#Add the following lines at the end of the file and save it
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 app3.com
```
**Test with curl from your Inception_Host_VM**

```bash
# Test App 1
curl http://app1.com

# Test App 2
curl http://app2.com

# Test App 3 (The Ingress should use it as the default backend if no host matches)
curl http://app3.com
```


### Part 3: K3d and ArgoCD
Implement GitOps workflow with ArgoCD for continuous deployment


#### **Step 1:**

    ```bash
    cd /media/sf_iot/p3
    k3d cluster delete mycluster
    ```
**Deploy the Cluster & ArgoCD:**
    ```bash
    chmod +x scripts/setup_all.sh
    ./scripts/setup_all.sh
    ```

#### **Step 2: Local Configuration**
*(In**school computer**)*

1.  **Find your Host VM's IP Address:**
    *   On the `Inception_Host_VM`, run `ip a` and find the IP on the `192.168.57.x` network (e.g., `192.168.57.101`). This is `<HOST_VM_IP>`.

2.  **Create SSH Tunnel for ArgoCD UI:**
    *   Open a new terminal on your school computer and run:
        ```bash
        ssh -L 8080:localhost:8080 user@<HOST_VM_IP>
        ```
    *   *Keep this terminal open for the entire test.*

3.  **Configure Firefox for Application Access:**
    *   Open Firefox. In the address bar, type `about:config` and press Enter.
    *   type `network.dns.forceResolve`.
    *   Enter  `<HOST_VM_IP>` as the value and save.


#### **Step 3: Initial Verification**
*(Use the configured Firefox browser on your **school computer**)*

1.  **Verify ArgoCD UI:**
    *   Go to `https://localhost:8080`.
    *   Accept the security warning.
    *   Log in with `admin` and the password from `./scripts/argocd_access.sh` (run on the VM).
    *   **Expected Result:** The status must be **Healthy** and **Synced**.

2.  **Verify Application v1:**
    *    `curl http://localhost:8888/`.
    *   **Expected Result:**  JSON response: `{"status":"ok", "message": "v1"}`.

---

#### **Step 4: GitOps Workflow Demonstration**

1.  **Modify Code:**
    *   In Git repository, edit the file `p3/confs/app/deployment.yaml`.
    *   Change the image tag from `...:v1` to `...:v2`.

2.  **Push to GitHub:**
    ```bash
    git add .
    git commit -m "Upgrade application to v2"
    git push
    ```

3.  **Observe in ArgoCD:**
    *   Switch back to the ArgoCD UI tab (`https://localhost:8080`).
    *   Click **Refresh**. The status will change to **`OutOfSync`**.
    *   Click **Sync** to apply the change immediately.
    *   Wait for the status to become **Healthy** and **Synced** again.

4.  **Verify Final Result:**
    *  ` curl http://localhost:8888/`
    *   **Expected Result:** The JSON response now shows: `{"status":"ok", "message": "v2"}`.

---

#### **Phase 5: Cleanup **

1.  **Reset Firefox Configuration:**
    *   On your school computer, go back to `about:config` in Firefox.
    *   Search for `network.dns.forceResolve`.
    *   Click the **trash can icon** (🗑️) to delete the key and restore normal browser behavior.

### Bonus: GitLab Integration
Add local GitLab instance integrated with the K3s cluster
