# Theia Deployment

## Install Theia Cloud

Make sure to set the namespace to your desired location first. For production, we use `theia-prod`. 

```bash
helm repo add theia-cloud-repo https://eclipse-theia.github.io/theia-cloud-helm/
helm repo update

helm upgrade theia-cloud-base theia-cloud-repo/theia-cloud-base --install -f theia-base-helm-values.yml

helm upgrade theia-cloud-crds theia-cloud-repo/theia-cloud-crds --install -f theia-crds-helm-values.yml

helm upgrade --install tum-theia-cloud ./tum-theia-cloud --namespace your-namespace --create-namespace
```

### Installing the Theia Cloud Test Operator
To install the theia cloud test operator, we use the specific yaml file. For other environments, it makes sense to also create a new values file.
```bash
helm upgrade --install tum-theia-cloud ./tum-theia-cloud --namespace $namespace --create-namespace -f tum-theia-cloud-helm-test-values.yaml
```

## Certificate System
Theia creates a new URI for each session<>plugin combination in the namespace of `*.webview.instance.theia.artemis.cit.tum.de`. Thus, a wildcard certificate is required granting the server the authority to securely handle this namespace. 
Our certificates are externally signed by RBG and cannot be renewed nor used by the regular K8s `cert-manager` - we disable it using `ingress.certManagerAnnotations: false` in the helm values.

### Install the *.webview... certificate from TUM
1. Import certificate as secret
```bash
k create secret tls static-theia-cert --cert=./wildcard-webview-cert/__webview_instance_theia_artemis_cit_tum_de.pem --key=./wildcard-webview-cert/wildcard_webview_instance_theia_artemis_cit_tum_de.key
```

2. Make sure to set the `hosts.allWildcardInstances` and `ingress.instances.allWildcardSecretNames` accordingly.

## Enable Metrics for Theia
The installation of the metrics system is based on the[Theia Cloud Observability](https://github.com/eclipsesource/theia-cloud-observability) project.

### Install Prometheus & Grafana
Based on [this instructions](https://github.com/eclipsesource/theia-cloud-observability/blob/main/kube-prometheus-stack/README.md), we perform the following steps:

1. Configure the system in `theia-prometheus-values.yml`. Make sure to set an appropriate password and adjust the domains.

2. Add repository to install prometheus.
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

3. Install in wanted namespace
```bash
helm upgrade theia-prometheus-stack prometheus-community/kube-prometheus-stack \
--version 60.2.0 --namespace theia-prometheus-stack --create-namespace --install \
--values theia-prometheus-values.yaml
```

### Install Theia dashboards
The manifests assume default namespaces for both the Theia Cloud and the Prometheus installations. If those namespaces do not match your installation, you have to adapt the manifests.
Follow [these instructions](https://github.com/eclipsesource/theia-cloud-observability/blob/main/kube-prometheus-stack/README.md#installupgrade-additional-manifests) to change the manifests available in the `theia-metrics` directory.

Finally, create the new dashboard: `kubectl apply -f theia-metrics/manifests`.

## Install Custom AppDefinitions
In Theia, *AppDefinition*s are used to define the environment the students work in. They are build in a compley three-stages pipeline [here](https://github.com/ls1intum/artemis-theia-blueprints).
To install them, we use a simplified HelmChart - more configuration is possible and documented-in-code in `./theia-appdefinitions/templates/appdefinition.yaml`. To apply changes to your cluster, run:

```bash
helm dependency update ./tum-theia-cloud
helm upgrade --install tum-theia-cloud ./tum-theia-cloud --namespace your-namespace --create-namespace -f your-custom-values.yaml
```
