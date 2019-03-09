#/bin/bash
set -x

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# source the variable files
source ${REPO_HOME}/scripts/vars.rc

kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl delete -f "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml"
kubectl delete ns ingress-nginx --ignore-not-found
rm -f "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml"

if [ $internal_endpoint == True ]; then
  echo "removing nginx-ingress-internal-ip"
  #gcloud compute addresses delete nginx-ingress-internal-ip --region $REGION || echo "ingress internal ip not found"
elif [ $internal_endpoint == False ]; then
  echo "removing nginx-ingress-external-ip"
  #gcloud compute addresses delete nginx-ingress-external-ip --region $REGION || echo "ingress external ip not found"
else
  echo >&2 'internal_endpoint should be True or False.. Aborting'; exit 1;
fi

