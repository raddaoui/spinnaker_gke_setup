#/bin/bash
set -x

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# use project and region from your current setup
export PROJECT=$(gcloud config get-value core/project)
export REGION=$(gcloud config get-value compute/region)


# source: https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl create ns ingress-nginx || echo 'ingress-nginx ns exists'

# to make the nginx ingress controller use a private or a static ip, you can add a couple of annotations
# for more information on using internal and static service with gke:
# https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing
curl -o "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml" \
    https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/cloud-generic.yaml

# whether to deploy an internal or external nginx ingress controleller
if [ $internal_endpoint == True ]; then
  # reserve a static internal ip for the ingress controller
  gcloud compute addresses create nginx-ingress-internal-ip --region $REGION --subnet $ingress_subnet || echo "ingress internal ip already created"
  # get ingress controller ip
  ingress_controller_ip=$(gcloud compute addresses describe nginx-ingress-internal-ip --region us-east4 --format 'value(address)')
  awk '/namespace: ingress-nginx/{print;print "  annotations:";print "    cloud.google.com/load-balancer-type: \"Internal\"";next}1' \
      "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml" > tmp && mv tmp "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml"
elif [ $internal_endpoint == False ]; then
  # reserve a static external ip for the ingress controller
  gcloud compute addresses create nginx-ingress-external-ip --region $REGION || echo "ingress external ip already created"
  # get ingress controller ip
  ingress_controller_ip=$(gcloud compute addresses describe nginx-ingress-external-ip --region us-east4 --format 'value(address)')
else
  echo >&2 'internal_endpoint should be True or False.. Aborting'; exit 1;
fi

# edit the nginx controller manifest to listen on our reserved static ip
awk -v v="${ingress_controller_ip}" '/type: LoadBalancer/{print;print "  loadBalancerIP: "v;next}1' "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml" > tmp && mv tmp "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml"

# install the ingress controller service into the cluster
kubectl apply -f "${REPO_HOME}/kube_manifests/nginx_controller_service.yaml"

sleep 30
POD_NAMESPACE=ingress-nginx
POD_NAME=$(kubectl get pods -n $POD_NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller --version
