# ================================
# Install Helm
# ================================

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# create the gitlab namespace
kubectl create namespace gitlab

kubectl config set-context --current --namespace=gitlab

# ================================
# Install Gitlab via Helm chart
# ================================

helm repo add gitlab https://charts.gitlab.io
helm search repo -l gitlab/gitlab

helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --set global.hosts.domain=localhost \
  --set global.hosts.externalIP=127.0.0.1 \
  --set certmanager-issuer.email=me@example.com \
  --set postgresql.image.tag=13.6.0 \
  --set livenessProbe.initialDelaySeconds=220 \
  --set readinessProbe.initialDelaySeconds=220

# expose the gitlab frontend
kubectl port-forward services/gitlab-nginx-ingress-controller 8082:443 -n gitlab --address="0.0.0.0" 2>&1 > /var/log/gitlab-webserver.log &

# obtain the root password for login
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo

# Need to connect argoCD with gitlab
