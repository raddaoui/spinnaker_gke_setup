#/bin/bash
# source: https://docs.cert-manager.io/en/latest/getting-started/install.html

set -x
set -e

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.6.6 \
  --set webhook.enabled=false \
  stable/cert-manager

# wait and verify installation
sleep 5 && kubectl get pods --namespace cert-manager

# create lets Encrypt cluster Issuer for the cluster
sed -i "s/email:.*/email: $spinnaker_domain_email/g" "${REPO_HOME}/kube_manifests/letsEncrypt-cluster-issuer.yaml"
kubectl apply -f "${REPO_HOME}/kube_manifests/letsEncrypt-cluster-issuer.yaml"
