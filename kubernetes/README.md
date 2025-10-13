# 🚀 Enterprise Kubernetes GitOps Architecture

> **2025 Enterprise Hybrid Pattern** - Netflix/Google/Meta Level GitOps Implementation

**Production-grade 4-layer GitOps architecture** implementing 2025 enterprise best practices with **Zero Trust Foundation**, **Domain-based ApplicationSets**, and **TRUE Kustomize Control**.

## 🎯 Quick Start

### Option 1: Bootstrap Applications (Recommended)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 🚀 Deploy complete enterprise stack via ArgoCD App-of-Apps
kubectl apply -k bootstrap/

# 🔍 Monitor deployment
kubectl get applications -n argocd -w
```

### Option 2: Enterprise Bootstrap Pattern (2-Step Control)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 🎯 STEP 1: BOOTSTRAP - Deploys ONLY Projects + ApplicationSets (no individual services)
#           Fast bootstrap without waiting for Helm charts
kubectl apply -k security/           # Wave 0: Security ApplicationSets
kubectl apply -k infrastructure/     # Wave 1: Infrastructure ApplicationSets
kubectl apply -k platform/          # Wave 15: Platform ApplicationSets
kubectl apply -k apps/              # Wave 25: Apps ApplicationSets

# 🎯 STEP 2: GRANULAR CONTROL - Comment/Uncomment in ApplicationSet files
#           Individual services ein/ausschalten nach Bootstrap
# Edit: infrastructure/monitoring-app.yaml, infrastructure/network-app.yaml, etc.
# Comment/Uncomment services to enable/disable after bootstrap
```

### Option 3: Manual Core Bootstrap (Minimal)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Core components only - minimum required for enterprise ArgoCD
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/network/sail-operator | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/network/istio-control-plane | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# Then deploy remaining components via ArgoCD UI
```

### ArgoCD Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
# 🌐 URL: http://localhost:8080 (admin / <password>)
```


## 🏗️ 2025 Enterprise Bootstrap Architecture

**🎯 2-Step Bootstrap Pattern** following Netflix/Google/Meta best practices:

### 🚀 Enterprise Bootstrap Pattern

**STEP 1: Bootstrap** - `kubectl apply -k` deploys only Projects + ApplicationSets
**STEP 2: Granular Control** - Comment/Uncomment in ApplicationSet files for individual services

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

🎯 STEP 2: GRANULAR CONTROL (ApplicationSet Control)
*/monitoring-app.yaml     # Comment/Uncomment services = Enable/Disable
*/network-app.yaml        # Example: Comment grafana = Disable Grafana
*/data-app.yaml           # Example: Comment postgresql = Disable PostgreSQL
```

### Component Overview

| Layer | Components | Wave | Sync Policy |
|-------|------------|------|-------------|
| **Security** | RBAC, Pod Security, Network Policies | 0 | Auto |
| **Infrastructure** | 25+ Core Services (CNI, Storage, Monitoring) | 1-6 | Auto |
| **Platform** | 8+ Platform Services (Data, Identity, Messaging) | 15-18 | Auto |
| **Apps** | User Applications (3 environments) | 25-26 | Dev/Staging: Auto, Prod: Manual |

### 🎛️ Kubernetes Operators

**Enterprise operators managing lifecycle, scaling, and HA for complex stateful workloads:**

| Operator | Purpose | Namespace | Version | Manages | Deployment |
|----------|---------|-----------|---------|---------|------------|
| **Cilium Operator** | CNI networking + eBPF dataplane | kube-system | v1.17.0 | Pod networking, Network Policies, Hubble | Kustomize + Helm |
| **Rook-Ceph Operator** | Storage orchestration (Block, Object, File) | rook-ceph | v1.16.0 | CephCluster, CephBlockPool, CephFilesystem | Kustomize + Helm |
| **Sail Operator** | Istio service mesh lifecycle | istio-system | v0.1.3 | Istio control plane, Gateways | Kustomize + Helm |
| **Cert-Manager** | TLS certificate automation | cert-manager | v1.17.0 | Certificates, Issuers, ClusterIssuers | Kustomize + Helm |
| **Prometheus Operator** | Metrics collection & alerting | monitoring | v0.77.0 | Prometheus, AlertManager, ServiceMonitors | Kustomize + Helm (kube-prometheus-stack) |
| **Grafana Operator** | Dashboard & visualization lifecycle | grafana | v5.17.0 | Grafana, Dashboards, Datasources | Kustomize + Helm |
| **Jaeger Operator** | Distributed tracing | jaeger | v1.63.0 | Jaeger instances, Collectors, Queries | Kustomize + Helm |
| **Elastic Operator** | Elasticsearch & Kibana orchestration | elastic-system | v2.17.0 | Elasticsearch clusters, Kibana instances | Kustomize + Helm |
| **OpenTelemetry Operator** | Observability data collection | opentelemetry | v0.114.0 | Collectors, Instrumentation | Kustomize + Helm |
| **Confluent Operator** | Kafka enterprise features & lifecycle | confluent | v2.11.0 | Kafka clusters, Connect, Schema Registry | Kustomize + Helm |
| **Redis Operator** | Redis standalone/sentinel/replication | redis-operator-system | v0.18.0 | Redis, RedisCluster, RedisSentinel | Kustomize + Helm |
| **Tailscale Operator** | VPN connectivity & routing | tailscale | v1.78.3 | Connectors, Subnet routes | Kustomize + Helm |
| **CloudNativePG Operator** | PostgreSQL HA clusters | cnpg-system | v1.25.1 | PostgreSQL Clusters, Backups, Poolers | Kustomize + Helm |

**Key Benefits:**
- **Automated Lifecycle**: Upgrades, scaling, backups managed by operators
- **Self-Healing**: Operators monitor CRs and reconcile desired state
- **Enterprise HA**: Multi-replica deployments with auto-failover
- **GitOps Native**: All operators deployed via ArgoCD + Kustomize
- **Consistent Pattern**: All use Kustomize + Helm for declarative config

## 🔍 Enterprise Features

### 🛡️ Zero Trust Security
- **Pod Security Standards**: Baseline + Restricted policies
- **Network Policies**: Micro-segmentation between services
- **RBAC**: Least-privilege access control
- **OIDC Integration**: Authelia + LLDAP authentication

### 🚀 GitOps Best Practices
- **App-of-Apps Pattern**: Single bootstrap entry point
- **2-Step Bootstrap**: Fast kubectl apply -k bootstrap, then granular control
- **ApplicationSet Control**: Comment/uncomment in ApplicationSet files for enable/disable
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
| **2-Step Bootstrap Pattern** | Fast kubectl apply -k bootstrap, then granular control |
| **ApplicationSet Control** | Comment/uncomment services in ApplicationSet files |
| **Zero Trust Security** | Enterprise-grade security foundation |
| **Environment Separation** | Dev auto-sync, Prod manual control |
| **Git-native Control** | No complex logic, simple comment/uncomment pattern |
| **Netflix/Google Patterns** | Battle-tested at scale, enterprise ready |

---

> **Built with** 2025 Enterprise GitOps Best Practices
> **Inspired by** Netflix, Google, Meta, Spotify GitOps Architectures
