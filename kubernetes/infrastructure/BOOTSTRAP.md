# 🚀 MEGA ENTERPRISE BOOTSTRAP GUIDE
## Netflix/Google/Meta Pattern Infrastructure

## 🎯 CLEAN BOOTSTRAP FROM SCRATCH

### Prerequisites
- Talos Kubernetes cluster running
- ArgoCD installed in cluster
- Git repository accessible

### 🏗️ BOOTSTRAP STEPS

```bash
# 1️⃣ Export KUBECONFIG
export KUBECONFIG="tofu/output/kube-config.yaml"

# 2️⃣ Deploy ENTIRE Infrastructure with ONE COMMAND!
kubectl apply -k kubernetes/infrastructure

# ✅ This creates ALL ApplicationSets:
# - infrastructure-network
# - infrastructure-controllers
# - infrastructure-storage
# - infrastructure-monitoring
# - infrastructure-observability
```

## 🎮 LAYER CONTROL SYSTEM

### Enable/Disable Infrastructure Layers
Edit `kubernetes/infrastructure/kustomization.yaml`:

```yaml
resources:
  # Core Layers (always needed)
  - infrastructure-network.yaml      # ✅ Network (Cilium, Istio, Gateway)
  - infrastructure-controllers.yaml  # ✅ Controllers (ArgoCD, Cert-Manager)
  - infrastructure-storage.yaml      # ✅ Storage (Rook-Ceph, Proxmox-CSI)

  # Optional Layers (comment to disable)
  - infrastructure-monitoring.yaml   # 📊 Monitoring (Prometheus, Grafana)
  - infrastructure-observability.yaml # 🔍 Observability (Vector, Elastic)
```

### Apply Changes
```bash
# After editing kustomization.yaml:
kubectl apply -k kubernetes/infrastructure

# OR if using ArgoCD App-of-Apps:
kubectl apply -f kubernetes/infrastructure/tier0-infrastructure.yaml
```

## 🏢 ARCHITECTURE PATTERN

```
tier0-infrastructure.yaml (ArgoCD Application)
    ↓ manages
kubernetes/infrastructure/kustomization.yaml
    ↓ includes
infrastructure-*.yaml (ApplicationSets)
    ↓ deploy
Individual Applications (cilium, istio, etc.)
```

## 💡 TOGGLE COMPONENTS

### Network Layer Example
Edit `kubernetes/infrastructure/network/application-set.yaml`:

```yaml
# COMPONENT TOGGLES - uncomment to disable:
# - path: "kubernetes/infrastructure/network/cloudflared"
#   exclude: true
- path: "kubernetes/infrastructure/network/metallb"
  exclude: true    # ← Component disabled
- path: "kubernetes/infrastructure/network/layers"
  exclude: true    # ← Component disabled
```

## 🔥 BENEFITS

- ✅ **ONE COMMAND** bootstrap: `kubectl apply -k kubernetes/infrastructure`
- ✅ **Git-based toggles** - No kubectl commands needed
- ✅ **Layer control** - Enable/disable entire infrastructure layers
- ✅ **TRUE Enterprise Pattern** - Netflix/Google/Meta approved!
- ✅ **Clean & Simple** - Anyone can understand and operate

## 🚨 TROUBLESHOOTING

### Duplicate ApplicationSets
```bash
# Check for duplicates
kubectl get applicationsets -n argocd

# Delete old/duplicate ones
kubectl delete applicationset <old-name> -n argocd
```

### Application Stuck Deleting
```bash
# Force delete if stuck
kubectl patch application <app-name> -n argocd \
  --type json \
  --patch='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

## 🎯 FULL RESET

```bash
# Nuclear option - delete everything and start fresh
kubectl delete applications --all -n argocd
kubectl delete applicationsets --all -n argocd
kubectl apply -k kubernetes/infrastructure
```

---
**TRUE ENTERPRISE PATTERN** 🚀 Netflix/Google/Meta Style!