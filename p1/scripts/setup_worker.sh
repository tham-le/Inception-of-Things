#!/bin/bash
set -e

WORKER_IP="192.168.56.111"
SERVER_IP="192.168.56.110"
NODE_TOKEN_FILE="/vagrant/node-token"

echo ">>> Waiting for node token..."
timeout=120
while [ ! -f "${NODE_TOKEN_FILE}" ] && [ $timeout -gt 0 ]; do
    sleep 5
    timeout=$((timeout - 5))
done

[ ! -f "${NODE_TOKEN_FILE}" ] && echo "ERROR: Token not found!" && exit 1

K3S_TOKEN=$(cat "${NODE_TOKEN_FILE}")
[ -z "${K3S_TOKEN}" ] && echo "ERROR: Token is empty!" && exit 1

echo "Installing K3s Agent..."
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    INSTALL_K3S_EXEC="agent --node-ip=${WORKER_IP} --flannel-iface eth1" \
    sh -s -

echo "K3s Agent ready!"