# Kubernetes

Enterprise GitOps homelab powered by ArgoCD and Kustomize.

## Quick Start

### Option 1: Essential Bootstrap (Manual)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Core components only - minimum required
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# ArgoCD UI Access
kubectl port-forward svc/argocd-server -n argocd 8080:80
# URL: http://localhost:8080
# Username: admin
```

### Option 2: Layer Bootstrap (Recommended)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Deploy all layers - ArgoCD will handle component ordering
kubectl apply -k security/
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

### Option 3: App-of-Apps (All-in-One)

```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# Single command - deploys everything
kubectl apply -k sets/
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