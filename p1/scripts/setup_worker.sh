#!/bin/bash

echo "Setting up the worker node..."
sudo apt update && sudo apt install -y curl
# Install k3s agent
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<token> sh -
echo "K3s agent installed successfully."
# Enable k3s service
sudo systemctl enable k3s-agent
# Start k3s service
sudo systemctl start k3s-agent
# Check k3s status
sudo systemctl status k3s-agent
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
echo "kubectl installed successfully."