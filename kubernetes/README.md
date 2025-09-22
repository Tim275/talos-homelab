# Kubernetes

Enterprise GitOps homelab powered by ArgoCD and Kustomize.

## Quick Start

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy all layers
kubectl apply -k security/
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

## One-Command Deploy Everything (App-of-Apps)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy ALL layers with single command via ArgoCD App-of-Apps
kubectl apply -k sets/

# ArgoCD will automatically deploy in correct order:
# 0. Security (sync-wave: 0)
# 1. Infrastructure (sync-wave: 1)
# 2. Platform (sync-wave: 15)
# 3. Apps (sync-wave: 25)
```

## One-Command Deploy Everything (Direct)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy ALL layers with single command (direct)
kubectl apply -k security/ && kubectl apply -k infrastructure/ && kubectl apply -k platform/ && kubectl apply -k apps/
```

## Standard Layer Bootstrap (Gitiles Pattern)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy each layer individually with Gitiles Pattern control
kubectl apply -k security/        # Security foundation (wave 0)
kubectl apply -k infrastructure/  # Core infrastructure (wave 1)
kubectl apply -k platform/        # Platform services (wave 15)
kubectl apply -k apps/            # Applications (wave 25)
```

## Core Components Bootstrap (Manual)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# === ESSENTIAL BOOTSTRAP (Manual Component Deployment) ===
# Cilium CNI (MUST BE FIRST!)
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -

# Sealed Secrets (Secret Management)
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -

# Rook-Ceph Storage
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -

# ArgoCD (GitOps Platform)
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# === ADDITIONAL CORE COMPONENTS ===
# Cert-Manager (Certificate Management)
kubectl kustomize --enable-helm infrastructure/controllers/cert-manager | kubectl apply -f -

# CloudNative-PG (PostgreSQL Operator)
kubectl kustomize --enable-helm infrastructure/controllers/cloudnative-pg | kubectl apply -f -

# Argo Rollouts (Progressive Delivery)
kubectl kustomize --enable-helm infrastructure/controllers/argo-rollouts | kubectl apply -f -

# Proxmox CSI (VM Storage)
kubectl kustomize --enable-helm infrastructure/storage/proxmox-csi | kubectl apply -f -

# Prometheus (Monitoring)
kubectl kustomize --enable-helm infrastructure/monitoring/prometheus | kubectl apply -f -

# Grafana (Dashboards)
kubectl kustomize --enable-helm infrastructure/monitoring/grafana | kubectl apply -f -

# Vector (Log Collection)
kubectl kustomize --enable-helm infrastructure/observability/vector | kubectl apply -f -

# Cloudflared (Tunnel)
kubectl kustomize --enable-helm infrastructure/network/cloudflared | kubectl apply -f -

# After core components are ready, deploy ApplicationSets for GitOps
kubectl apply -k sets/
```

## Wave-by-Wave Bootstrap (Production Ready)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# === WAVE 0: CORE CONTROLLERS ===
echo "🎮 Deploying Core Controllers..."
kubectl apply -k infrastructure/controllers/argocd/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

kubectl apply -k infrastructure/controllers/sealed-secrets/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n sealed-secrets --timeout=300s

kubectl apply -k infrastructure/controllers/cert-manager/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s

# === WAVE 1: NETWORK FOUNDATION ===
echo "🌐 Deploying Cilium CNI..."
kubectl apply -k infrastructure/network/cilium/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cilium-operator -n kube-system --timeout=300s

# === WAVE 2: STORAGE FOUNDATION ===
echo "🐙 Deploying Rook-Ceph Storage..."
kubectl apply -k infrastructure/storage/rook-ceph/
kubectl wait --for=condition=established crd/cephclusters.ceph.rook.io --timeout=60s
# Second apply after CRDs are ready
kubectl apply -k infrastructure/storage/rook-ceph/

# === WAVE 3: SERVICE MESH ===
echo "🌊 Deploying Istio Service Mesh..."
kubectl apply -k infrastructure/network/istio-base/
kubectl wait --for=condition=established crd/gateways.gateway.networking.k8s.io --timeout=300s

kubectl apply -k infrastructure/network/istio-cni/
kubectl wait --for=condition=ready pod -l app=istio-cni-node -n istio-system --timeout=300s

kubectl apply -k infrastructure/network/istio-control-plane/
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s

kubectl apply -k infrastructure/network/istio-gateway/
kubectl wait --for=condition=ready pod -l app=istio-gateway -n istio-gateway --timeout=300s

# === WAVE 5: MONITORING ===
echo "📊 Deploying Monitoring Stack..."
kubectl apply -k infrastructure/monitoring/prometheus/
kubectl apply -k infrastructure/monitoring/grafana/
kubectl apply -k infrastructure/monitoring/alertmanager/

# === WAVE 6: OBSERVABILITY ===
echo "🔍 Deploying Observability Stack..."
kubectl apply -k infrastructure/observability/vector/
kubectl apply -k infrastructure/observability/elasticsearch/
kubectl apply -k infrastructure/observability/kibana/

