# Infrastructure Bootstrap Commands

## File Structure
```
kubernetes/
├── crds/                      # Custom Resource Definitions
├── infra/
│   ├── controllers/
│   │   ├── argocd/
│   │   └── sealed-secrets/
│   ├── monitoring/
│   │   ├── grafana/
│   │   ├── prometheus/
│   │   └── loki/
│   ├── network/
│   │   └── cilium/
│   └── storage/
│       ├── proxmox-csi/
│       └── rook-ceph/
├── sets/                      # ApplicationSets
└── apps/
    ├── base/                  # Base applications
    │   ├── n8n/
    │   └── audiobookshelf/
    └── overlays/
        ├── dev/
        └── production/
```

## Bootstrap Commands (Execute in order)

```bash
# Set KUBECONFIG
export KUBECONFIG="/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml"

# 1. Deploy CRDs
kubectl apply -k kubernetes/crds

# 2. Deploy sealed-secrets
kubectl kustomize --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -

# 3. Deploy Proxmox CSI  
kubectl kustomize --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -

# 4. Deploy ArgoCD
kubectl kustomize --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -

# 5. Deploy infrastructure
kubectl apply -k kubernetes/infra

# 6. Deploy ApplicationSets  
kubectl apply -k kubernetes/sets

# 7. Deploy applications (production)
kubectl apply -k kubernetes/apps/overlays/production

# 8. Deploy applications (dev)
kubectl apply -k kubernetes/apps/overlays/dev
```

## Access Commands

### ArgoCD
```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# URL: https://localhost:8080
# User: admin
```

### Grafana
```bash
# Port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80

# Get password
kubectl get secret -n monitoring grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

# URL: http://localhost:3000
# User: admin
```

### n8n
```bash
# Port-forward
kubectl port-forward -n n8n svc/n8n 5678:80

# URL: http://localhost:5678
```

### Audiobookshelf
```bash
# Port-forward  
kubectl port-forward -n audiobookshelf svc/audiobookshelf 13378:80

# URL: http://localhost:13378
```

## Status Commands

```bash
# Check all applications
kubectl get applications -n argocd

# Check pods
kubectl get pods -A

# Check storage
kubectl get pvc -A

# Check ArgoCD sync status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"
```