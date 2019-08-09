#/bin/bash

set -x
set -e

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# use project and region from your current setup
export PROJECT=$(gcloud config get-value core/project)
export REGION=$(gcloud config get-value compute/region)

kubectl create ns "${nginx_namespace}" && sleep 2 || echo 'nginx-ingress ns exists'

# whether to deploy an internal or external nginx ingress controleller
if [ $internal_endpoint == True ]; then
  # reserve a static internal ip for the ingress controller
  gcloud compute addresses create nginx-ingress-internal-ip --region $REGION --subnet $ingress_subnet || echo "ingress internal ip already created"
  # get ingress controller ip
  ingress_controller_ip=$(gcloud compute addresses describe nginx-ingress-internal-ip --region us-east4 --format 'value(address)')
  helm install stable/nginx-ingress --name nginx-ingress-internal --namespace "${nginx_namespace}" --set controller.service.loadBalancerIP=$ingress_controller_ip --set controller.service.annotations."cloud\.google\.com/load-balancer-type"=Internal
elif [ $internal_endpoint == False ]; then
  # reserve a static external ip for the ingress controller
  gcloud compute addresses create nginx-ingress-external-ip --region $REGION || echo "ingress external ip already created"
  # get ingress controller ip
  ingress_controller_ip=$(gcloud compute addresses describe nginx-ingress-external-ip --region us-east4 --format 'value(address)')
  helm install stable/nginx-ingress --name nginx-ingress --namespace nginx-ingress --set controller.service.loadBalancerIP=$ingress_controller_ip
else
  echo >&2 'internal_endpoint should be True or False.. Aborting'; exit 1;
fi

sleep 30
POD_NAME=$(kubectl get pods -n "${nginx_namespace}" -l component=controller -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -n "${nginx_namespace}" -- /nginx-ingress-controller --version
