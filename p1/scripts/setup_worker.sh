#!/bin/bash
set -e
WORKER_HOSTNAME="thi-leSW"
WORKER_IP="192.168.56.111"
SERVER_IP="192.168.56.110"

echo ">>> Provisioning K3s Agent (${WORKER_HOSTNAME}) on Alpine..."

if ! sudo -n true 2>/dev/null && [ -f /etc/sudoers ] && ! grep -q "vagrant ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
echo "Adding vagrant to sudoers with NOPASSWD..."
echo "vagrant ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
fi

NODE_TOKEN_FILE_ON_SHARED="/vagrant/node-token"
echo "Waiting for node token file at ${NODE_TOKEN_FILE_ON_SHARED}..."
TIMEOUT_SECONDS=180 # Wait for up to 3 minutes for token from server
SECONDS_WAITED=0
while [ ! -f "${NODE_TOKEN_FILE_ON_SHARED}" ]; do
    if [ "${SECONDS_WAITED}" -ge "${TIMEOUT_SECONDS}" ]; then
        echo "ERROR: Timed out waiting for node token file from server!"
        exit 1
    fi
    sleep 10 # Agent might start provisioning before server is fully done writing token
    SECONDS_WAITED=$((SECONDS_WAITED + 10))
    echo "Still waiting for node token file (${SECONDS_WAITED}s)..."
done
# Read token using sudo as it was created by root on the server, permissions on shared folder might vary
K3S_AGENT_TOKEN=$(sudo cat "${NODE_TOKEN_FILE_ON_SHARED}")
if [ -z "${K3S_AGENT_TOKEN}" ]; then
echo "ERROR: Node token file is empty!"
exit 1
fi
echo "Node token retrieved."

echo "Installing K3s Agent..."
NODE_IFACE=$(ip -o addr show | awk "/${WORKER_IP//./\\.}/{print \$2}" | head -n1)
if [ -z "${NODE_IFACE}" ]; then
    echo "ERROR: No interface found with IP ${WORKER_IP}"
    exit 1
fi
echo "Using network interface: ${NODE_IFACE}"
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="agent --node-ip=${WORKER_IP} --flannel-iface ${NODE_IFACE}" K3S_URL=https://${SERVER_IP}:6443 K3S_TOKEN="${K3S_AGENT_TOKEN}" sh -s -
echo "K3s agent installation script finished."
echo "Waiting for agent service to start..."
sleep 10
echo "K3s Agent provisioning complete."