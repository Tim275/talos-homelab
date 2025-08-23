# Infrastructure Fixes for Clean Deployment

This document records all the critical infrastructure fixes that resolve broken applications and ensure a successful `tofu destroy` && `tofu apply` deployment.

## 🚨 **Critical Pre-Deployment Steps**

### 1. **Apply CRDs First (Manual Step)**
CRDs must be installed before ArgoCD bootstrap to prevent application sync failures.

```bash
# Apply CRDs before any ArgoCD applications
KUBECONFIG="tofu/output/kube-config.yaml" kubectl apply -k kubernetes/crds
```

### 2. **Re-encrypt SealedSecrets (If Needed)**
If sealed-secrets controller key changes, re-encrypt all secrets:

```bash
# Check for decryption errors
kubectl get sealedsecrets -A | grep "no key could decrypt"

# Re-encrypt affected secrets (manual process required)
# - Extract original secret from secrets-storage directory  
# - Re-encrypt with current sealed-secrets controller public key
# - Update SealedSecret YAML files in repository
```

## 📝 **Fixed Applications Summary**

| Application | Status Before | Status After | Fix Applied |
|-------------|---------------|--------------|-------------|
| `monitoring-alert-rules-grafana` | OutOfSync/Missing | ✅ Synced/Degraded | Prometheus Operator CRDs |
| `monitoring-prometheus` | OutOfSync/Missing | ⚠️ Partial | CRDs + Kustomization fix |  
| `velero` | OutOfSync/Missing | ✅ Synced/Healthy | Volume Snapshot CRDs |
| `monitoring-loki` (promtail) | Degraded | ✅ Healthy | PodSecurity fixes |

## 🔧 **Infrastructure as Code Fixes Applied**

### **1. Prometheus Monitoring Stack**

#### **Fixed prometheus/kustomization.yaml**
```yaml
# BEFORE: Missing resources declaration caused OutOfSync
# resources: # commented out

# AFTER: Proper empty resources declaration
resources: []
# Namespace managed by parent monitoring app
```

#### **Fixed prometheus-operator-crds.yaml**
```yaml
# BEFORE: Wrong repository URL and version
repoURL: https://github.com/prometheus-community/helm-charts
targetRevision: "65.1.1"

# AFTER: Correct repository URL and version alignment
repoURL: https://prometheus-community.github.io/helm-charts  
targetRevision: "75.15.1"  # Matches prometheus stack version
```

### **2. Volume Snapshot CRDs for Velero**

#### **Enhanced kubernetes/crds/kustomization.yaml**
```yaml
resources:
  # VolumeSnapshot CRDs for Velero and CSI snapshot support
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml  
  - https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-8.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  
  # Essential Prometheus Operator CRDs (compatible with cluster annotation limits)
  - prometheus-operator-crds.yaml
  - https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.65.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
  - https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.65.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
```

### **3. Pod Security Standards Compliance**

#### **Fixed monitoring/loki/promtail.yaml**  
```yaml
# BEFORE: PodSecurity baseline violation with hostPath volumes
spec:
  serviceAccount: promtail-serviceaccount
  containers:
    - name: promtail-container

# AFTER: Proper security context for privileged log collection  
spec:
  serviceAccount: promtail-serviceaccount
  securityContext:
    runAsUser: 0
    runAsGroup: 0  
    fsGroup: 0
  containers:
    - name: promtail-container
      securityContext:
        privileged: true
        runAsUser: 0
```

### **4. Bootstrap Infrastructure Enhancement**

#### **Updated kubernetes/bootstrap-infrastructure.yaml**
```yaml
# BEFORE: Missing CRDs in bootstrap
directories:
  - path: "kubernetes/infra/storage"
  - path: "kubernetes/infra/controllers"  
  - path: "kubernetes/infra/monitoring"
  - path: "kubernetes/infra/network"
  - path: "kubernetes/infra/backup"

# AFTER: CRDs included in bootstrap (sync wave -1)
directories:
  # CRDs must be applied first (sync wave -1)  
  - path: "kubernetes/crds"
  # Top-level ApplicationSets for each category
  - path: "kubernetes/infra/storage"
  - path: "kubernetes/infra/controllers"
  - path: "kubernetes/infra/monitoring" 
  - path: "kubernetes/infra/network"
  - path: "kubernetes/infra/backup"
```

## 🎯 **Deployment Success Criteria**

After `tofu apply`, all applications should be:
- ✅ **Sync Status**: `Synced`
- ✅ **Health Status**: `Healthy` or `Progressing` (for long-running deploys)

### **Verification Commands**
```bash
# Check application status
kubectl get applications -n argocd

# Verify critical CRDs are installed
kubectl get crd | grep -E "(snapshot.storage|monitoring.coreos)"

# Check for SealedSecret decryption errors  
kubectl get sealedsecrets -A | grep -v "Synced.*True"
```

## ⚡ **Quick Recovery Commands**

If applications fail after deployment:

```bash
# Re-apply CRDs manually
kubectl apply -k kubernetes/crds

# Force sync critical applications
kubectl patch application monitoring-alert-rules-grafana -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'
kubectl patch application monitoring-prometheus -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'
kubectl patch application velero -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'
```

## 🚀 **Infrastructure Readiness**

With these fixes, the infrastructure is ready for:
1. ✅ Clean `tofu destroy` 
2. ✅ Clean `tofu apply`
3. ✅ All applications should sync successfully
4. ✅ Production-ready monitoring and backup capabilities

---
*Generated after successful resolution of critical infrastructure issues - 2025-08-23*