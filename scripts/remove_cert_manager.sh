#/bin/bash

set -x

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SA=cert-manager-cloud-dns

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# delete the cert-manager helm chart
helm delete cert-manager --purge

# Remove namespace for cert-manager
kubectl delete namespace cert-manager

# remove cert-manager CustomResourceDefinition resources
kubectl delete -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

gcloud projects remove-iam-policy-binding ${DNS_PROJECT} \
    --member=serviceAccount:${SA}@${DNS_PROJECT}.iam.gserviceaccount.com \
    --role=roles/dns.admin --quiet

gcloud iam service-accounts delete ${SA}@${DNS_PROJECT}.iam.gserviceaccount.com \
    --project=${DNS_PROJECT} --quiet


rm -rf /tmp/${SA}.key.json
