# Enterprise Environment Management

## 🎯 **Available Environments**

| Environment | Components | Use Case | Resource Usage |
|-------------|------------|----------|----------------|
| **minimal** | Core only | Testing, dev, low-resource | XS (2-4GB RAM) |
| **standard** | Core + monitoring + backup | Standard production | M (8-16GB RAM) |  
| **enterprise** | Everything | Full enterprise setup | XL (32GB+ RAM) |
| **homelab** | Your current setup | Current working config | L (16-32GB RAM) |

## 🚀 **Deployment Commands**

### **Current Setup (no changes)**
```bash
# Your existing deployment (unchanged)
kubectl apply -f kubernetes/bootstrap-infrastructure.yaml
# OR via environment:
kubectl apply -k kubernetes/environments/homelab
```

### **Alternative Deployments**
```bash
# Minimal setup (nur essentials)  
kubectl apply -k kubernetes/environments/minimal

# Standard production
kubectl apply -k kubernetes/environments/standard

# Full enterprise
kubectl apply -k kubernetes/environments/enterprise
```

## 🔧 **Environment Switching**

```bash
# Switch from current to minimal
kubectl delete -f kubernetes/bootstrap-infrastructure.yaml
kubectl apply -k kubernetes/environments/minimal

# Switch back to your current setup
kubectl delete -k kubernetes/environments/minimal  
kubectl apply -k kubernetes/environments/homelab
```

## 📊 **What Each Environment Includes**

### 🔧 **Minimal**
- ArgoCD, Cert-Manager, Sealed-Secrets
- Cilium networking
- Gateway API  
- Longhorn storage (single replica)
- **Resource Usage**: ~4GB RAM

### 🏭 **Standard**  
- Everything from Minimal +
- Kube-VIP (HA)
- Prometheus + Grafana + Loki
- Velero backup
- Proxmox CSI
- **Resource Usage**: ~12GB RAM

### 🏢 **Enterprise**
- Everything from Standard +  
- Jaeger tracing
- Hubble observability
- Rook-Ceph distributed storage
- MinIO object storage
- OpenTelemetry
- Cloudflared tunnels
- **Resource Usage**: ~24GB RAM

### 🏠 **Homelab (Current)**
- Your existing working configuration
- Optimized for homelab usage
- All features you currently use
- **Resource Usage**: ~16GB RAM

## 💡 **Migration Path**

1. **Test minimal**: `kubectl apply -k kubernetes/environments/minimal`
2. **Validate standard**: `kubectl apply -k kubernetes/environments/standard`  
3. **Keep current**: `kubectl apply -k kubernetes/environments/homelab`

Your `infra/` directory remains unchanged - environments just select different components!