#!/bin/bash
set -e

echo "🚀 Deploying Rook-Ceph..."

# First apply - CRDs and operator
echo "📋 Installing CRDs and operator..."
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -

# Wait for CRDs to be established
echo "⏳ Waiting for CRDs to be ready..."
kubectl wait --for=condition=established crd/cephclusters.ceph.rook.io --timeout=60s
kubectl wait --for=condition=established crd/cephblockpools.ceph.rook.io --timeout=60s
kubectl wait --for=condition=established crd/cephfilesystems.ceph.rook.io --timeout=60s

# Second apply - actual Ceph resources
echo "🗄️ Creating Ceph cluster and pools..."
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -

echo "✅ Rook-Ceph deployment complete!"
echo "📊 Check status with: kubectl get pods -n rook-ceph"