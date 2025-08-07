# Kubernetes Infrastructure

## 🚀 Deployment Commands

```bash
# 1. Deploy ArgoCD
kustomize build --enable-helm infra/controllers/argocd | kubectl apply -f -
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# 2. Chain Reaction
kustomize build --enable-helm infra | kubectl apply -f -
kubectl apply -k sets

# Individual Components (if needed)
# Cilium
kubectl kustomize --enable-helm infra/network/cilium | kubectl apply -f -

# Sealed-secrets
kustomize build --enable-helm infra/controllers/sealed-secrets | kubectl apply -f -

# Proxmox CSI Plugin
kustomize build --enable-helm infra/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A
```