#!/bin/bash
set -euo pipefail

# 🔑 BOOTSTRAP SEALED SECRETS PERSISTENT KEY
# ==========================================
# This script creates the persistent sealed secrets key from terraform-generated certificates
# Ensures the same private key is used across all tofu destroy/apply cycles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/../../../../tofu/bootstrap/sealed-secrets/certificate"

echo "🔑 Bootstrapping Sealed Secrets persistent key..."

# Check if certificate files exist
if [[ ! -f "${CERT_DIR}/sealed-secrets.crt" ]]; then
    echo "❌ ERROR: Certificate file not found: ${CERT_DIR}/sealed-secrets.crt"
    exit 1
fi

if [[ ! -f "${CERT_DIR}/sealed-secrets.key" ]]; then
    echo "❌ ERROR: Private key file not found: ${CERT_DIR}/sealed-secrets.key"
    exit 1
fi

echo "✅ Found certificate files:"
echo "   📄 Public key:  ${CERT_DIR}/sealed-secrets.crt"
echo "   🔐 Private key: ${CERT_DIR}/sealed-secrets.key"

# Create namespace if it doesn't exist
kubectl create namespace sealed-secrets --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secret if present
kubectl delete secret sealed-secrets-key-persistent -n sealed-secrets --ignore-not-found=true

# Create the persistent key secret from terraform certificates
echo "🚀 Creating persistent key secret..."
kubectl create secret tls sealed-secrets-key-persistent \
    --cert="${CERT_DIR}/sealed-secrets.crt" \
    --key="${CERT_DIR}/sealed-secrets.key" \
    --namespace=sealed-secrets

# Add the required label for sealed-secrets controller
echo "🏷️  Adding sealed-secrets label..."
kubectl label secret sealed-secrets-key-persistent \
    sealedsecrets.bitnami.com/sealed-secrets-key=active \
    --namespace=sealed-secrets

echo "✅ SUCCESS: Persistent key secret created!"
echo "📊 Secret info:"
kubectl get secret sealed-secrets-key-persistent -n sealed-secrets -o wide

echo ""
echo "🎯 NEXT STEPS:"
echo "   Deploy Sealed Secrets controller with: kubectl kustomize --enable-helm kubernetes/infrastructure/controllers/sealed-secrets | kubectl apply -f -"
echo "   The controller will automatically use the persistent key!"