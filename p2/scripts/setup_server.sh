#!/bin/bash
set -e
SERVER_HOSTNAME="cqinS"
SERVER_IP="192.168.56.110"
echo ">>> Provisioning K3s Server (${SERVER_HOSTNAME}) on Alpine..."

    # Ensure sudo works for vagrant user
    if ! sudo -n true 2>/dev/null && [ -f /etc/sudoers ] && ! grep -q "vagrant ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
    echo "Adding vagrant to sudoers with NOPASSWD..."
    echo "vagrant ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    fi

    echo "Installing K3s Server..."
    # Using options from your friend's working example, plus --node-ip
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=${SERVER_IP}" K3S_KUBECONFIG_MODE="644" sh -s -
    echo "K3s server installation script finished. Waiting for services..."
    sleep 25 # Give K3s services time to start

    # Verify k3s.yaml exists and has correct permissions
    KUBE_CONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
    if [ ! -f "${KUBE_CONFIG_PATH}" ]; then
    echo "ERROR: ${KUBE_CONFIG_PATH} not found after K3s installation!"
    # Optionally, check K3s service status: rc-service k3s status
    exit 1
    fi
    # K3S_KUBECONFIG_MODE should handle this, but an explicit chmod is safe.
    sudo chmod 644 "${KUBE_CONFIG_PATH}"

    NODE_TOKEN_PATH="/var/lib/rancher/k3s/server/node-token"
    echo "Waiting for node token at ${NODE_TOKEN_PATH}..."
    TIMEOUT_SECONDS=120 # Wait for up to 2 minutes
    SECONDS_WAITED=0
    while [ ! -f "${NODE_TOKEN_PATH}" ]; do
        if [ "${SECONDS_WAITED}" -ge "${TIMEOUT_SECONDS}" ]; then
            echo "ERROR: Timed out waiting for node token!"
            # Optionally, check K3s service status here too
            exit 1
        fi
        sleep 5
        SECONDS_WAITED=$((SECONDS_WAITED + 5))
        echo "Still waiting for node token (${SECONDS_WAITED}s)..."
    done
    echo "Node token found."

    # Copy token and kubeconfig to /vagrant shared folder
    sudo cp "${NODE_TOKEN_PATH}" /vagrant/node-token
    sudo cp "${KUBE_CONFIG_PATH}" /vagrant/k3s.yaml # Save as k3s.yaml for clarity
    echo "Node token and k3s.yaml copied to /vagrant/"

    # Install kubectl binary (project requirement)
    echo "Installing kubectl binary..."
    if ! command -v kubectl &> /dev/null || ! /usr/local/bin/kubectl version --client &> /dev/null; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi

    # Setup kubectl for vagrant user
    if [ -d /home/vagrant ]; then # Vagrant user on Alpine is typically 'vagrant'
    echo "Configuring kubectl for user vagrant..."
    mkdir -p /home/vagrant/.kube
    sudo cp "${KUBE_CONFIG_PATH}" /home/vagrant/.kube/config
    sudo chown vagrant:vagrant /home/vagrant/.kube/config # Ensure correct ownership
    chmod 600 /home/vagrant/.kube/config                 # Ensure correct permissions

    # Make bash default for vagrant if installed, for .bashrc to be sourced
    if command -v bash &> /dev/null && [ "$(getent passwd vagrant | cut -d: -f7)" != "/bin/bash" ]; then
        sudo chsh -s /bin/bash vagrant
    fi
    # Add alias and completion to .bashrc (if bash is default) or .profile
    PROFILE_FILE="/home/vagrant/.bashrc"; if [ ! -f "$PROFILE_FILE" ] || [ "$(getent passwd vagrant | cut -d: -f7)" != "/bin/bash" ]; then PROFILE_FILE="/home/vagrant/.profile"; fi
    if ! grep -q "alias k=" "$PROFILE_FILE"; then
        echo "alias k='kubectl'" >> "$PROFILE_FILE"
        if command -v bash &> /dev/null; then # Completion only works with bash
        echo "source <(kubectl completion bash)" >> "$PROFILE_FILE"
        fi
    fi
    echo "kubectl configured for user vagrant."
    fi
    
    # Deploy applications
    echo "Deploying applications..."
    
    # Wait for K3s to be fully ready
    echo "Waiting for K3s to be ready..."
    while ! kubectl get nodes --kubeconfig="${KUBE_CONFIG_PATH}" 2>/dev/null | grep -q "Ready"; do
        sleep 5
        echo "Waiting for K3s cluster to be ready..."
    done
    echo "K3s cluster is ready!"
    
    # Create pods
    echo "Create pods..."
    kubectl apply -f /vagrant/confs/deployments.yaml --kubeconfig="${KUBE_CONFIG_PATH}"
    
    # Create services
    echo "Create services..."
    kubectl apply -f /vagrant/confs/services.yaml --kubeconfig="${KUBE_CONFIG_PATH}"
    
    # Deploy ingress
    echo "Deploying ingress..."
    kubectl apply -f /vagrant/confs/ingress.yaml --kubeconfig="${KUBE_CONFIG_PATH}"
    
    sleep 50
    # Show status
    echo "Checking deployment status..."
    kubectl get pods,services,ingress --kubeconfig="${KUBE_CONFIG_PATH}"
    
    echo "K3s Server provisioning complete."
