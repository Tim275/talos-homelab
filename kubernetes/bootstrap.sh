#!/bin/bash
set -e

# Bootstrap ArgoCD and Infrastructure as Code
# This script sets up the entire GitOps infrastructure

KUBECONFIG="${KUBECONFIG:-tofu/output/kube-config.yaml}"
export KUBECONFIG

echo "🚀 Starting Infrastructure Bootstrap..."

# Step 1: Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Step 2: Apply the bootstrap ApplicationSet
echo "🔧 Applying infrastructure bootstrap..."
cat <<'EOF' | kubectl apply -f -
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infrastructure
  namespace: argocd
spec:
  description: Infrastructure project
  sourceRepos:
    - 'https://github.com/Tim275/talos-homelab'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - name: crds
            path: kubernetes/crds
          - name: storage
            path: kubernetes/infra/storage
          - name: controllers
            path: kubernetes/infra/controllers
          - name: network
            path: kubernetes/infra/network
          - name: monitoring
            path: kubernetes/infra/monitoring
          - name: backup
            path: kubernetes/infra/backup
  template:
    metadata:
      name: '{{.name}}'
      namespace: argocd
    spec:
      project: infrastructure
      source:
        repoURL: https://github.com/Tim275/talos-homelab
        targetRevision: HEAD
        path: '{{.path}}'
      destination:
        server: https://kubernetes.default.svc
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
EOF

echo "✅ Bootstrap complete! ArgoCD will now sync all infrastructure components."
echo ""
echo "📊 Monitor progress with:"
echo "  kubectl get applications -n argocd"
echo ""
echo "🔑 Get ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"