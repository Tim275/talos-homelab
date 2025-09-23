# 🚀 Enterprise Kubernetes GitOps Architecture

> **2025 Enterprise Hybrid Pattern** - Netflix/Google/Meta Level GitOps Implementation

**Production-grade 4-layer GitOps architecture** implementing 2025 enterprise best practices with **Zero Trust Foundation**, **Domain-based ApplicationSets**, and **TRUE Kustomize Control**.

## 🎯 Quick Start

### Single Command Deployment

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 🚀 Deploy complete enterprise stack
kubectl apply -k bootstrap/

# 🔍 Monitor deployment
kubectl get applications -n argocd -w
```

### ArgoCD Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
# 🌐 URL: http://localhost:8080 (admin / <password>)
```


## 🏗️ 2025 Enterprise Hybrid Architecture

**3-Level GitOps Pattern** following Netflix/Google/Meta best practices:

```
🚀 LEVEL 1: BOOTSTRAP (App-of-Apps Pattern)
bootstrap/
├── security.yaml          # Wave 0: Zero Trust Foundation
├── infrastructure.yaml    # Wave 1: Core Infrastructure
├── platform.yaml         # Wave 15: Platform Services
└── apps.yaml             # Wave 25: Applications

🛡️ LEVEL 2: SECURITY ApplicationSets (Wave 0)
security/
├── security-foundation   # RBAC, Pod Security, Network Policies
└── security-governance   # Policy Engines, Compliance, Audit

🏗️ LEVEL 2: INFRASTRUCTURE ApplicationSets (Wave 1-6)
infrastructure/
├── infrastructure-controllers    # ArgoCD, Cert-Manager, Sealed Secrets
├── infrastructure-network       # Cilium CNI, Istio Service Mesh, Gateway API
├── infrastructure-storage       # Rook-Ceph, Proxmox CSI, Velero Backup
├── infrastructure-monitoring    # Prometheus, Grafana, Metrics Server
└── infrastructure-observability # Vector, Elasticsearch, Kibana

🛠️ LEVEL 2: PLATFORM ApplicationSets (Wave 15-18)
platform/
├── platform-identity    # LLDAP, Authelia OIDC
├── platform-data       # PostgreSQL, MongoDB, InfluxDB
├── platform-developer  # Backstage
└── platform-messaging  # Kafka, Redpanda Console, Schema Registry

📱 LEVEL 2: APPS ApplicationSets (Wave 25-26)
apps/
├── apps-dev            # Development (auto-sync, 5 retries)
├── apps-staging        # Pre-prod testing (auto-sync, 3 retries)
└── apps-prod           # Production (manual-sync only)

🎯 LEVEL 3: KUSTOMIZE CONTROL (TRUE Control)
*/kustomization.yaml      # Comment/Uncomment = Enable/Disable
```

### Component Overview

| Layer | Components | Wave | Sync Policy |
|-------|------------|------|-------------|
| **Security** | RBAC, Pod Security, Network Policies | 0 | Auto |
| **Infrastructure** | 25+ Core Services (CNI, Storage, Monitoring) | 1-6 | Auto |
| **Platform** | 8+ Platform Services (Data, Identity, Messaging) | 15-18 | Auto |
| **Apps** | User Applications (3 environments) | 25-26 | Dev/Staging: Auto, Prod: Manual |

## 🔍 Enterprise Features

### 🛡️ Zero Trust Security
- **Pod Security Standards**: Baseline + Restricted policies
- **Network Policies**: Micro-segmentation between services
- **RBAC**: Least-privilege access control
- **OIDC Integration**: Authelia + LLDAP authentication

### 🚀 GitOps Best Practices
- **App-of-Apps Pattern**: Single bootstrap entry point
- **ApplicationSet Discovery**: Auto-discovery of components
- **Kustomize Control**: Comment/uncomment for enable/disable
- **Sync Waves**: Ordered deployment (0 → 1-6 → 15-18 → 25-26)

### 🏢 Enterprise Sync Policies
- **Development**: Auto-sync enabled (fast iteration)
- **Staging**: Auto-sync enabled (pre-prod testing)
- **Production**: Manual sync only (enterprise control)

### 📊 Observability Stack
- **Metrics**: Prometheus + Grafana + AlertManager
- **Logs**: Vector + Elasticsearch + Kibana
- **Traces**: Jaeger distributed tracing
- **Service Mesh**: Istio with mTLS

## 🔧 Operations

### Verification Commands
```bash
# Check bootstrap applications
kubectl get applications -n argocd | grep -E "(security|infrastructure|platform|apps)$"

# Check all ApplicationSets (should see 12 total)
kubectl get applicationsets -n argocd

# Check component applications
kubectl get applications -n argocd | grep -E "(security-|infrastructure-|platform-|apps-)"

# Monitor sync status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"
```

### Troubleshooting
```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Check application details
kubectl describe application <app-name> -n argocd

# Force refresh application
kubectl patch application <app-name> -n argocd --type='merge' -p='{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## 🎯 Enterprise Benefits

| Feature | Benefit |
|---------|---------|
| **3-Level Architecture** | Clear separation of concerns, scalable to 1000+ apps |
| **Domain ApplicationSets** | Clean ArgoCD UI, perfect for debugging |
| **Zero Trust Security** | Enterprise-grade security foundation |
| **Environment Separation** | Dev auto-sync, Prod manual control |
| **TRUE Kustomize Control** | Git-native, no complex ApplicationSet logic |
| **Netflix/Google Patterns** | Battle-tested at scale, enterprise ready |

---

> **Built with** 2025 Enterprise GitOps Best Practices
> **Inspired by** Netflix, Google, Meta, Spotify GitOps Architectures