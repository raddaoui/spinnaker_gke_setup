Continious delivery with Spinnaker
===================================

If you have followed the README in this repo, you will end up with a Spinnaker instance running on gke where 
- UI is exposed on https://spinnaker.`$spinnaker_domain`
- API is exposed on https://spinnaker-api.`$spinnaker_domain`
- Spinnaker has only default kubernetes account configured which is same gke cluster where Spinnaker is running.

this is all nice and helpful but how can I start using spinnaker to deploy my application to my different gke clusters(staging, production..) and create pipelines to test and automate CD workflows.

a simple workflow in spinnaker would be:

1- an update to kubernetes manifests stored in github would trigger a deploy pipeline to a staging cluster. This is done using github webhook which will notify Spinnaker of changes made to the manifests and spinnaker in turn will get the updated manifests and apply them to the cluster.

2- a new binary image pushed to a docker registry(dockerhub, gcr) would trigger the same deploy to stage pipeline which will update the application imaged used in stage. This will also require setting up a webhook in your docker registry to notify spinnaker of the new image.

3- once the "deploy to stage" pipeline finish successfully, this should trigger another pipeline which should perform functional testing and possibly a manual judgment where an operator can do more verification on the updated application in Stage.

4- if the testing pipeline finish successfully, this will trigger a "Deploy to production" pipeline.

In this document, we will focus only on creating the first pipeline which can be used as an example to complete the rest:

a rundown of the steps we will follow is listed below

- add an artifact account for dockerhub to use images stored in the repository and setup webhook to get notified when new images are pushed.
- add an artifact account for github to start deploying kubernetes manifests stored there and setup webhook to get notified when changes are made to the manifests.
- add a kubernetes account to use it to deploy to staging cluster.
- setup the spin client to start interacting with spinnaker using the CLI.
- create a spinnaker application for our example microservice.
- create a spinnaker pipeline which will deploy an application using the github and docker artifact accounts into the kubernetes cluster using the kubernetes account.

before we start, login to the halyard container:

      kubectl exec -it spin-spinnaker-halyard-0 /bin/bash -n spin


## Step1: add spinnaker artifact account for dockerhub and set dockerhub webhook
from the halyard container, run the following:

`NOTE:` you will be prompted to enter your dockerhub password

    ADDRESS=index.docker.io # change to your docker registry url if not using docker hub
    REPOSITORIES="raddaoui/sampleapp" # change to the list of repositories you will use for your application
    USERNAME=raddaoui # change to your dockerhub username
    EMAIL=raddaoui@mail.com # change to your dockerhub email

    hal config provider docker-registry account add
        my-docker-registry \
        --address $ADDRESS \
        --repositories $REPOSITORIES \
        --username $USERNAME \
        --email $USERNAME \
        --password

Now allow docker hub to post build events to spinnaker

First, login to your dockerhub account. Then for every repository you selected above, press on the webhooks tab 
and add a webhook. Put a name and set the webhok URL to `https://spinnaker-api.$spinnaker_domain/webhooks/webhook/dockerhub`

## Step2: add artifact account for github and set github webhook

in order for spinnaker to download files from GitHub.
we need to generate an access token from a Github account that is able to access the code. It's advised to create the token from a cicd Github bot account rather than your persnal account. To create the token, login to the bot github account and go to settings. Then press on Developper settings. Click on Personal access tokens and then press on Generate new token:

For description, put spinnaker-gke-access, select the repo scope and press Generate token. make note of the token, we will be using it next.

from the halyard container:

    TOKEN_FILE=/tmp/spinnaker-github-token
    echo "[PUT TOKEN HERE]" > $TOKEN_FILE

    ARTIFACT_ACCOUNT_NAME=my-github-artifact-account
    hal config features edit --artifacts true
    hal config artifact github enable
    hal config artifact github account add $ARTIFACT_ACCOUNT_NAME \
      --token-file $TOKEN_FILE

## Step3: add a kubernetes account for the staging cluster

in order to do that, we need to prepare a kubeconfig with valid config to access the staging cluster

make sure you're poinging to the stage cluster and can issue api requests there. If not, this command should get you a new kube config file.

    gcloud container clusters get-credentials [staging cluster name] --zone [staging cluster zone] --project [staging gcp project id]

Now, we will make spinnaker communicate with the staging cluster through a service account.

Start by creating the service account and giving it edit role:

    kubectl create sa spinnaker-service-account -n default
    kubectl create clusterrolebinding --user \
      system:serviceaccount:default:spinnaker-service-account spinnaker --clusterrole edit

get the service account token and change our kube config file to use that

    SERVICE_ACCOUNT_TOKEN=`kubectl get serviceaccounts spinnaker-service-account -o jsonpath='{.secrets[0].name}'`
    
    secret=`kubectl get secret $SERVICE_ACCOUNT_TOKEN -o jsonpath='{.data.token}' | base64 --decode`

    TEST_USER_PROFILE=`kubectl config current-context`
    kubectl config set-credentials $TEST_USER_PROFILE --token $secret

