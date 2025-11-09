#!/bin/bash

echo "=== EMERGENCY VM CLEANUP ==="
echo "Critical: Disk usage at 100%"
echo ""

# ================================
# 1. IMMEDIATE SPACE RECOVERY
# ================================
echo "=== 1. CLEARING LOGS (Quick Win) ==="
sudo journalctl --vacuum-time=1d
sudo journalctl --vacuum-size=100M
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.old 2>/dev/null
sudo truncate -s 0 /var/log/syslog 2>/dev/null
sudo truncate -s 0 /var/log/kern.log 2>/dev/null
sudo truncate -s 0 /var/log/auth.log 2>/dev/null

echo "After log cleanup:"
df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}'

# ================================
# 2. DOCKER CLEANUP
# ================================
echo -e "\n=== 2. DOCKER CLEANUP ==="
if command -v docker &> /dev/null; then
    echo "Removing all Docker data..."
    docker system prune -a -f --volumes 2>/dev/null || true
    docker builder prune -a -f 2>/dev/null || true
    
    # If Docker daemon is not running, clean manually
    if ! docker ps &>/dev/null; then
        echo "Docker not running, cleaning manually..."
        sudo rm -rf /var/lib/docker/overlay2/* 2>/dev/null || true
        sudo rm -rf /var/lib/docker/containers/* 2>/dev/null || true
        sudo rm -rf /var/lib/docker/image/* 2>/dev/null || true
        sudo rm -rf /var/lib/docker/volumes/* 2>/dev/null || true
    fi
fi

echo "After Docker cleanup:"
df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}'

# ================================
# 3. APT CACHE & PACKAGES
# ================================
echo -e "\n=== 3. PACKAGE CLEANUP ==="
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove --purge -y

# Remove old kernels (keep only current)
echo "Removing old kernels..."
sudo apt-get autoremove --purge -y $(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | head -n -1) 2>/dev/null || true

echo "After package cleanup:"
df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}'

# ================================
# 4. TEMPORARY FILES
# ================================
echo -e "\n=== 4. TEMPORARY FILES ==="
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null
sudo rm -rf ~/.cache/* 2>/dev/null
sudo rm -rf /root/.cache/* 2>/dev/null

echo "After temp cleanup:"
df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}'

# ================================
# 5. VAGRANT VMs
# ================================
echo -e "\n=== 5. VAGRANT CLEANUP ==="
if command -v vagrant &> /dev/null; then
    echo "Destroying all Vagrant VMs..."
    cd ~ 2>/dev/null || true
    
    # Check multiple possible locations
    for base_dir in /media/sf_iot ~/Documents/iot; do
        if [ -d "$base_dir" ]; then
            for dir in "$base_dir"/p*; do
                if [ -d "$dir/.vagrant" ]; then
                    echo "Cleaning $dir..."
                    cd "$dir"
                    vagrant destroy -f 2>/dev/null || true
                    rm -rf .vagrant
                fi
            done
        fi
    done
    
    # Clean Vagrant boxes cache
    echo "Removing Vagrant boxes..."
    vagrant box list | awk '{print $1}' | xargs -I {} vagrant box remove {} --all -f 2>/dev/null || true
fi

echo "After Vagrant cleanup:"
df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}'

# ================================
# 6. K3D CLEANUP
# ================================
echo -e "\n=== 6. K3D CLEANUP ==="
if command -v k3d &> /dev/null; then
    k3d cluster delete --all 2>/dev/null || true
fi

# ================================
# 7. KUBECTL CACHE
# ================================
echo -e "\n=== 7. KUBECTL CLEANUP ==="
rm -rf ~/.kube/cache 2>/dev/null
rm -rf ~/.kube/http-cache 2>/dev/null

# ================================
# 8. FIND LARGE FILES
# ================================
echo -e "\n=== 8. FINDING LARGEST FILES ==="
echo "Top 10 largest files:"
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $5 "\t" $9}' | sort -rh | head -10

# ================================
# 9. SYSTEM OPTIMIZATION
# ================================
echo -e "\n=== 9. FINAL OPTIMIZATION ==="
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# ================================
# FINAL STATUS
# ================================
echo -e "\n=== FINAL STATUS ==="
df -h / | head -2
echo ""
free -h | grep Mem

echo -e "\n=== CLEANUP COMPLETE ==="
echo "If disk is still >90% full, you may need to:"
echo "1. Increase VM disk size in VirtualBox"
echo "2. Remove unnecessary programs (see Set-up-VM.md)"
echo "3. Move project to external storage"
