# Kubernetes

Enterprise GitOps homelab powered by ArgoCD and Kustomize.

## Quick Start

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy all layers
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

## All-in-One Bootstrap

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Foundation components with proper ordering
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/proxmox-csi | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# Rook-Ceph (requires 2x deployment for CRDs)
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
sleep 10
kubectl wait --for=condition=established crd/cephclusters.ceph.rook.io --timeout=60s
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -

# Deploy everything else via Kustomize
kubectl kustomize --enable-helm infrastructure/ | kubectl apply -f -
kubectl kustomize --enable-helm platform/ | kubectl apply -f -
kubectl kustomize --enable-helm apps/ | kubectl apply -f -
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

## Manual Bootstrap

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 1. Cilium CNI
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -

# 2. Sealed Secrets
kustomize build --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -

# 3. Proxmox CSI Plugin
kustomize build --enable-helm infrastructure/storage/proxmox-csi | kubectl apply -f -

# 4. ArgoCD
kustomize build --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# 5. Deploy everything else via GitOps
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

## Structure

```
kubernetes/
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
# Check applications
kubectl get applications -n argocd

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