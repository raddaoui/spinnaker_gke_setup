SHELL := /usr/bin/env bash

# google cloud project
PROJECT:=$(shell gcloud config get-value core/project)
REGION:=$(shell gcloud config get-value compute/region)
ZONE:=$(shell gcloud config get-value compute/zone)
ROOT:=.

DEBUG?=-c dbg

# enable services
.PHONY: bootstrap
bootstrap:
	gcloud services enable \
	  compute.googleapis.com \
	  container.googleapis.com \
	  cloudbuild.googleapis.com \
	  containerregistry.googleapis.com \
	  logging.googleapis.com

.PHONY: helm
helm:
	$(ROOT)/scripts/install_helm.sh

.PHONY: create
create:
	pushd $(ROOT)/scripts && ./install_spinnaker.sh && popd

.PHONY: teardown
teardown:
	pushd $(ROOT)/scripts && ./clean.sh && popd