Now open the kube config under ~/.kube/config and remove any authentication part left over from the user authentication.
at the end your kubeconfig skeleton should look like this.

`NOTE:` make sure to remove the `current-context` line as well.

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: 
        server: 
      name:
    contexts:
    - context:
        cluster: 
        user: 
      name: CONTEXT_NAME
    kind: Config
    preferences: {}
    users:
    - name: 
      user:
        token:

Copy the resulted config. Move to the halyard container and paste it to ~/.kube/config

Now, we are ready to add the kubernetes account for the staging cluster and deploy all the changes in spinnaker

    hal config provider kubernetes account add stage-account --docker-registries my-docker-registry --context [CONTEXT_NAME] --provider-version v2 --skin v2 --omit-namespaces="kube-system,kube-public"

    hal deploy apply


## Step4: setup the spin client

to enable authentication with Spin client using oauth2 with Google, you can do it either by specifying a Client ID and a client secret which you can get by creating a new GCP oauth client in your GCP project [here](https://console.cloud.google.com/apis/credentials) or by specifying an Access and Refresh token.

here we will be following the second option

First authenticate with Google via `gcloud auth login`.

Use the following commands to acquire the tokens:

```
ACCESS_TOKEN=$(gcloud auth print-access-token)
REFRESH_TOKEN=$(gcloud auth print-refresh-token)
```
Second, download the spin client binary by following direction from this [link](https://www.spinnaker.io/guides/spin/cli/)

Finally, create a spin config file which will hold information on how to reach the gate and how to authenticate with GCP.

    spinnaker_domain=[put spinnaker domain here]
    cat << EOF > ~/.spin/config
    gate:
      endpoint: https://spinnaker-api.$spinnaker_domain
    auth:
      enabled: true
      oauth2:
        tokenUrl: https://www.googleapis.com/oauth2/v4/token
        authUrl: https://accounts.google.com/o/oauth2/auth
        scopes:
        - email
        - profile
        - openid
        cachedToken:
          accesstoken: $ACCESS_TOKEN
          refreshtoken: $REFRESH_TOKEN
    EOF

now spin is installed and configured to talk to the spinnaker api. execute the below command to make sure everyting is working.

    spin applications list


## Step 5: create a spinnaker application 

Spinnaker recommends creating one application per microservice of your app. Let's suppose we have an application called `sampelapp`.
to create the application using spin, execute this:

    spin application save --application-name sampelapp --owner-email 'help@$spinnaker_domain' --cloud-providers kubernetes


## Step 6: create a spinnaker pipeline 

The easiest way to create a pipeline is to build it first using the UI, test it then use the spin client to get the json definition of the pipeline. once you have that you can templatize the template using your best templating language. Also there's MPT v2 on the way but its still in the alpha release and not well documented.

For our case we created a sample pipeline template to deploy a folder of k8s manifests to a kubernetes account. the pipeline has also all the webhooks and the expected artifacts configurable.

Feel free to drop a look of the pipeline under `spinnaker_templates/deploy_manifests_pipline.json`

Now let's create a copy of the template, configure it and save it to spinnaker

    cp spinnaker_templates/deploy_manifests_pipeline_template.json spinnaker_templates/deploy_manifests_pipeline.json 

    APPLICATION=sampelapp
    FOLDER_PATH=[PUT FOLDER PATH HERE] # for folder path specify your application manifests path from the repository root
    DOCKER_IMAGE=index.docker.io/raddaoui/sampleapp # specify your application docker image
    GITHUB_ARTIFACT_ACCOUNT=my-github-artifact-account
    GITHUB_PROJECT=raddaoui  # if your github repo name is raddaoui/sampleapp, then GITHUB_PROJECT=raddaoui
    GITHUB_REPO=sampleapp    # if your github repo name is raddaoui/sampleapp, then GITHUB_REPO=sampleapp
    GITHUB_WEBHOOK_SECRET=[put your GITHUB WEBHOOK SECRET]

    sed -i "s/APPLICATION/$APPLICATION/g" spinnaker_templates/deploy_manifests_pipeline.json
    sed -i "s#FOLDER_PATH#$FOLDER_PATH#g" spinnaker_templates/deploy_manifests_pipeline.json
    sed -i "s#DOCKER_IMAGE#$DOCKER_IMAGE#g" spinnaker_templates/deploy_manifests_pipeline.json
    sed -i "s/GITHUB_ARTIFACT_ACCOUNT/$GITHUB_ARTIFACT_ACCOUNT/g" spinnaker_templates/deploy_manifests_pipeline.json
    sed -i "s/GITHUB_PROJECT/$GITHUB_PROJECT/g" spinnaker_templates/deploy_manifests_pipeline.json
    sed -i "s/GITHUB_REPO/$GITHUB_REPO/g" spinnaker_templates/deploy_manifests_pipeline.json 
    sed -i "s/GITHUB_WEBHOOK_SECRET/$GITHUB_WEBHOOK_SECRET/g" spinnaker_templates/deploy_manifests_pipeline.json


Now its time to create the pipline in spinnaker and trigger it.

    spin pipeline save -f spinnaker_templates/deploy_manifests_pipeline.json

