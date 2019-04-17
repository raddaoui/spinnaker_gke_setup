#/bin/bash

set -x
set -e

REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source the variable files
source ${REPO_HOME}/scripts/vars.rc

# use project and region from your current setup
export PROJECT=$(gcloud config get-value core/project)
export REGION=$(gcloud config get-value compute/region)

# Create a service account for spinnaker and wait for creation
gcloud iam service-accounts create  spinnaker-account \
    --display-name spinnaker-account && sleep 10

# Store the service account email address and your current project ID in environment variable
export SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:spinnaker-account" \
    --format='value(email)')

# Bind the storage.admin role to the Spinnaker service account:
gcloud projects add-iam-policy-binding \
    $PROJECT --role roles/storage.admin --member serviceAccount:$SA_EMAIL

# Download the service account key
gcloud iam service-accounts keys create /tmp/spinnaker-sa.json --iam-account $SA_EMAIL
export SA_JSON=$(cat /tmp/spinnaker-sa.json) && rm /tmp/spinnaker-sa.json

# create a GCS bucket 
export BUCKET=$PROJECT-spinnaker-config
gsutil mb -c regional -l $REGION gs://$BUCKET
export REGION=$(gcloud config get-value compute/region)

cat > "${REPO_HOME}/helm/spinnaker-config.yaml" <<EOF
gcs:
  enabled: true
  bucket: $BUCKET
  project: $PROJECT
  jsonKey: '$SA_JSON'

dockerRegistries:
- name: dockerhub
  address: index.docker.io
  repositories:
    - library/alpine
    - library/ubuntu
    - library/centos
    - library/nginx

# Disable minio as the default storage backend
minio:
  enabled: false

# Configure Spinnaker to enable GCP services
halyard:
  spinnakerVersion: $spinnaker_version
  image:
    tag: $halyard_image_tag
  additionalScripts:
    create: true
    data:
      enable_gcs_artifacts.sh: |-
        \$HAL_COMMAND config artifact gcs account add gcs-$PROJECT --json-path /opt/gcs/key.json
        \$HAL_COMMAND config artifact gcs enable

# Change this if youd like to expose Spinnaker outside the cluster
ingress:
  enabled: true
  host: spinnaker.$spinnaker_domain
  annotations:
    ingress.kubernetes.io/ssl-redirect: 'true'
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: 'true'
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
  tls:
  - secretName: spinnaker-tls-prod-cert
    hosts:
    - 'spinnaker.$spinnaker_domain'
ingressGate:
  enabled: true
  host: spinnaker-api.$spinnaker_domain
  annotations:
    ingress.kubernetes.io/ssl-redirect: 'true'
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: 'true'
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
  tls:
  - secretName: spinnaker-api-tls-prod-cert
    hosts:
    - 'spinnaker-api.$spinnaker_domain'
EOF

# Create a namespace for spinnaker
kubectl create ns spin && sleep 2
# Install Spinnaker
helm repo update
helm install -n spin stable/spinnaker --namespace spin -f "${REPO_HOME}/helm/spinnaker-config.yaml" --version "$spinnaker_helmchart_version" --timeout 600 --wait
