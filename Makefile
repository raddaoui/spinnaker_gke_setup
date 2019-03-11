SHELL := /usr/bin/env bash

# google cloud project
PROJECT:=$(shell gcloud config get-value core/project)
REGION:=$(shell gcloud config get-value compute/region)
ZONE:=$(shell gcloud config get-value compute/zone)
ROOT:=.

DEBUG?=-c dbg

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

.PHONY: nginx_controller
nginx_controller:
	$(ROOT)/scripts/install_nginx_controller.sh

.PHONY: remove_nginx_controller
remove_nginx_controller:
	$(ROOT)/scripts/remove_nginx_controller.sh

.PHONY: cert_manager
cert_manager:
	$(ROOT)/scripts/install_cert_manager.sh

.PHONY: remove_cert_manager
remove_cert_manager:
	$(ROOT)/scripts/remove_cert_manager.sh

.PHONY: spinnaker
spinnaker:
	pushd $(ROOT)/scripts && ./install_spinnaker.sh && popd

.PHONY: remove_spinnaker
remove_spinnaker:
	pushd $(ROOT)/scripts && ./remove_spinnaker.sh && popd
