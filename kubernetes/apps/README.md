# Applications

2-stage GitOps deployment for homelab applications.

## Bootstrap Commands

```bash
# 1. Bootstrap ArgoCD ApplicationSet (one-time setup)
kubectl apply -k kubernetes/apps/

# 2. Deploy development environment
kubectl apply -k kubernetes/apps/overlays/dev/

# 3. Deploy production environment
kubectl apply -k kubernetes/apps/overlays/production/
```

## Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application pods
kubectl get pods -n audiobookshelf
kubectl get pods -n n8n
```

## Applications

- **Audiobookshelf**: Self-hosted audiobook server
- **n8n**: Workflow automation platform with CloudNativePG database

## Structure

- `base/` - Shared Kubernetes resources
- `overlays/dev/` - Development environment (latest tags, minimal resources)
- `overlays/production/` - Production environment (pinned versions, backups)