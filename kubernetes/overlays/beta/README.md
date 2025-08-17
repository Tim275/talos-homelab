# 🚀 Beta Overlay - Enterprise ApplicationSet Control

## Was ist das?
Ein **Kustomize Overlay** für **Enterprise-level Kontrolle** über deine ArgoCD ApplicationSets.

## 🎯 Enterprise Features

### ✅ **ApplicationSet Granulare Kontrolle**
- **Comment/Uncomment** ApplicationSets in `kustomization.yaml`
- **Sync Waves** für geordnete Deployments  
- **Retry Policies** für Enterprise Reliability
- **Validation** für strikte Compliance

### 📊 **Kontrollierte ApplicationSets:**
```
✅ controllers   → ArgoCD, Cert-Manager, Sealed-Secrets
✅ storage       → Proxmox-CSI, Rook-Ceph (MinIO excluded)
✅ monitoring    → Prometheus, Grafana, Loki
✅ network       → Cilium, Gateway API
❌ backup        → Velero (optional, uncomment wenn benötigt)
```

### 🔧 **Enterprise Patches:**
- **Monitoring:** Sync wave 2, safer prune policy
- **Storage:** Sync wave 1, exclude heavy components  
- **All:** Strict validation, retry policies

## 🚀 **Deployment:**

### **1. Test Overlay (Dry Run):**
```bash
kubectl kustomize overlays/beta/
```

### **2. Deploy Beta Overlay:**
```bash
kubectl apply -k overlays/beta/
```

### **3. Kontrolle Individual ApplicationSets:**
```bash
# Monitoring ausschalten
# Edit overlays/beta/kustomization.yaml:
# - ../../infra/monitoring/application-set.yaml  → auskommentieren

# Re-apply
kubectl apply -k overlays/beta/
```

## 📈 **Enterprise Control Examples:**

### **Disable Heavy Components:**
```yaml
# In overlays/beta/kustomization.yaml
resources:
  - ../../infra/controllers/application-set.yaml  # ✅ Essential
  - ../../infra/storage/application-set.yaml      # ✅ Core storage
  # - ../../infra/monitoring/application-set.yaml # ❌ Disable für Testing
  - ../../infra/network/application-set.yaml      # ✅ Network
```

### **Environment-Specific Patches:**
```yaml
# overlays/production/patches/storage-production-patch.yaml
spec:
  template:
    spec:
      syncPolicy:
        automated:
          prune: true    # ✅ Production: Aggressive cleanup
```

## 🎛️ **ArgoCD Integration:**
```bash
# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check Generated Applications  
kubectl get applications -n argocd

# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

## 🏢 **Enterprise Benefits:**
- **Controlled Rollouts** via Sync Waves
- **Risk Mitigation** mit Beta-safe policies
- **Component Isolation** per ApplicationSet
- **Environment Parity** mit consistent overlays