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

4. open vars.rc file:

        vi scripts/vars.rc

edit `spinnaker-domain` to the domain name of your company.

5. install helm client in your machine

Hop on to the helm [website](https://docs.helm.sh/using_helm/#installing-the-helm-client) and follow instructions to install the helm binary according to your CPU platform

6. install helm server(tiller) in your kubernetes cluster

        make helm

7. install spinnaker:

        make create

At this point, Spinnaker is installed but it's not exposed publicly and authentication is not enabled.
in the next part we will cover steps to expose Spinnaker with a public ip and allow authentication through google using oauth2.

8. check out the service created by helm

        kubectl get svc -n spin

note how all the services have `ClusterIP`. In order to expose spinnaker UI and spinnaker API we need to change their type to LoadBalancer. Moreover, if we want to make sure, Spinnaker will always listen on the same IP. the spinnaker installation step has reserved two static IPs `spinnaker-ui-ip` and `spinnaker-api-ip` which we will use for this purpose

9. expose the Spinnaker UI

First get the value of the reserved IP for the UI

       gcloud compute addresses describe spinnaker-ui-ip --region $REGION --format='value(address)'

edit the service as show below. Change port 80, type to `LoadBalancer` and add the `UI IP`

        kubectl edit svc spin-gate -n spin

  
        spec:
        clusterIP: 10.0.255.58
        ports:
        - port: 9000
         protocol: TCP
           targetPort: 9000
         selector:
          app: spin
           cluster: spin-deck
         sessionAffinity: None
         type: LoadBalancer  <-- change this
         loadBalancerIP: $SPINNAKER-UI-IP <-- change this
        status:
        loadBalancer: {}

9. expose the Spinnaker API
we will do the same for the API service

get the value of the reserved IP for the API

       gcloud compute addresses describe spinnaker-api-ip --region $REGION --format='value(address)'

edit the service as show below. Change port to 80, type to `LoadBalancer` and add the `API IP`

       kubectl edit svc spin-gate -n spin
    
       spec:
        clusterIP: 10.0.255.190
         ports:
         - port: 80 <--
           protocol: TCP
             targetPort: 8084
        selector:
          app: spin
            cluster: spin-gate
          sessionAffinity: None
          type: LoadBalancer <-- change this
          loadBalancerIP: $SPINNAKER-API-IP <-- change this
        status:
          loadBalancer: {}

Verify spinnaker UI is now available in the UI IP. Visit `http:/$SPINNAKER-UI-IP/

Now we need to enable authenticaton, the dashboard is exposed publicy and this is not secure

If you own a domain name go ahead and create two A records with your registrar as follows:

        A  spinnaker-api.$spinnaker-domain $SPINNAKER-API-IP
        A  pinnaker.$spinnaker-domain $SPINNAKER-UI-IP 

login to the halyard container with this command

        kubectl exec -it spin-spinnaker-halyard-0 /bin/bash

we need to tauthorize the UI and API servers to receive requests at these urls:

        hal config security ui edit \
         --override-base-url http://spinnaker.$spinnaker-domain

        hal config security api edit \
         --override-base-url http://spinnaker-api.$spinnaker-domain


Navigate to the [Google credentials manager](https://console.developers.google.com/apis/credentials), and create a new set of credentials:

Login to your project and press on `Create credentials`, choose `OAuth Client ID`.
Select Application type to `Web application`. Put a name for client. In the `Authorized redirect URIs` put  http://spinnaker-api.$spinnaker-domain/login

A screen will pop up with your new `Client ID` and `client secret`

Now go back to the terminal where you're logged in to the halyard container and run the following

        hal config security authn oauth2 edit --provider google \
         --client-id $CLIENT_ID \
         --client-secret $CLIENT_SECRET \
         --user-info-requirements hd=$spinnaker-domain

         hal config security authn oauth2 enable

Apply the configuration

         hal deploy apply


test your authentication is working by visiting the spinnaker UI http://spinnaker.$spinnaker-domain/

