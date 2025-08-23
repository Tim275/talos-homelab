#!/bin/bash
# Re-encrypt all SealedSecrets with current controller key

set -euo pipefail

echo "🔐 Re-encrypting all SealedSecrets with current controller key..."

# Get current sealed-secrets public cert
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets > /tmp/current-seal.pem

echo "✅ Fetched current sealing certificate"

# 1. Cloudflared credentials
echo "📦 Processing cloudflared-credentials..."
kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json=secrets-storage/cloudflared-credentials.json \
  --namespace=cloudflared \
  --dry-run=client -o yaml | \
kubeseal --cert=/tmp/current-seal.pem \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  -o yaml > kubernetes/infra/network/cloudflared/sealed-credentials.yaml

# 2. Proxmox CSI credentials  
echo "📦 Processing proxmox-csi-plugin..."
cat > /tmp/proxmox-config.yaml <<EOF
clusters:
  - url: https://192.168.68.51:8006/api2/json
    insecure: false
    token_id: "root@pam!homelab-tofu"
    token_secret: "c4422069-e417-4feb-9a21-ad6e0922ac24"
    region: homelab
EOF

kubectl create secret generic proxmox-csi-plugin \
  --from-file=config.yaml=/tmp/proxmox-config.yaml \
  --namespace=csi-proxmox \
  --dry-run=client -o yaml | \
kubeseal --cert=/tmp/current-seal.pem \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  -o yaml > kubernetes/infra/storage/proxmox-csi/sealed-proxmox-credentials.yaml

# 3. Cloudflare API Token for cert-manager
echo "📦 Processing cloudflare-api-token for cert-manager..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="DUMMY_API_TOKEN_REPLACE_WITH_REAL_ONE" \
  --namespace=cert-manager \
  --dry-run=client -o yaml | \
kubeseal --cert=/tmp/current-seal.pem \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  -o yaml > kubernetes/infra/controllers/cert-manager/cloudflare-api-token.yaml

# 4. Cloudflare API Token for gateway
echo "📦 Processing cloudflare-api-token for gateway..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="DUMMY_API_TOKEN_REPLACE_WITH_REAL_ONE" \
  --namespace=gateway \
  --dry-run=client -o yaml | \
kubeseal --cert=/tmp/current-seal.pem \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  -o yaml > kubernetes/infra/network/gateway/sealed-cloudflare-api-token.yaml

# Clean up
rm /tmp/current-seal.pem /tmp/proxmox-config.yaml

echo "✅ All SealedSecrets re-encrypted successfully!"
echo "📝 Updated files:"
echo "  - kubernetes/infra/network/cloudflared/sealed-credentials.yaml"
echo "  - kubernetes/infra/storage/proxmox-csi/sealed-proxmox-credentials.yaml"
echo "  - kubernetes/infra/controllers/cert-manager/cloudflare-api-token.yaml"
echo "  - kubernetes/infra/network/gateway/sealed-cloudflare-api-token.yaml"