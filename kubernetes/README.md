# Kubernetes Homelab GitOps

## Quick Start

### Option 1: Bootstrap via ArgoCD (Recommended)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy complete stack
kubectl apply -k bootstrap/

# Monitor deployment
kubectl get applications -n argocd -w
```

### Option 2: Layer-by-Layer Bootstrap (More Control)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Step-by-step deployment with wave control
kubectl apply -k security/           # Wave 0: Security ApplicationSets
kubectl apply -k infrastructure/     # Wave 1: Infrastructure ApplicationSets
kubectl apply -k platform/          # Wave 15: Platform ApplicationSets
kubectl apply -k apps/              # Wave 25: Apps ApplicationSets

# Edit ApplicationSet files to enable/disable individual services
# Example: infrastructure/monitoring-app.yaml, infrastructure/network-app.yaml
# Comment/Uncomment services to control what gets deployed
```

### Option 3: Manual Core Bootstrap (Minimal)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Core infrastructure only - minimum required for ArgoCD
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/network/sail-operator | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/network/istio-control-plane | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# Then deploy remaining components via ArgoCD UI
```

---

## ArgoCD Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:80

# URL: http://localhost:8080 (admin / <password>)
```

---

## 3-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: BOOTSTRAP (App-of-Apps)                               │
│ ────────────────────────────────────────────────────────────── │
│ bootstrap/kustomization.yaml                                    │
│ └── Deploys 4 ApplicationSets via ArgoCD                       │
└─────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ security.yaml │   │ infrastructure│   │ platform.yaml │
│ Wave 0        │   │ Wave 1-6      │   │ Wave 15-18    │
└───────────────┘   └───────────────┘   └───────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: APPLICATIONSETS (Domain-Based)                        │
│ ────────────────────────────────────────────────────────────── │
│ infrastructure/                                                 │
│ ├── monitoring-app.yaml      ← ApplicationSet for monitoring   │
│ ├── network-app.yaml         ← ApplicationSet for networking   │
│ ├── storage-app.yaml         ← ApplicationSet for storage      │
│ └── kustomization.yaml       ← SELECT which ApplicationSets    │
│                                                                 │
│ 🎯 CONTROL: Edit kustomization.yaml                            │
│    Comment/Uncomment ApplicationSets to enable/disable domains │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: SERVICES (Individual Components)                      │
│ ────────────────────────────────────────────────────────────── │
│ infrastructure/monitoring/                                      │
│ ├── prometheus/                                                 │
│ │   └── kustomization.yaml  ← Service-level config             │
│ ├── grafana/                                                    │
│ │   └── kustomization.yaml  ← Service-level config             │
│ └── alertmanager/                                               │
│     └── kustomization.yaml  ← Service-level config             │
│                                                                 │
│ 🎯 CONTROL: Edit service kustomization.yaml                    │
│    Add/remove resources, patch configs, set replicas           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎛️ Kustomize Control Points

### Level 1: Enable/Disable Domains (ApplicationSets)

**File:** `infrastructure/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # ENABLE/DISABLE ENTIRE DOMAINS
  - monitoring-app.yaml       # ✅ Prometheus, Grafana, Alertmanager
  - network-app.yaml          # ✅ Cilium, Istio, Gateway API
  - storage-app.yaml          # ✅ Rook-Ceph, Velero
  # - observability-app.yaml  # ❌ DISABLED (Vector, Elasticsearch, Kibana)
```

**To disable monitoring stack:**
```yaml
resources:
  # - monitoring-app.yaml     # ❌ Comment out = no monitoring deployed
  - network-app.yaml
  - storage-app.yaml
```

---

### Level 2: Enable/Disable Services (Individual Components)

**File:** `infrastructure/monitoring/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # ENABLE/DISABLE INDIVIDUAL SERVICES
  - prometheus/               # ✅ Metrics collection
  - grafana/                  # ✅ Dashboards
  - alertmanager/             # ✅ Alert routing
  # - robusta/                # ❌ DISABLED (AI alerts)
  # - loki/                   # ❌ DISABLED (Log aggregation)
```

**To disable Grafana:**
```yaml
resources:
  - prometheus/
  # - grafana/                # ❌ Comment out = no Grafana
  - alertmanager/
```

---

### Level 3: Patch Service Configs

