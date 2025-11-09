#!/bin/bash

echo "=== VM CLEANUP & OPTIMIZATION SCRIPT ==="

# ================================
# Check current state
# ================================
echo -e "\n=== INITIAL STATE ==="
echo "Memory:"
free -h
echo -e "\nDisk space:"
df -h / | head -2

# ================================
# 1. Docker Cleanup
# ================================
echo -e "\n=== 2. DOCKER CLEANUP ==="
if command -v docker &> /dev/null; then
    echo "Stopping containers..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    echo "Removing containers..."
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    echo "Removing unused images..."
    docker image prune -a -f
    
    echo "Removing volumes..."
    docker volume prune -f
    
    echo "Removing networks..."
    docker network prune -f
    
    echo "Removing build cache..."
    docker builder prune -a -f
    
    echo "Complete Docker system cleanup..."
    docker system prune -a -f --volumes
fi

# ================================
# 2. System Cleanup
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
# 3. Remove non-essential programs
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
# 4. Memory optimization
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
