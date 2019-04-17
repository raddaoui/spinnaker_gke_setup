#/bin/bash

set -x

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# delete the cert-manager helm chart
helm delete cert-manager --purge

# Remove namespace for cert-manager
kubectl delete namespace cert-manager

# remove cert-manager CustomResourceDefinition resources
kubectl delete -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml --ignore-not-found
