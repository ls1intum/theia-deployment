#!/bin/bash

# Theia Cloud Test Environment Deployment
# Usage: ./deploy-test.sh [namespace]
# Default namespace: theia-test

namespace=$1
if [ -z "$namespace" ]; then
  echo "Using default namespace 'theia-test'."
  namespace="theia-test"
fi

RELEASE_NAME="tum-theia-cloud-test"
VALUES_FILE="value-reference-files/tum-theia-cloud-helm-test-values.yaml"

echo "🚀 Deploying Theia Cloud Test Environment"
echo "Namespace: $namespace"
echo "Values: $VALUES_FILE"
echo "========================================"

# Update Helm dependencies
echo "📦 Updating Helm dependencies..."
helm dependency update ./charts/tum-theia-cloud

# Function to generate secure client secret (32 characters hex)
generate_client_secret() {
    openssl rand -hex 16
}

# Function to generate secure cookie secret (32 bytes base64)
generate_cookie_secret() {
    openssl rand -base64 32 | head -c 32
}

# Check if secrets already exist
echo "🔐 Checking for existing secrets..."
if kubectl get secret theia-keycloak-secrets -n "$namespace" --insecure-skip-tls-verify &> /dev/null; then
    echo "✅ Secrets already exist. Reusing existing secrets."
    read -p "Do you want to regenerate secrets? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Regenerating secrets..."
        kubectl delete secret theia-keycloak-secrets -n "$namespace" --insecure-skip-tls-verify
        CLIENT_SECRET=$(generate_client_secret)
        COOKIE_SECRET=$(generate_cookie_secret)
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - --insecure-skip-tls-verify
        kubectl create secret generic theia-keycloak-secrets -n "$namespace" \
            --from-literal=clientSecret="$CLIENT_SECRET" \
            --from-literal=cookieSecret="$COOKIE_SECRET" \
            --dry-run=client -o yaml | kubectl apply -f - --insecure-skip-tls-verify
        echo "✅ New secrets generated and stored"
    else
        # Extract existing secrets for Helm deployment
        CLIENT_SECRET=$(kubectl get secret theia-keycloak-secrets -n "$namespace" --insecure-skip-tls-verify -o jsonpath='{.data.clientSecret}' | base64 -d)
        COOKIE_SECRET=$(kubectl get secret theia-keycloak-secrets -n "$namespace" --insecure-skip-tls-verify -o jsonpath='{.data.cookieSecret}' | base64 -d)
        echo "✅ Using existing secrets"
    fi
else
    echo "🔑 Generating new secrets..."
    CLIENT_SECRET=$(generate_client_secret)
    COOKIE_SECRET=$(generate_cookie_secret)
    
    # Create namespace and secrets
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - --insecure-skip-tls-verify
    kubectl create secret generic theia-keycloak-secrets -n "$namespace" \
        --from-literal=clientSecret="$CLIENT_SECRET" \
        --from-literal=cookieSecret="$COOKIE_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f - --insecure-skip-tls-verify
    echo "✅ New secrets generated and stored"
fi

# Deploy with Helm using --set flags for secrets
echo "🚀 Deploying Theia Cloud..."
echo "Release: $RELEASE_NAME"
echo "Namespace: $namespace"
echo "Values File: $VALUES_FILE"
echo "Charts Directory: ./charts/tum-theia-cloud"
echo ""
echo "📦 Running Helm deployment..."

helm upgrade --install "$RELEASE_NAME" ./charts/tum-theia-cloud \
    --namespace "$namespace" \
    --create-namespace \
    -f "$VALUES_FILE" \
    --set theia-cloud.keycloak.clientSecret="$CLIENT_SECRET" \
    --set theia-cloud.keycloak.cookieSecret="$COOKIE_SECRET" \
    --wait \
    --timeout=10m \
    --insecure-skip-tls-verify

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🔍 Checking deployment status..."
kubectl get pods -n "$namespace" --insecure-skip-tls-verify
echo ""
echo "🌐 Access URLs:"
echo "Landing page: https://theia-test.artemis.cit.tum.de/"
echo "Service API: https://service.theia-test.artemis.cit.tum.de/"
echo ""
echo "🎉 Theia Cloud Test Environment deployed successfully!"
