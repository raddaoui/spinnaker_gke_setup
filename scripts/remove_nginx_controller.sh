#/bin/bash
set -x

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# use region from your current setup
export REGION=$(gcloud config get-value compute/region)

helm delete nginx-ingress --purge || echo "nginx helm chart not found" 
kubectl delete ns "${nginx_namespace}" --ignore-not-found

if [ $internal_endpoint == True ]; then
  echo "removing nginx-ingress-internal-ip"
  #gcloud -q compute addresses delete nginx-ingress-internal-ip --region $REGION || echo "ingress internal ip not found"
elif [ $internal_endpoint == False ]; then
  echo "removing nginx-ingress-external-ip"
  #gcloud -q compute addresses delete nginx-ingress-external-ip --region $REGION || echo "ingress external ip not found"
else
  echo >&2 'internal_endpoint should be True or False.. Aborting'; exit 1;
fi

