# Kubernetes Homelab GitOps

## Quick Start

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy complete stack
kubectl apply -k bootstrap/

# Monitor deployment
kubectl get applications -n argocd -w
```

## ArgoCD Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

## Operations

```bash
# Check all applications
kubectl get applications -n argocd

# Sync status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"

# Force sync
kubectl patch application <app-name> -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'

# ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Application details
kubectl describe application <app-name> -n argocd
```
