# Kubernetes Infrastructure

## 🚀 Deployment Commands

### **Bootstrap Order (Dependencies Matter!)**

```bash
# IMPORTANT: Set KUBECONFIG first!
export KUBECONFIG="/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml"

# 1. 🌐 NETWORK FOUNDATION
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -
# ↳ CNI + LoadBalancer + Gateway API CRDs

# 2. 🔐 SECURITY FOUNDATION  
kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -
# ↳ SealedSecret CRDs for encrypted secrets

# 3. 💾 STORAGE FOUNDATION
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A
# ↳ Storage classes and persistent volume support

# 4. 🚀 GITOPS ENGINE
kustomize build --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
# ↳ ArgoCD GitOps platform

# 5. ⚡ TRIGGER CHAIN REACTION (Matrix Generator Magic!)
kubectl apply -k kubernetes/infra  # Deploy remaining infrastructure
kubectl apply -k kubernetes/sets   # Deploy ApplicationSets → Auto-discovers ALL apps!
```

### **Access ArgoCD UI**
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
# 🌐 URL: http://localhost:8080
# 👤 Username: admin  
# 🔑 Password: [from command above]
```

### **Original Commands (Legacy)**
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

---

## 🎯 Enterprise Matrix Generator

This setup implements the **Enterprise Matrix Generator Pattern** used by Netflix, Google, and AWS:

### **How it works:**
- **Auto-Discovery**: Apps in `kubernetes/infra/*/*` are automatically found
- **Zero Maintenance**: No manual app registry updates needed  
- **Multi-Cluster Ready**: Deploy to 1000+ clusters with same config
- **Team Self-Service**: Create folder → App appears in ArgoCD

### **Adding New Apps:**
```bash
mkdir -p kubernetes/infra/my-category/my-app
# Add kustomization.yaml
git push
# ✨ App appears automatically in ArgoCD!
```

### **Why This Bootstrap Order? (Critical Dependencies)**

#### **🔴 What happens if you deploy in wrong order:**
```
❌ Apps before Cilium → Pods stuck in "ContainerCreating" (no network)
❌ Apps before Sealed-Secrets → "SealedSecret CRD not found" errors
❌ Databases before Storage → "No PersistentVolume available" 
❌ Everything before ArgoCD → Manual deployment hell (no GitOps)
```

#### **✅ Why this specific order works:**

1. **Cilium First (CNI)**: 
   - Without CNI, Pods can't get IP addresses or communicate
   - Provides LoadBalancer for exposing services
   - Installs Gateway API CRDs that other apps depend on

2. **Sealed-Secrets Second**:
   - Many apps store credentials as SealedSecrets
   - Without the CRD, these apps fail immediately
   - Must exist BEFORE any app that uses encrypted secrets

3. **Storage (Proxmox CSI)**:
   - Databases (PostgreSQL, Redis) need PersistentVolumes
   - Grafana, Prometheus need storage for data
   - CSI driver must be ready before stateful apps

4. **ArgoCD Fourth**:
   - Once foundations are ready, ArgoCD takes over
   - Manages all remaining deployments automatically
   - Provides self-healing and auto-sync

5. **ApplicationSets Last**:
   - Triggers the "chain reaction"
   - Auto-discovers all apps in `kubernetes/infra/*/*`
   - Matrix Generator deploys everything else automatically

---

**🚀 From manual app management to enterprise auto-discovery!**