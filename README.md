# Theia Deployment

## Install Theia Cloud

### Prerequisites

Theia Cloud requires a Kubernetes cluster with the following patch to the ingress-nginx controller to allow snippet annotations (also see [theia-cloud-helm](https://github.com/eclipse-theia/theia-cloud-helm/tree/main):

```bash
kubectl -n ingress-nginx patch cm ingress-nginx-controller --patch '{"data":{"allow-snippet-annotations":"true" "annotations-risk-level": "Critical" }}'
kubectl -n ingress-nginx delete pod -l app.kubernetes.io/name=ingress-nginx
```

### Install Theia Cloud Charts

Make sure to set the namespace to your desired location first. For production, we use `theia-prod`.

```bash
helm repo add theia-cloud-repo https://eclipse-theia.github.io/theia-cloud-helm/
helm repo update

helm upgrade theia-cloud-base theia-cloud-repo/theia-cloud-base --install -f theia-base-helm-values.yml

helm upgrade theia-cloud-crds theia-cloud-repo/theia-cloud-crds --install -f theia-crds-helm-values.yml

helm upgrade --install tum-theia-cloud ./tum-theia-cloud --namespace your-namespace --create-namespace
```

### Installing the Theia Cloud Test Environment

#### Secure Deployment (Recommended)

The test environment uses a secure deployment script that automatically generates OAuth2 secrets and stores them safely in Kubernetes secrets. This follows security best practices by not storing sensitive data in Git.

```bash
# Make the deployment script executable
chmod +x deploy-test-secure.sh

# Deploy to test environment with auto-generated secrets
./deploy-test-secure.sh
```

The script will:
- Generate secure OAuth2 client and cookie secrets
- Store secrets in Kubernetes secret `theia-keycloak-secrets`
- Deploy using `value-reference-files/theia-test-values.yaml` configuration
- Deploy to `theia-test` namespace with enhanced landing page

**Features included:**
- ✨ Enhanced landing page with VantaJS background animation
- 🎨 Programming language icons (Java, C, JavaScript, OCaml, Python, Rust)
- 🔐 Secure OAuth2 integration with Keycloak
- 📱 Responsive design for mobile/tablet
- 🚀 Fast session startup with image preloading

#### Manual Deployment (Advanced)

If you prefer manual deployment or need custom secret values:

```bash
# Generate secrets manually
CLIENT_SECRET=$(openssl rand -hex 16)
COOKIE_SECRET=$(openssl rand -base64 32)

# Deploy with manual secrets
helm upgrade --install tum-theia-cloud-test ./charts/tum-theia-cloud \
  --namespace theia-test --create-namespace \
  -f value-reference-files/theia-test-values.yaml \
  --set theia-cloud.keycloak.clientSecret="$CLIENT_SECRET" \
  --set theia-cloud.keycloak.cookieSecret="$COOKIE_SECRET"
```

#### Access URLs

After successful deployment:
- **Landing Page**: https://theia-test.artemis.cit.tum.de/
- **Service API**: https://service.theia-test.artemis.cit.tum.de/

#### Security Notes

- 🔐 OAuth2 secrets are generated per deployment and stored in Kubernetes secrets
- 🚫 No sensitive data is stored in Git repository  
- 🔄 Secrets can be easily rotated by re-running the deployment script
- 🏢 Compatible with existing CI/CD security patterns

## Certificate System

Theia creates a new URI for each session<>plugin combination in the namespace of `*.webview.instance.theia.artemis.cit.tum.de`. Thus, a wildcard certificate is required granting the server the authority to securely handle this namespace.
Our certificates are externally signed by RBG and cannot be renewed nor used by the regular K8s `cert-manager` - we disable it using `ingress.certManagerAnnotations: false` in the helm values.

### Install the *.webview... certificate from TUM

1. Import certificate as secret

```bash
k create secret tls static-theia-cert --cert=./wildcard-webview-cert/__webview_instance_theia_artemis_cit_tum_de.pem --key=./wildcard-webview-cert/wildcard_webview_instance_theia_artemis_cit_tum_de.key
```

2. Make sure to set the `hosts.allWildcardInstances` and `ingress.instances.allWildcardSecretNames` accordingly.

## Add Keycloak Client Scopes

Go to Keycloak realm > Clients > theia-cloud > Client Scopes > theia-dedicated > Mappers and add the following mappers:

![Keycloak Client Scopes](docs/images/keycloak_client_scopes.png)

- username

![Username Mapper](docs/images/keycloak_client_scope_username.png)

- audience

![Audience Mapper](docs/images/keycloak_client_scope_audience.png)

- groups

![Groups Mapper](docs/images/keycloak_client_scope_groups.png)

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
