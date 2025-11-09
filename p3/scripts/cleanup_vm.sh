#!/bin/bash

echo "=== VM CLEANUP & OPTIMIZATION SCRIPT ==="
echo "This will remove:"
echo "  - ArgoCD Application 'wil42'"
echo "  - Namespace 'dev' and its pods"
echo ""
echo "This will KEEP:"
echo "  - k3d cluster 'mycluster'"
echo "  - ArgoCD installation"
echo ""

# ================================
# Check current state
# ================================
echo -e "\n=== INITIAL STATE ==="
echo "Memory:"
free -h
echo -e "\nDisk space:"
df -h / | head -2

# ================================
# 1. Delete P3 ArgoCD application
# ================================
echo "Deleting P3 ArgoCD application 'wil42'..."
if kubectl get application wil42 -n argocd &>/dev/null; then
    kubectl delete application wil42 -n argocd --timeout=30s
    echo "[OK] ArgoCD application 'wil42' deleted"
else
    echo "[INFO] ArgoCD application 'wil42' not found"
fi

# ================================
# 2. Delete dev namespace
# ================================
echo "Deleting dev namespace..."
if kubectl get namespace dev &>/dev/null; then
    kubectl delete namespace dev --timeout=60s
    echo "[OK] Dev namespace deleted"
else
    echo "[INFO] Dev namespace not found"
fi

# ================================
# 3. Docker Cleanup
# ================================
echo -e "\n=== 3. DOCKER CLEANUP (KEEPING K3D) ==="
if command -v docker &> /dev/null; then
    echo "Cleaning unused Docker resources (keeping k3d cluster)..."
    
    # Only remove stopped containers (won't touch running k3d containers)
    echo "Removing stopped containers..."
    docker container prune -f
    
    # Remove dangling images only (not used by any container)
    echo "Removing dangling images..."
    docker image prune -f
    
    # Remove unused volumes (be careful - add --all to remove all unused)
    echo "Removing unused volumes..."
    docker volume prune -f
    
    # Remove unused networks (won't remove k3d networks in use)
    echo "Removing unused networks..."
    docker network prune -f
    
    # Remove build cache
    echo "Removing build cache..."
    docker builder prune -f
    
    echo "[OK] Docker cleanup completed (k3d cluster preserved)"
else
    echo "[INFO] Docker not found"
fi

# ================================
# 4. System Cleanup
# ================================
echo -e "\n=== 4. SYSTEM CLEANUP ==="

# Packages
echo "Cleaning packages..."
sudo apt-get autoremove --purge -y 2>/dev/null || true
sudo apt-get autoclean -y 2>/dev/null || true
sudo apt-get clean -y 2>/dev/null || true

# Logs
echo "Cleaning logs..."
sudo journalctl --vacuum-time=1d
sudo rm -rf /var/log/*.log.* 2>/dev/null || true
sudo rm -rf /var/log/*/*.log.* 2>/dev/null || true

# Temporary files
echo "Cleaning temporary files..."
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
sudo rm -rf ~/.cache/* 2>/dev/null || true

# Kubernetes cache
echo "Cleaning kubectl cache..."
rm -rf ~/.kube/cache 2>/dev/null || true

# Old kernels (keep current + 1)
echo "Removing old kernels..."
sudo apt-get autoremove --purge -y $(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | head -n -1) 2>/dev/null || true

# ================================
# 5. Remove non-essential programs
# ================================
echo -e "\n=== 5. REMOVING NON-ESSENTIAL PROGRAMS ==="

# List of programs often installed but not necessary for K8s
programs_to_remove="
    thunderbird
    libreoffice*
    firefox
    games-*
    aisleriot
    gnome-mahjongg
    gnome-mines
    gnome-sudoku
    remmina
    transmission-*
    rhythmbox
    totem
    cheese
    shotwell
    simple-scan
"

for program in $programs_to_remove; do
    if dpkg -l | grep -q "^ii.*$program"; then
        echo "Removing $program..."
        sudo apt-get remove --purge -y $program 2>/dev/null || true
    fi
done

# ================================
# 6. Memory optimization
# ================================
echo -e "\n=== 6. MEMORY OPTIMIZATION ==="

# Clear caches
echo "Clearing system caches..."
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# Swap optimization
echo "Optimizing swap settings..."
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf 2>/dev/null || true
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf 2>/dev/null || true

# ================================
# 7. Verify cluster and ArgoCD
# ================================
echo -e "\n=== 7. VERIFICATION ==="
echo "Checking k3d cluster..."
if k3d cluster list | grep -q "mycluster.*running"; then
    echo "[OK] k3d cluster 'mycluster' is running"
else
    echo "[WARNING] k3d cluster 'mycluster' not found or not running"
fi

echo "Checking ArgoCD pods..."
if kubectl get pods -n argocd | grep -q "Running"; then
    echo "[OK] ArgoCD pods are running"
    kubectl get pods -n argocd
else
    echo "[WARNING] ArgoCD pods may not be running properly"
fi
# ================================
# Final state
# ================================
echo -e "\n=== FINAL STATE ==="
echo "Memory:"
free -h
echo -e "\nDisk space:"
df -h / | head -2
echo -e "\nTop memory consuming processes:"
ps aux --sort=-%mem | head -10

echo -e "\n Cleanup completed!"
echo "You can now restart your setup_all.sh script"
