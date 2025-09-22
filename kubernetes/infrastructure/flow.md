# Infrastructure Deployment Flow

## 🎯 TRUE KUSTOMIZE CONTROL Pattern

### 1. Initial Bootstrap Command
```bash
kubectl apply -k kubernetes/infrastructure/
```

### 2. Bootstrap Phase (Direct kubectl)
```
kubectl → kubernetes/infrastructure/kustomization.yaml
     ↓
Deploys ONLY:
├── project.yaml           # infrastructure AppProject
└── applications.yaml      # infrastructure ApplicationSet
```

**Result**: 2 resources deployed, NO Helm charts, NO components yet!

### 3. ApplicationSet Discovery Phase (ArgoCD)
```
infrastructure ApplicationSet → Scans repository
     ↓
Discovers directories:
├── kubernetes/infrastructure/controllers/*
├── kubernetes/infrastructure/network/*
├── kubernetes/infrastructure/storage/*
├── kubernetes/infrastructure/monitoring/*
└── kubernetes/infrastructure/observability/*
```

### 4. ApplicationSet Creates Applications (ArgoCD)
For each discovered directory, ApplicationSet creates an ArgoCD Application:

```yaml
# Example: infrastructure/storage/rook-ceph/
Application:
  name: rook-ceph
  source:
    path: kubernetes/infrastructure/storage/rook-ceph/
    kustomize: {}  # 🎯 KEY: Forces Kustomize processing!
  destination:
    namespace: rook-ceph
```

### 5. Kustomize Processing Phase (ArgoCD)
```
ArgoCD Application → storage/rook-ceph/kustomization.yaml
     ↓
Kustomize processes:
├── resources:              # What to include
│   ├── crds.yaml
│   ├── operator.yaml
│   └── cluster.yaml
├── patches:                # Strategic modifications
│   ├── Memory limits
│   ├── Sync waves
│   └── Enterprise labels
└── images:                 # Version control
    └── rook/ceph:v1.15.8
```

### 6. Deployment Control (Kustomize)
**Kustomize has FULL CONTROL:**

✅ **Can disable components:**
```yaml
resources:
  # - longhorn/          # ❌ DISABLED by commenting out
  - rook-ceph/           # ✅ ENABLED
```

✅ **Can modify any resource:**
```yaml
patches:
  - target:
      kind: Deployment
      name: rook-ceph-operator
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "1Gi"  # Reduced from 2Gi
```

✅ **Can control sync order:**
```yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "4"  # Deploy after controllers
```

### 7. Final Result
```
ApplicationSet (Discovery) + Kustomize (Control) = Perfect GitOps
     ↓
Each component deployed EXACTLY as Kustomize specifies
NO direct Helm chart processing
NO bypassing of filters
FULL granular control
```

## 🚨 Error Prevention

### ❌ OLD BROKEN PATTERN:
```
ApplicationSet → Direct directory deployment
     ↓
ArgoCD deploys Helm charts directly
NO Kustomize processing
NO filtering capability
```

### ✅ NEW WORKING PATTERN:
```
ApplicationSet → Discovers directories
     ↓
ArgoCD uses source.kustomize: {}
     ↓
Kustomize processes EVERYTHING
     ↓
Filtered, patched, controlled deployment
```

## 🎯 Key Benefits

1. **Discovery**: ApplicationSet automatically finds new components
2. **Control**: Kustomize controls exactly what gets deployed
3. **Filtering**: Can disable/enable components by commenting in kustomization.yaml
4. **Patching**: Can modify any resource before deployment
5. **Versioning**: Can pin specific image versions
6. **Ordering**: Can control deployment sequence with sync waves
7. **Enterprise**: Consistent labeling and annotations

## 📂 Directory Structure
```
kubernetes/infrastructure/
├── kustomization.yaml           # Bootstrap only (project + applicationset)
├── applications.yaml            # ApplicationSet with kustomize: {}
├── controllers/
│   ├── argocd/kustomization.yaml      # Controls ArgoCD deployment
│   ├── cert-manager/kustomization.yaml
│   └── sealed-secrets/kustomization.yaml
├── network/
│   ├── cilium/kustomization.yaml      # Controls CNI deployment
│   └── istio-*/kustomization.yaml
├── storage/
│   ├── rook-ceph/kustomization.yaml   # Controls storage deployment
│   └── proxmox-csi/kustomization.yaml
└── monitoring/
    ├── prometheus/kustomization.yaml  # Controls monitoring deployment
    └── grafana/kustomization.yaml
```

Each `kustomization.yaml` has FULL CONTROL over its component deployment!