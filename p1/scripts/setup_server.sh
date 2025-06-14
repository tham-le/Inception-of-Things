#!/bin/bash

echo "Setting up the server..."
sudo apt update && sudo apt install -y curl
# Install k3s
curl -sfL https://get.k3s.io | sh -
echo "K3s installed successfully."
# Enable k3s service
sudo systemctl enable k3s
# Start k3s service
sudo systemctl start k3s
# Check k3s status
sudo systemctl status k3s
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
echo "kubectl installed successfully."