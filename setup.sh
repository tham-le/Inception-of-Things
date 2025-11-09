#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--------------------------------------------------------------------"
echo "Starting provisioning of Inception Host VM..."
echo "--------------------------------------------------------------------"
date

# --- System Update and Basic Utilities ---
echo ">>> Updating package lists and installing basic utilities..."
export DEBIAN_FRONTEND=noninteractive # Prevents interactive prompts during apt installs
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    git \
    nano \
    unzip \
    build-essential \
    linux-headers-$(uname -r) \
    dkms

# --- Install VirtualBox (for inner Vagrant VMs) ---
# Using the version from Ubuntu's repositories for simplicity here.
# For the absolute latest, you'd add Oracle's repo.
echo ">>> Installing VirtualBox..."
# Ensure old versions are removed if any
sudo apt-get remove -y virtualbox virtualbox-ext-pack virtualbox-dkms
# Install VirtualBox and Extension Pack (Extension pack provides USB 2.0/3.0, etc.)
# Note: The version of virtualbox in standard Ubuntu repos might be slightly older.
# For latest, see: https://www.virtualbox.org/wiki/Linux_Downloads
sudo apt-get install -y virtualbox virtualbox-dkms

echo "VirtualBox version:"
vboxmanage --version || echo "VirtualBox not found or failed to get version."

# --- Install Vagrant ---
echo ">>> Installing Vagrant..."
# Get the latest Vagrant version
VAGRANT_VERSION="2.4.1" # Check for the latest stable version on releases.hashicorp.com
VAGRANT_VERSION_SUFFIX="${VAGRANT_VERSION}-1" # If version includes the suffix
VAGRANT_DEB="vagrant_${VAGRANT_VERSION_SUFFIX}_amd64.deb"
DEB_PATH="/tmp/${VAGRANT_DEB}"
if [ ! -f "$DEB_PATH" ]; then
  echo "Downloading Vagrant $VAGRANT_VERSION..."
  wget "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/${VAGRANT_DEB}" -O "$DEB_PATH"
else
  echo "Vagrant .deb already exists at $DEB_PATH, skipping download."
fi
sudo dpkg -i "$DEB_PATH" || sudo apt-get install -f -y # Install the .deb
rm -f "$DEB_PATH"
echo "Vagrant version:"
vagrant --version

# --- Install Docker ---
echo ">>> Installing Docker..."
if command -v docker &> /dev/null; then
  echo "Docker is already installed: $(docker --version)"
else
  echo "Docker not found, installing..."
  # Add Docker's official GPG key (only if missing):
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi
  # Add the repository to Apt sources (only if missing):
  if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
echo "Docker version:"
docker --version

# --- Install kubectl ---
echo ">>> Installing kubectl..."
if command -v kubectl &> /dev/null; then
  echo "kubectl is already installed: $(kubectl version)"
else
  echo "Downloading latest stable kubectl..."
  KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  if [ -f kubectl ]; then
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
  else
    echo "Failed to download kubectl!"
    exit 1
  fi
fi
echo "kubectl version:"
kubectl version --client --output=yaml # Use yaml to avoid server connection attempt

# --- Install k3d ---
echo ">>> Installing k3d..."
if command -v k3d &> /dev/null; then
  echo "k3d is already installed: $(k3d version)"
else
  echo "Downloading latest stable k3d..."
  # Using wget for better error handling in scripts
  wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi
echo "k3d version:"
k3d version

# --- Install cpu-checker (to verify nested virtualization) ---
echo ">>> Installing cpu-checker..."
sudo apt-get install -y cpu-checker

# --- Add vagrant user to necessary groups ---
echo ">>> Adding 'vagrant' user to 'docker' and 'vboxusers' groups..."
sudo usermod -aG docker vagrant
sudo usermod -aG vboxusers vagrant
# Note: For group changes to take effect, the user 'vagrant' would typically need to log out and log back in.
# When vagrant provision runs, this script runs as root or vagrant with sudo,
# but for subsequent `vagrant ssh` sessions and manual commands as 'vagrant', this is important.

# --- Final Checks (Optional, for logging) ---
echo ">>> Verifying nested virtualization support (kvm-ok)..."
# This will run after a reboot if needed for kernel modules, or directly.
# The actual check should be done after `vagrant up` completes and you SSH in.
kvm-ok || echo "kvm-ok check failed or requires reboot/further setup. Check after 'vagrant up' completes and you SSH in."

echo "--------------------------------------------------------------------"
echo "Provisioning of Inception Host VM completed."
echo "You may need to 'vagrant reload' or logout/login for group changes (docker, vboxusers) to fully apply for the 'vagrant' user's session."
echo "After 'vagrant up' finishes, SSH into the VM ('vagrant ssh' or 'ssh -p 2222 vagrant@localhost')"
echo "and run 'kvm-ok' to confirm nested virtualization."
echo "--------------------------------------------------------------------"
date