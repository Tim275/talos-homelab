#!/bin/bash
# SealedSecrets Key Restoration Script
# Run this after every `tofu apply` that recreates the cluster

set -e

echo "🔧 Restoring SealedSecrets keys after cluster recreation..."

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
  echo "❌ KUBECONFIG environment variable not set!"
  echo "   Set it with: export KUBECONFIG=path/to/your/kubeconfig.yaml"
  exit 1
fi

# Check if kubectl works
if ! kubectl cluster-info &> /dev/null; then
  echo "❌ Cannot connect to Kubernetes cluster!"
  echo "   Check your KUBECONFIG and cluster connectivity"
  exit 1
fi

echo "✅ Connected to cluster: $(kubectl config current-context)"

# Check if sealed-secrets namespace exists
if ! kubectl get namespace sealed-secrets &> /dev/null; then
  echo "❌ sealed-secrets namespace not found!"
  echo "   Make sure SealedSecrets controller is deployed"
  exit 1
fi

echo "🔍 Checking current SealedSecrets status..."
kubectl get sealedsecrets --all-namespaces || echo "No SealedSecrets found"

# 1. Delete auto-generated keys
echo "🗑️  Removing auto-generated SealedSecrets keys..."
kubectl delete secret sealed-secrets-key* -n sealed-secrets --ignore-not-found

# 2. Check if bootstrap certificate files exist
CERT_FILE="tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt"
KEY_FILE="tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.key"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "❌ Bootstrap certificate files not found!"
  echo "   Expected files:"
  echo "   - $CERT_FILE"
  echo "   - $KEY_FILE"
  exit 1
fi

# 3. Restore original bootstrap keys
echo "🔐 Restoring original SealedSecrets keys from bootstrap..."
kubectl create secret tls sealed-secrets-key \
  --cert="$CERT_FILE" \
  --key="$KEY_FILE" \
  -n sealed-secrets

# 4. Label as active
echo "🏷️  Labeling secret as active SealedSecrets key..."
kubectl label secret sealed-secrets-key -n sealed-secrets \
  sealedsecrets.bitnami.com/sealed-secrets-key=active

# 5. Restart controller
echo "🔄 Restarting SealedSecrets controller..."
kubectl rollout restart deployment sealed-secrets-controller -n sealed-secrets

# 6. Wait for controller to be ready
echo "⏳ Waiting for SealedSecrets controller to be ready..."
kubectl rollout status deployment sealed-secrets-controller -n sealed-secrets --timeout=120s

# 7. Verify all SealedSecrets work
echo "🔍 Verifying SealedSecrets status..."
sleep 10  # Give controller time to process existing SealedSecrets

echo ""
echo "📊 Final SealedSecrets Status:"
kubectl get sealedsecrets --all-namespaces

# Check if any are still failing
FAILED=$(kubectl get sealedsecrets --all-namespaces -o jsonpath='{.items[?(@.status.conditions[0].status=="False")].metadata.name}' | wc -w)

if [ "$FAILED" -eq 0 ]; then
  echo ""
  echo "🎉 SUCCESS! All SealedSecrets are working correctly!"
  echo "✅ Certificate issuance, storage, monitoring, and backups should work now"
else
  echo ""
  echo "⚠️  WARNING: $FAILED SealedSecrets still failing to decrypt"
  echo "   This might indicate:"
  echo "   - Some secrets were encrypted with different keys"
  echo "   - Need to re-encrypt those specific secrets"
  echo "   - Wait a few more minutes and check again"
fi

echo ""
echo "🔧 SealedSecrets key restoration complete!"