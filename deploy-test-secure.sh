#!/bin/bash
# Secure deployment script for Theia Cloud Test Environment
# This script generates secrets dynamically and deploys safely

set -e

# Configuration
NAMESPACE="theia-test"
RELEASE_NAME="tum-theia-cloud-test"
VALUES_FILE="value-reference-files/theia-test-values.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Theia Cloud Test - Secure Deployment${NC}"
echo "=========================================="

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl is not configured or cluster is unreachable${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster accessible${NC}"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}❌ Values file $VALUES_FILE not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Values file found: $VALUES_FILE${NC}"

# Function to generate secure cookie secret (32 bytes base64)
generate_cookie_secret() {
    openssl rand -base64 32 | head -c 32
}

# Function to generate client secret (32 hex characters)
generate_client_secret() {
    openssl rand -hex 16
}

# Check if secrets already exist in cluster
SECRET_NAME="theia-keycloak-secrets"
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Secret $SECRET_NAME already exists${NC}"
    read -p "Do you want to regenerate secrets? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing secrets${NC}"
        USE_EXISTING_SECRETS=true
    else
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        USE_EXISTING_SECRETS=false
    fi
else
    USE_EXISTING_SECRETS=false
fi

# Generate or retrieve secrets
if [ "$USE_EXISTING_SECRETS" = true ]; then
    CLIENT_SECRET=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.clientSecret}' | base64 -d)
    COOKIE_SECRET=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cookieSecret}' | base64 -d)
    echo -e "${GREEN}✅ Retrieved existing secrets${NC}"
else
    echo -e "${YELLOW}🔑 Generating new secrets...${NC}"
    CLIENT_SECRET=$(generate_client_secret)
    COOKIE_SECRET=$(generate_cookie_secret)
    
    # Create Kubernetes secret for backup/reference
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic "$SECRET_NAME" \
        --from-literal=clientSecret="$CLIENT_SECRET" \
        --from-literal=cookieSecret="$COOKIE_SECRET" \
        -n "$NAMESPACE"
    
    echo -e "${GREEN}✅ Generated and stored new secrets${NC}"
fi

# Deploy with Helm using --set flags for secrets
echo -e "${YELLOW}🚀 Deploying Theia Cloud...${NC}"
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Values File: $VALUES_FILE"
echo "Charts Directory: ./charts/tum-theia-cloud"
echo ""
echo -e "${YELLOW}📦 Running Helm deployment...${NC}"

helm upgrade --install "$RELEASE_NAME" ./charts/tum-theia-cloud \
    --namespace "$NAMESPACE" \
    --create-namespace \
    -f "$VALUES_FILE" \
    --set theia-cloud.keycloak.clientSecret="$CLIENT_SECRET" \
    --set theia-cloud.keycloak.cookieSecret="$COOKIE_SECRET" \
    --set theia-cloud.landingPage.image="ghcr.io/ls1intum/theia/landing-page:issue-30-improve-landing-page" \
    --set theia-cloud.preloading.images[0]="ghcr.io/ls1intum/theia/landing-page:issue-30-improve-landing-page" \
    --wait --timeout=10m --debug

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo ""
    echo "🔗 Access URLs:"
    echo "   Landing Page: https://theia-test.artemis.cit.tum.de/"
    echo "   Service API:  https://service.theia-test.artemis.cit.tum.de/"
    echo ""
    echo "🔐 Security Notes:"
    echo "   - Secrets are stored in Kubernetes secret: $SECRET_NAME"
    echo "   - Secrets are NOT in Git repository"
    echo "   - Use 'kubectl get secret $SECRET_NAME -n $NAMESPACE -o yaml' to view"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
