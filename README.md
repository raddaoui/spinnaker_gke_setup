Setup Spinnaker with oauth2 authentication on GKE
===================================================

Table of Contents
-------------------

Introduction
-------------
TODO:

Deployment steps:
------------------

1. If you don't have a kubernetes cluster installed, create one with this command:

       gcloud container node-pools create ops-cluster --num-nodes=1 --cluster example-cluster \
       --machine-type=n1-standard-8

2. get credentials for the new cluster

        gcloud container clusters get-credentials ops-cluster

3. clone this repo and move into it:

       git clone git@github.com:raddaoui/spinnaker_gke_setup.git && cd spinnaker_gke_setup

1. open vars.rc file:

        vi scripts/vars.rc

edit `spinnaker-domain` to the domain name of your company.

2. install helm client in your machine

Hop on to the helm [website](https://docs.helm.sh/using_helm/#installing-the-helm-client) and follow instructions to install the helm binary according to your CPU platform

3. install helm server(tiller) in your kubernetes cluster

        make helm

4. install spinnaker:

        make create

At this point, Spinnaker is installed but it's not exposed publicly and authentication is not enabled.
in the coming part wwe will cover steps to expose Spinnaker with a public ip and allow authentication through google.



