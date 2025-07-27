#!/bin/bash

namespace=$1
if [ -z "$namespace" ]; then
  echo "Using default namespace 'theia-prod'."
  namespace="theia-prod"
fi

helm repo add theia-cloud-repo https://eclipse-theia.github.io/theia-cloud-helm/
helm repo update

helm upgrade theia-cloud-base theia-cloud-repo/theia-cloud-base --install -f theia-base-helm-values.yml
helm upgrade theia-cloud-crds theia-cloud-repo/theia-cloud-crds --install -f theia-crds-helm-values.yml

helm upgrade theia-cloud theia-cloud-repo/theia-cloud --install --namespace $namespace -f theia-cloud-helm-values.yml

helm upgrade theia-appdefinitions -f theia-appdefinitions/values.yml --install ./theia-appdefinitions