echo "✅ Manual bootstrap complete! ArgoCD ApplicationSets now manage everything."
```

## Manual Bootstrap (Core Components)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Essential components - tested & working bootstrap sequence
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/proxmox-csi | kubectl apply -f -

# ArgoCD Access (after deployment)
kubectl port-forward svc/argocd-server -n argocd 8080:80
# URL: http://localhost:8080
# Username: admin
# Password: HjGrNH2psKBqo5kJ

# Deploy remaining components via GitOps
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

## Structure

```
kubernetes/
├── sets/                              # App-of-Apps Bootstrap (vehagn pattern)
│   ├── kustomization.yaml            # Main bootstrap control
│   ├── project.yaml                  # ArgoCD project for timour-homelab
│   ├── security.yaml                 # Security Application (sync-wave: 0)
│   ├── infrastructure.yaml           # Infrastructure Application (sync-wave: 1)
│   ├── platform.yaml                 # Platform Application (sync-wave: 15)
│   └── apps.yaml                     # Apps Application (sync-wave: 25)
│
├── security/                          # Zero Trust security foundation
│   ├── kustomization.yaml            # Main security control
│   ├── project.yaml                  # ArgoCD project definition
│   └── foundation/                   # Security foundation layer
│       └── network-policies/         # Kubernetes Network Policies
│
├── infrastructure/                    # Core cluster services (22 Apps)
│   ├── kustomization.yaml            # Main infrastructure control
│   ├── project.yaml                  # ArgoCD project definition
│   ├── network/                      # Network Layer (Wave 0-1)
│   │   ├── cilium/                   # CNI with eBPF
│   │   ├── gateway/                  # Gateway API CRDs
│   │   ├── envoy-gateway/            # Envoy Gateway implementation
│   │   ├── istio-base/               # Service mesh base
│   │   ├── istio-cni/                # Istio CNI plugin
│   │   ├── istio-control-plane/      # Istiod control plane
│   │   ├── istio-gateway/            # Istio ingress gateway
│   │   ├── istio-operator/           # Sail Operator
│   │   └── cloudflared/              # Cloudflare tunnel
│   ├── controllers/                  # Controllers Layer (Wave 2-3)
│   │   ├── argocd/                   # GitOps engine
│   │   ├── cert-manager/             # Certificate management
│   │   ├── sealed-secrets/           # Secret encryption
│   │   ├── argo-rollouts/            # Progressive delivery
│   │   └── cloudnative-pg/           # PostgreSQL operator
│   ├── storage/                      # Storage Layer (Wave 1)
│   │   ├── rook-ceph/                # Distributed storage
│   │   ├── proxmox-csi/              # VM storage integration
│   │   └── velero/                   # Backup & disaster recovery
│   ├── monitoring/                   # Monitoring Layer (Wave 5)
│   │   ├── prometheus/               # Metrics & alerting
│   │   ├── alertmanager/             # Alert routing & notifications
│   │   ├── grafana/                  # Dashboards & visualization
│   │   └── jaeger/                   # Distributed tracing
│   └── observability/                # Observability Layer (Wave 5-6)
│       ├── vector/                   # Log collection & processing
│       ├── elasticsearch/            # Search & analytics
│       └── kibana/                   # Log visualization
│
├── platform/                         # Platform services (6 Apps)
│   ├── kustomization.yaml            # Main platform control
│   ├── project.yaml                  # ArgoCD project definition
│   ├── data/                         # Data Layer (Wave 12)
│   │   ├── influxdb/                 # Time-series database
│   │   ├── cloudbeaver/              # Database management UI
│   │   └── n8n/                      # N8N PostgreSQL cluster
│   └── messaging/                    # Messaging Layer (Wave 12-13)
│       ├── kafka/                    # Message broker
│       ├── schema-registry/          # Schema management
│       └── redpanda-console/         # Modern Kafka UI
│
└── apps/                             # User applications (5 Apps)
    ├── kustomization.yaml            # Main applications control
    ├── base/                         # Service base configurations
    │   ├── audiobookshelf/           # Media server templates
    │   ├── n8n/                      # Workflow automation with rollouts
    │   │   └── environments/         # Environment-specific configs
    │   │       ├── dev/              # Development environment
    │   │       └── production/       # Production with Argo Rollouts
    │   └── kafka-demo/               # Kafka demo applications
    ├── overlays/                     # Enterprise tier-0 patterns
    │   ├── dev/                      # Development overrides
    │   │   └── patches/              # Environment-specific patches
    │   └── prod/                     # Production overrides
    │       └── patches/              # Production-grade patches
    ├── audiobookshelf-dev-app.yaml   # Media server (development)
    ├── audiobookshelf-prod-app.yaml  # Media server (production)
    ├── n8n-dev-app.yaml              # Workflow automation (dev)
    ├── n8n-prod-app.yaml             # Workflow automation (prod w/ rollouts)
    └── kafka-demo-dev-app.yaml       # Kafka demo (development)
```

## Verification

```bash
# Check App-of-Apps applications
kubectl get applications -n argocd

# Check all ApplicationSets
kubectl get applicationsets -n argocd

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Check storage
kubectl get csistoragecapacities -A
```

## Architecture

- **ApplicationSet Pattern**: Auto-discovery of applications
- **Kustomize Control**: Comment/uncomment resources to enable/disable
- **4-Layer GitOps**: Security → Infrastructure → Platform → Apps
- **Wave-based Deployment**: Ordered rollout with sync waves