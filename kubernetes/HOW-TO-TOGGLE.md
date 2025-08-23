# 🎛️ Component Toggle System - Easy Enable/Disable

## 🚀 Quick Start

Want to **disable** a component? Add these lines to the ApplicationSet:
```yaml
- path: "kubernetes/infra/monitoring/loki"
  exclude: true
```

Want to **enable** it? Remove or comment out those lines:
```yaml
# - path: "kubernetes/infra/monitoring/loki"
#   exclude: true
```

## 📁 Where to Edit

Each category has its ApplicationSet file:

| Category | File | Examples |
|----------|------|----------|
| **Monitoring** | `infra/monitoring/application-set.yaml` | grafana, loki, jaeger, prometheus |
| **Network** | `infra/network/application-set.yaml` | cloudflared, gateway, cilium |
| **Storage** | `infra/storage/application-set.yaml` | longhorn, proxmox-csi, rook-ceph |
| **Controllers** | `infra/controllers/application-set.yaml` | cert-manager, sealed-secrets |
| **Observability** | `infra/observability/application-set.yaml` | opentelemetry |

## 📝 Examples

### Disable Loki (Save 2GB+ Memory)
Edit `infra/monitoring/application-set.yaml`:
```yaml
# DISABLE LOKI - resource intensive!
- path: "kubernetes/infra/monitoring/loki"
  exclude: true
```

### Disable Cloudflared Tunnel  
Edit `infra/network/application-set.yaml`:
```yaml
# Disable cloudflare tunnel
- path: "kubernetes/infra/network/cloudflared"
  exclude: true
```

### Disable Longhorn Storage
Edit `infra/storage/application-set.yaml`:
```yaml  
# Disable Longhorn storage
- path: "kubernetes/infra/storage/longhorn"
  exclude: true
```

## ⚡ How It Works

1. **ApplicationSet** scans `kubernetes/infra/*/` directories
2. **Exclude paths** tell it to skip certain components
3. **ArgoCD** automatically removes Applications when you exclude them
4. **Git commit + push** = instant changes!

## 🔄 Workflow

```bash
# 1. Edit ApplicationSet file
vim infra/monitoring/application-set.yaml

# 2. Add or remove exclude blocks
- path: "kubernetes/infra/monitoring/loki"
  exclude: true

# 3. Commit and push
git add .
git commit -m "disable loki to save resources"
git push

# 4. ArgoCD auto-syncs and removes the Application
# Done! 🎉
```

## 📊 Resource Impact

| Component | Memory Usage | Notes |
|-----------|--------------|-------|
| **Loki** | 1-2GB | Log storage - can disable safely |
| **Jaeger** | 1GB | Distributed tracing - optional |
| **Grafana** | 500MB | Dashboards - keep enabled |
| **Prometheus** | 1GB | Core metrics - always keep |

## 🚨 Dependencies

Some components need others:
- **Grafana** needs **Prometheus** 
- **Gateway** needs **cert-manager**
- **Cloudflared** needs **sealed-secrets**

## ✅ Current Status

Check what's currently enabled/disabled:
```bash
kubectl get applications -n argocd
```

Missing applications = they're disabled! 🎯

---

**Pro Tip**: Always commit with descriptive messages like "disable loki to save resources" so you remember why!