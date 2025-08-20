#!/bin/bash

namespace=$1
if [ -z "$namespace" ]; then
  echo "Using default namespace 'theia-prod'."
  namespace="theia-prod"
fi

helm dependency update ./charts/tum-theia-cloud

helm upgrade theia-cloud-base theia-cloud-repo/theia-cloud-base --install -f theia-base-helm-values.yml
helm upgrade theia-cloud-crds theia-cloud-repo/theia-cloud-crds --install -f theia-crds-helm-values.yml

# this installs the latest version of theia-cloud, theia-appdefinitions and theia-certificates
helm upgrade --install tum-theia-cloud ./charts/tum-theia-cloud --namespace $namespace --create-namespace \
  --theia-certificates.wildcardCertificate="$(cat ./prod/wildcard-webview-cert/wildcard_webview_instance_theia_artemis_cit_tum_de.pem)" \
  --theia-certificates.wildcardKey="$(cat ./prod/wildcard-webview-cert/wildcard_webview_instance_theia_artemis_cit_tum_de.key)"