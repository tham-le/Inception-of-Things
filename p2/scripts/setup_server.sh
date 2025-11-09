#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"

echo ">>> Installing K3s Server..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=${SERVER_IP}" K3S_KUBECONFIG_MODE="644" sh -s -

echo "Waiting for K3s to be ready..."
timeout=60
while ! kubectl get nodes --kubeconfig="${KUBE_CONFIG}" 2>/dev/null | grep -q "Ready"; do
    [ $timeout -le 0 ] && echo "ERROR: K3s not ready!" && exit 1
    sleep 2
    timeout=$((timeout - 2))
done

sudo cp "${KUBE_CONFIG}" /vagrant/k3s.yaml

echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

mkdir -p /home/vagrant/.kube
sudo cp "${KUBE_CONFIG}" /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
echo "alias k='kubectl'" >> /home/vagrant/.profile

echo "Deploying applications..."
kubectl apply -f /vagrant/confs/deployments.yaml --kubeconfig="${KUBE_CONFIG}"
kubectl apply -f /vagrant/confs/services.yaml --kubeconfig="${KUBE_CONFIG}"
kubectl apply -f /vagrant/confs/ingress.yaml --kubeconfig="${KUBE_CONFIG}"

echo "Waiting for deployments..."
kubectl wait --for=condition=available --timeout=120s deployment --all --kubeconfig="${KUBE_CONFIG}"

kubectl get pods,svc,ingress --kubeconfig="${KUBE_CONFIG}"
echo "Setup complete!"