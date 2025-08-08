#!/bin/bash
# Helper script to encrypt secrets with kubeseal

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <secret-name> <namespace> <secret-file> [output-file]"
    echo ""
    echo "Examples:"
    echo "  $0 cloudflared-credentials cloudflared secrets-storage/cloudflared-credentials.json"
    echo "  $0 proxmox-csi-plugin csi-proxmox secrets-storage/proxmox-api-config.yaml"
    echo ""
    exit 1
fi

SECRET_NAME="$1"
NAMESPACE="$2"
SECRET_FILE="$3"
OUTPUT_FILE="${4:-kubernetes/infra/**/${SECRET_NAME}.yaml}"

if [[ ! -f "$SECRET_FILE" ]]; then
    echo "Error: Secret file '$SECRET_FILE' not found!"
    exit 1
fi

if [[ ! -f "tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt" ]]; then
    echo "Error: SealedSecrets certificate not found!"
    echo "Make sure you're in the repository root and the certificate exists."
    exit 1
fi

# Determine the key name from the file extension
KEY_NAME=$(basename "$SECRET_FILE")

echo "Creating SealedSecret for '$SECRET_NAME' in namespace '$NAMESPACE'..."

# Create the secret and seal it
kubectl create secret generic "$SECRET_NAME" \
  --from-file="$KEY_NAME=$SECRET_FILE" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | \
kubeseal --cert tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --format yaml

echo ""
echo "✅ SealedSecret created successfully!"
echo "📝 Copy the output above to the appropriate sealed-secret.yaml file"
echo "🔒 The original secret in '$SECRET_FILE' remains unencrypted"