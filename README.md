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

edit `spinnaker_domain` to the domain name of your company and `spinnaker_domain_email` to domain owner email of your company.

set a value for `internal_endpoint`
if you wish an internal_endpoint, set `ingress_subnet` to the subnet where you installed the gke cluster

5. install helm client in your machine

Hop on to the helm [website](https://docs.helm.sh/using_helm/#installing-the-helm-client) and follow instructions to install the helm binary according to your CPU platform

6. install helm server(tiller) in your kubernetes cluster

        make helm

7. install the nginx ingress controller
NOTE: we are using the nginx ingress controller since we found issues when using the gce-controller for spinnaker ingress.

        make nginx_controller

8. install cert manager:
we will use cert manager to create a certificate for Spinnaker http endpoints: the UI and the API.

        make cert_manager

9. install spinnaker:

        make spinnaker

At this point, Spinnaker is installed but it's not exposed publicly and authentication is not enabled.
in the next part we will cover steps to expose Spinnaker with a public ip and allow authentication through google using oauth2.

10. check out the service created by helm

        kubectl get svc -n spin

11. create dns records for spinnaker

This step is not included in the automation since, this depends on where you're hosting your domain

first get the spinnaker UI IP with this command

        kubectl get ingress spin-spinnaker-deck -n spin -o jsonpath='{.status.loadBalancer.ingress[0].ip}'


Now move to your resitrar and create two A records with the ip you just got as shown below:

        A  spinnaker-api.$spinnaker_domain [Spinnaker IP]
        A  spinnaker.$spinnaker_domain [Spinnaker IP] 

12. verify you can login to the spinnaker UI

Wait some minutes for the DNS records to take effect and login to the spinnaker UI using the its domain name: `spinnaker.$spinnaker_domain` 

13. enable authentication to Spinnaker

As you can see Spinnaker is now deployed but its open to public.
To enable authentication, we will use OAUTH2 with Google endpoints to offload authenication to Google

login to the halyard container with this command

        kubectl exec -it spin-spinnaker-halyard-0 /bin/bash -n spin

we need to tauthorize the UI and API servers to receive requests at these urls:

        spinnaker_domain=[put domain here]
        hal config security ui edit \
         --override-base-url https://spinnaker.$spinnaker_domain

        hal config security api edit \
         --override-base-url https://spinnaker-api.$spinnaker_domain


Navigate to the [Google credentials manager](https://console.developers.google.com/apis/credentials), and create a new set of credentials:

Login to your project and press on `Create credentials`, choose `OAuth Client ID`.
Select Application type to `Web application`. Put a name for client. In the `Authorized redirect URIs` put  https://spinnaker-api.$spinnaker_domain/login

A screen will pop up with your new `Client ID` and `client secret`

Now go back to the terminal where you're logged in to the halyard container and run the following

	CLIENT_ID=[put client ID here]
	CLIENT_SECRET=[put client secret]
        hal config security authn oauth2 edit --provider google \
         --client-id $CLIENT_ID \
         --client-secret $CLIENT_SECRET \
         --user-info-requirements hd=${spinnaker_domain#*.}

         hal config security authn oauth2 enable

NOTE: any user which satisfy `user-info-requirements` is authorized to access the UI. Here, authorization is restrited to authenticated users with emails belonging to the root domain of Spinnaker.

Apply the configuration

         hal deploy apply


test your authentication is working by visiting the spinnaker UI https://spinnaker.$spinnaker_domain/


Cleanup:

        make remove_spinnaker
        make remove_cert_manager
        make remove_nginx_controller 
