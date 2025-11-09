#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
KUBE_CONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
NODE_TOKEN_PATH="/var/lib/rancher/k3s/server/node-token"

echo ">>> Installing K3s Server..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=${SERVER_IP}" K3S_KUBECONFIG_MODE="644" sh -s -

echo "Waiting for K3s files..."
timeout=60
while [ ! -f "${NODE_TOKEN_PATH}" ] && [ $timeout -gt 0 ]; do
    sleep 2
    timeout=$((timeout - 2))
done

[ ! -f "${NODE_TOKEN_PATH}" ] && echo "ERROR: Node token not found!" && exit 1

sudo cp "${NODE_TOKEN_PATH}" /vagrant/node-token
sudo cp "${KUBE_CONFIG_PATH}" /vagrant/k3s.yaml

echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

mkdir -p /home/vagrant/.kube
sudo cp "${KUBE_CONFIG_PATH}" /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

echo "alias k='kubectl'" >> /home/vagrant/.profile
echo "K3s Server ready!"