**File:** `infrastructure/monitoring/prometheus/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - prometheus.yaml

# PATCH SERVICE CONFIG
patches:
  - target:
      kind: Prometheus
      name: kube-prometheus-stack-prometheus
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1                # Change replicas

  - target:
      kind: Prometheus
      name: kube-prometheus-stack-prometheus
    patch: |-
      - op: replace
        path: /spec/retention
        value: 7d               # Change retention
```

---

## 📂 Directory Structure

```
kubernetes/
├── bootstrap/
│   ├── kustomization.yaml       # LAYER 1: Bootstrap entry point
│   ├── security.yaml
│   ├── infrastructure.yaml
│   ├── platform.yaml
│   └── apps.yaml
│
├── security/
│   └── kustomization.yaml       # LAYER 2: Security ApplicationSets
│
├── infrastructure/
│   ├── kustomization.yaml       # LAYER 2: Infrastructure ApplicationSets
│   ├── monitoring-app.yaml
│   ├── network-app.yaml
│   ├── storage-app.yaml
│   │
│   ├── monitoring/
│   │   ├── kustomization.yaml   # LAYER 3: Service selector
│   │   ├── prometheus/
│   │   │   └── kustomization.yaml  # Service config
│   │   └── grafana/
│   │       └── kustomization.yaml  # Service config
│   │
│   └── network/
│       ├── kustomization.yaml
│       └── cilium/
│           └── kustomization.yaml
│
├── platform/
│   └── kustomization.yaml       # LAYER 2: Platform ApplicationSets
│
└── apps/
    └── kustomization.yaml       # LAYER 2: Apps ApplicationSets
```

---

## 🎯 Control Examples

### Example 1: Disable Entire Monitoring Stack

```bash
# Edit infrastructure/kustomization.yaml
vim infrastructure/kustomization.yaml

# Comment out monitoring-app.yaml
resources:
  # - monitoring-app.yaml    # ❌ DISABLED
  - network-app.yaml
  - storage-app.yaml

# Apply
kubectl apply -k infrastructure/
```

**Result:** ArgoCD deletes all monitoring applications (Prometheus, Grafana, Alertmanager)

---

### Example 2: Disable Only Grafana

```bash
# Edit infrastructure/monitoring/kustomization.yaml
vim infrastructure/monitoring/kustomization.yaml

# Comment out grafana/
resources:
  - prometheus/
  # - grafana/              # ❌ DISABLED
  - alertmanager/

# Sync via ArgoCD (auto-sync enabled)
kubectl patch application infrastructure-monitoring -n argocd --type='merge' -p='{"operation":{"sync":{}}}'
```

**Result:** ArgoCD deletes Grafana, keeps Prometheus + Alertmanager

---

### Example 3: Change Prometheus Replicas

```bash
# Edit infrastructure/monitoring/prometheus/kustomization.yaml
vim infrastructure/monitoring/prometheus/kustomization.yaml

# Add patch
patches:
  - target:
      kind: Prometheus
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3              # Scale to 3 replicas

# Sync
kubectl patch application infrastructure-monitoring -n argocd --type='merge' -p='{"operation":{"sync":{}}}'
```

**Result:** Prometheus scales from 2 to 3 replicas

---

## Core Components

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| **Cilium** | CNI + Network Policies | kube-system |
| **Rook-Ceph** | Storage (Block, Object, File) | rook-ceph |
| **ArgoCD** | GitOps Controller | argocd |
| **Istio** | Service Mesh | istio-system |
| **Prometheus** | Metrics | monitoring |
| **Elasticsearch** | Logs | elastic-system |
| **PostgreSQL (CNPG)** | Databases | various |
| **Authelia** | Auth Gateway | authelia |

---

## Operations

### Check Deployment Status
```bash
# All applications
kubectl get applications -n argocd

# Sync status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"
```

### Force Sync Application
```bash
kubectl patch application <app-name> -n argocd --type='merge' -p='{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Troubleshooting
```bash
# ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Application details
kubectl describe application <app-name> -n argocd
```

---

## Manual Core Bootstrap (Minimal)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Core infrastructure (if not using ArgoCD bootstrap)
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/network/sail-operator | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# Then use ArgoCD UI for remaining components
```

---

## Backup Strategy

See: `infrastructure/storage/velero/ENTERPRISE_BACKUP_STRATEGY.md`

**Critical Backups (Tier-0):**
- n8n-prod (Workflows)
- Keycloak (Users)
- Infisical (Secrets)
- Authelia (2FA)
- LLDAP (User Directory)

**Backup Method:** Velero + Rook Ceph S3
**Retention:** 7-90 days
**RPO:** 6h (Tier-0), 24h (Tier-1)
