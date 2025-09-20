# 🚀 KUBERNETES ENTERPRISE TIER-0 NON PLUS ULTRA
## Netflix/Google/Meta/Amazon ULTIMATE Pattern - Individual Applications

**🔥 THE ULTIMATE KUBERNETES ARCHITECTURE PATTERN!**

---

## 🎯 ULTIMATE BOOTSTRAP OPTIONS

### **🚀 OPTION 1: ONE COMMAND TO RULE THEM ALL (RECOMMENDED)**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🔥 NON PLUS ULTRA - Everything at once!
kubectl apply -k kubernetes/

# OR if you want to see what would be applied first:
kubectl kustomize kubernetes/ | less
```

### **🎮 OPTION 2: LAYER-BY-LAYER BOOTSTRAP**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🏗️ Infrastructure first (Network, Controllers, Storage, Monitoring)
kubectl apply -k kubernetes/infrastructure/

# 🏭 Platform services when infrastructure is ready
kubectl apply -k kubernetes/platform/

# 🎯 Applications last (Business apps - Dev/Prod)
kubectl apply -k kubernetes/apps/

# 🗂️ OR use legacy ApplicationSets approach
kubectl apply -k kubernetes/sets/
```

### **🎯 OPTION 3: ULTRA-GRANULAR CONTROL**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# Network only
kubectl apply -f kubernetes/infrastructure/network/cilium-app.yaml
kubectl apply -f kubernetes/infrastructure/network/gateway-app.yaml

# Controllers only
kubectl apply -f kubernetes/infrastructure/controllers/argocd-app.yaml
kubectl apply -f kubernetes/infrastructure/controllers/cert-manager-app.yaml

# Platform services only
kubectl apply -f kubernetes/platform/kafka-app.yaml
kubectl apply -f kubernetes/platform/mongodb-app.yaml

# Applications only (environment-specific)
kubectl apply -f kubernetes/apps/audiobookshelf-dev-app.yaml
kubectl apply -f kubernetes/apps/n8n-prod-app.yaml
```

### **🔧 OPTION 4: MANUAL FOUNDATION BOOTSTRAP (Expert Mode)**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 📋 Step 0: CRDs and Gateway API (if needed)
kubectl apply -k kubernetes/infrastructure/crds

# 🌐 Step 1: Network Foundation (Manual Kustomize)
kubectl kustomize --enable-helm kubernetes/infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-base | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-cni | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-control-plane | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-gateway | kubectl apply -f -

# 🔐 Step 2: Security & Secrets (Manual Kustomize)
# 1. Bootstrap persistent key from terraform certificates
kubernetes/infrastructure/controllers/sealed-secrets/bootstrap-persistent-key.sh
# 2. Deploy controller with persistent key
kustomize build --enable-helm kubernetes/infrastructure/controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/controllers/cert-manager | kubectl apply -f -

# 💾 Step 3: Storage Foundation (Manual Kustomize)
kustomize build --enable-helm kubernetes/infrastructure/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A
kustomize build --enable-helm kubernetes/infrastructure/storage/rook-ceph | kubectl apply -f -

# 🎮 Step 4: GitOps Engine (Manual Kustomize)
kustomize build --enable-helm kubernetes/infrastructure/controllers/argocd | kubectl apply -f -

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### **🚨 BOOTSTRAP CONFLICT ANALYSIS**

**❌ PROBLEMATIC APPROACH (Avoid This!):**
```bash
# This creates conflicts between manual deployment and ArgoCD management!
kubectl kustomize --enable-helm kubernetes/infrastructure/network/cilium | kubectl apply -f -
kubectl apply -k kubernetes/infrastructure/  # ← Will conflict with manual cilium!
```

**✅ RECOMMENDED MIXED APPROACH (Best of Both Worlds):**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🔧 PHASE 1: FOUNDATION (Manual - Keep your favorite commands!)
kubectl kustomize --enable-helm kubernetes/infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-base | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-cni | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-control-plane | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infrastructure/network/istio-gateway | kubectl apply -f -
# 1. Bootstrap persistent key from terraform certificates
kubernetes/infrastructure/controllers/sealed-secrets/bootstrap-persistent-key.sh
# 2. Deploy controller with persistent key
kustomize build --enable-helm kubernetes/infrastructure/controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/controllers/cert-manager | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/storage/proxmox-csi | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/storage/rook-ceph | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/controllers/argocd | kubectl apply -f -

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 🏭 PHASE 2: PLATFORM & APPS (ArgoCD managed - No conflicts!)
kubectl apply -k kubernetes/platform/   # ArgoCD Applications for Platform services
kubectl apply -k kubernetes/apps/       # ArgoCD Applications for Business apps

# 🚫 IMPORTANT: Don't run kubectl apply -k kubernetes/infrastructure/
#    This would create ArgoCD Applications that conflict with manual deployments!
```

**✅ ALTERNATIVE: PURE ARGOCD APPROACH (True GitOps):**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🎮 PHASE 1: Bootstrap ArgoCD only
kubectl kustomize --enable-helm kubernetes/infrastructure/controllers/argocd | kubectl apply -f -
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 🚀 PHASE 2: Let ArgoCD manage everything
kubectl apply -k kubernetes/infrastructure/  # ArgoCD manages ALL infrastructure
kubectl apply -k kubernetes/platform/        # ArgoCD manages platform
kubectl apply -k kubernetes/apps/            # ArgoCD manages apps
```

**✅ ULTIMATE: ROOT BOOTSTRAP (Non Plus Ultra):**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🎮 Bootstrap ArgoCD manually first
kubectl kustomize --enable-helm kubernetes/infrastructure/controllers/argocd | kubectl apply -f -
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 🚀 ONE COMMAND TO RULE THEM ALL
kubectl apply -k kubernetes/  # Everything through root kustomization!
```

### **📊 BOOTSTRAP APPROACHES SUMMARY**

| Approach | Manual Commands | ArgoCD Infrastructure | ArgoCD Platform | ArgoCD Apps | Conflicts |
|----------|-----------------|----------------------|-----------------|-------------|-----------|
| **Mixed (Recommended)** | ✅ Foundation | ❌ Skip | ✅ Yes | ✅ Yes | ❌ None |
| **Pure ArgoCD** | ❌ ArgoCD only | ✅ Yes | ✅ Yes | ✅ Yes | ❌ None |
| **Root Bootstrap** | ❌ ArgoCD only | ✅ Yes | ✅ Yes | ✅ Yes | ❌ None |
| **❌ Problematic** | ✅ Foundation | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ **CONFLICTS!** |

**🎯 Choose Your Fighter:**
- **Mixed**: Keep manual commands for foundation + ArgoCD for platform/apps
- **Pure ArgoCD**: Everything managed by ArgoCD (true GitOps)
- **Root Bootstrap**: Ultimate one-command deployment

---

## 🎮 NON PLUS ULTRA CONTROL SYSTEM

### **🔥 GRANULAR KUSTOMIZE CONTROL (The Ultimate Way)**

**Edit kustomization.yaml files to enable/disable ANY component with comments!**

#### **🏗️ Infrastructure Control** (`kubernetes/infrastructure/kustomization.yaml`)
```yaml
resources:
  # 🌐 NETWORK LAYER
  - network/cilium-app.yaml           # ✅ Core CNI - ENABLED
  - network/gateway-app.yaml          # ✅ Gateway API - ENABLED
  - network/istio-base-app.yaml       # ✅ Service Mesh - ENABLED
  # - network/istio-cni-app.yaml      # ❌ DISABLED (comment to disable)
  # - network/cloudflared-app.yaml    # ❌ DISABLED (tunnel not needed)

  # 🎮 CONTROLLERS LAYER
  - controllers/argocd-app.yaml       # ✅ GitOps Controller - ENABLED
  - controllers/cert-manager-app.yaml # ✅ Certificate Management - ENABLED
  - controllers/sealed-secrets-app.yaml # ✅ Secret Management - ENABLED
  # - controllers/cloudnative-pg-app.yaml # ❌ DISABLED (don't need PostgreSQL)
```

#### **🏭 Platform Control** (`kubernetes/platform/kustomization.yaml`)
```yaml
resources:
  # 🗄️ DATA SERVICES
  - influxdb-app.yaml                 # ✅ Time-series database - ENABLED
  - mongodb-app.yaml                  # ✅ Document database - ENABLED
  # - cloudbeaver-app.yaml            # ❌ DISABLED (DB UI not needed)

  # 📨 MESSAGING SERVICES
  - kafka-app.yaml                    # ✅ Message broker - ENABLED
  # - schema-registry-app.yaml        # ❌ DISABLED (schema mgmt not needed)

  # 👨‍💻 DEVELOPER SERVICES
  - backstage-app.yaml                # ✅ Developer portal - ENABLED
```

#### **🎯 Applications Control** (`kubernetes/apps/kustomization.yaml`)
```yaml
resources:
  # 🎯 DEVELOPMENT APPLICATIONS
  - audiobookshelf-dev-app.yaml       # ✅ Media server (dev) - ENABLED
  - n8n-dev-app.yaml                  # ✅ Workflow automation (dev) - ENABLED
  - kafka-demo-dev-app.yaml           # ✅ Messaging demo (dev) - ENABLED

  # 🏭 PRODUCTION APPLICATIONS
  - audiobookshelf-prod-app.yaml      # ✅ Media server (prod) - ENABLED
  - n8n-prod-app.yaml                 # ✅ Workflow automation (prod) - ENABLED
  # - kafka-demo-prod-app.yaml        # ❌ DISABLED (no prod deployment needed)
```

#### **🚀 Root Control** (`kubernetes/kustomization.yaml`)
```yaml
resources:
  # Enable/disable entire layers!
  - infrastructure/tier0-infrastructure.yaml  # ✅ Infrastructure - ENABLED
  # - platform/kustomization.yaml            # ❌ Platform - DISABLED
  # - apps/kustomization.yaml                # ❌ Apps - DISABLED
```

### **🎯 HOW TO TOGGLE COMPONENTS**

```bash
# 1. Edit the kustomization.yaml file
vim kubernetes/infrastructure/kustomization.yaml

# 2. Comment/uncomment lines:
# - network/istio-base-app.yaml      # ❌ DISABLED
- network/istio-base-app.yaml        # ✅ ENABLED

# 3. Apply changes
kubectl apply -k kubernetes/infrastructure/
```

---

## 🗂️ LEGACY APPLICATIONSET DEPLOYMENT

### **ApplicationSet Deployment (After Foundation)**

#### **🎯 ENTERPRISE TIER-0: Granular Service Control (Legacy)**

**🏗️ Infrastructure Layers**
```bash
# 🌐 Network only (Cilium, Istio, Gateway)
kubectl apply -k kubernetes/infrastructure/layers/network

# 🎮 Controllers only (ArgoCD, Cert-Manager, Sealed Secrets)
kubectl apply -k kubernetes/infrastructure/layers/controllers

# 💾 Storage only (Rook Ceph, Proxmox CSI, Velero)
kubectl apply -k kubernetes/infrastructure/layers/storage

# 📊 Monitoring only (Prometheus, Grafana, Metrics Server)
kubectl apply -k kubernetes/infrastructure/layers/monitoring

# 🔍 Observability only (Jaeger, OpenTelemetry, Vector)
kubectl apply -k kubernetes/infrastructure/layers/observability
```

**🛠️ Platform Services**
```bash
# 💾 Data Platform only (N8N, InfluxDB, CloudBeaver, PostgreSQL)
kubectl apply -k kubernetes/platform/layers/data

# 📬 Messaging only (Kafka, Schema Registry, Redpanda Console)
kubectl apply -k kubernetes/platform/layers/messaging

# 🔧 Developer Portal only (Backstage)
kubectl apply -k kubernetes/platform/layers/developer
```

**📱 Individual Applications**
```bash
# 🎵 Audiobookshelf only (dev + prod)
kubectl apply -k kubernetes/apps/layers/kustomization-audiobookshelf.yaml

# 🔄 N8N only (dev + prod)
kubectl apply -k kubernetes/apps/layers/kustomization-n8n.yaml

# 📨 Kafka Demo only (dev + prod)
kubectl apply -k kubernetes/apps/layers/kustomization-kafka-demo.yaml

# 🚀 All applications together
kubectl apply -k kubernetes/apps/layers/all-apps.yaml
```

**🎯 Complete Service Stacks**
```bash
# 🌐 Complete Istio Service Mesh (all 4 components)
kubectl apply -k kubernetes/infrastructure/layers/istio-complete.yaml

# 🛠️ Complete Platform Services (data + messaging + developer)
kubectl apply -k kubernetes/platform/layers/all-platform.yaml

# 💾 Complete Storage Stack (Rook Ceph + Proxmox CSI)
kubectl apply -k kubernetes/infrastructure/layers/storage-complete.yaml

# 🔐 Complete Security Stack (Sealed Secrets + Cert Manager)
kubectl apply -k kubernetes/infrastructure/layers/security-complete.yaml
```

#### **🏗️ Full Layer Deployment**
```bash
# 🏗️ Deploy all Infrastructure ApplicationSets
kubectl apply -k kubernetes/infrastructure

# 🛠️ Deploy all Platform ApplicationSets
kubectl apply -k kubernetes/platform

# 📱 Deploy all Application ApplicationSets
kubectl apply -k kubernetes/apps

# 🚀 OR single command (deploys everything)
kubectl apply -k kubernetes/sets
```

### **Verification Commands**
```bash
# Check foundation pods
kubectl get pods -n cilium-system
kubectl get pods -n istio-system
kubectl get pods -n argocd
kubectl get pods -n rook-ceph

# Check storage capacity
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A

# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check generated Applications (should show 60+)
kubectl get applications -n argocd
```

---

## 📋 SBOM (Software Bill of Materials)

### **✅ Foundation Components**
- ✅ **Cilium** - CNI with Gateway API and L2 announcements
- ✅ **Hubble** - Network observability and monitoring
- ✅ **Istio Service Mesh** - Ambient mode with ztunnel
- ✅ **ArgoCD** - GitOps engine with ApplicationSets
- ✅ **Sealed Secrets** - Secret encryption controller
- ✅ **Proxmox CSI** - VM storage integration
- ✅ **Rook Ceph** - Distributed storage cluster
- ✅ **Gateway API** - Next-gen ingress and traffic management

### **🔄 Platform Services**
- ✅ **CNPG** - Cloud Native PostgreSQL operator
- ✅ **Cert-Manager** - Certificate lifecycle management
- ✅ **Cloudflared** - Tunnel management

### **📊 Monitoring Stack**
- ✅ **Prometheus** - Metrics collection and alerting
- ✅ **Grafana** - Dashboards and visualization
- ✅ **Loki** - Log aggregation
- ✅ **Jaeger** - Distributed tracing

### **🚧 TODO - Tier-0 Enterprise Roadmap**

**🎯 Current Status: LEVEL 4/5 (Advanced) - 90% Tier-0 Complete**

**Phase 1: Policy & Governance (Tier-0 Completion)**
- [ ] **OPA Gatekeeper** - Policy as Code (`kubernetes/governance/policies/`)
- [ ] **Security Policies** - Automated compliance enforcement
- [ ] **Resource Quotas** - Enterprise resource governance

**Phase 2: Multi-Cluster Governance**
- [ ] **Cluster Generators** - Netflix-style cluster management
- [ ] **Environment Classification** - Production/staging cluster patterns
- [ ] **Cross-Cluster ApplicationSets** - Uber-level multi-cluster orchestration

**Phase 3: Zero-Trust Security**
- [ ] **External Secrets Operator** - Enterprise secret management (`kubernetes/infrastructure/controllers/external-secrets/`)
- [ ] **Vault Integration** - HashiCorp Vault for zero-trust secrets
- [ ] **Network Policies** - Micro-segmentation with Cilium

**Phase 4: Enhanced Observability**
- [ ] **GitOps Metrics** - ArgoCD metrics integration with Prometheus
- [ ] **Business KPI Correlation** - Git commit → deployment success tracking
- [ ] **MTTR Tracking** - Mean Time To Recovery analytics
- [ ] **Deployment Frequency** - DevOps DORA metrics

**Phase 5: Platform Engineering**
- [ ] **Component Library** - Reusable Kustomize components (`kubernetes/components/`)
- [ ] **API Management** - Enterprise API gateway layer
- [ ] **Developer Self-Service** - Backstage integration enhancement

### **📊 Tier-0 Benchmarks (Target Metrics)**
- **Deployment Frequency**: >10 deployments/day per team ✅ (Architecture Ready)
- **Lead Time**: <1 hour commit→production ✅ (Infrastructure Ready)
- **MTTR**: <30 minutes for infrastructure issues ✅ (Monitoring Ready)
- **Change Failure Rate**: <5% ✅ (GitOps + Testing Ready)
- **Multi-Cluster Scale**: Support 50+ clusters 🔄 (Needs cluster generators)
- **Policy Compliance**: 100% automated enforcement 🔄 (Needs OPA/Gatekeeper)

### **🏆 Current Enterprise Features (Already Tier-0)**
- ✅ **Sophisticated ApplicationSet Patterns** (15+ specialized ApplicationSets)
- ✅ **Multi-Layer Architecture** (Infrastructure/Platform/Apps separation)
- ✅ **Granular Kustomize Control** (Superior to many Big Tech implementations)
- ✅ **Sync Wave Orchestration** (Proper dependency management)
- ✅ **Progressive Delivery** (Argo Rollouts integration)
- ✅ **Advanced Helm Integration** (Enterprise patterns with --enable-helm)

### **🎯 Legacy TODO (Lower Priority)**
- [ ] **Keycloak/Authentik** - Identity and access management
- [ ] **Velero** - Backup and disaster recovery
- [ ] **OpenTelemetry** - Observability framework

---

## 🏗️ Directory Structure

```
kubernetes/
├── sets/                              # 🚀 Bootstrap Layer
│   ├── kustomization.yaml           # App-of-Apps entry point
│   ├── infrastructure.yaml          # Infrastructure meta-app
│   ├── platform.yaml               # Platform meta-app
│   ├── apps.yaml                   # Applications meta-app
│   └── applicationsets.yaml        # ApplicationSets bootstrap
│
├── applicationsets/                   # 🎯 ApplicationSet Definitions
│   ├── applications.yaml           # Multi-env app generator
│   ├── infrastructure-*.yaml       # Infrastructure ApplicationSets
│   ├── platform-*.yaml            # Platform ApplicationSets
│   └── storage-*.yaml              # Storage ApplicationSets
│
├── infrastructure/                    # 🏗️ Foundation (37 Services)
│   ├── kustomization.yaml          # ApplicationSet references only
│   ├── layers/                     # 🎯 GRANULAR CONTROL
│   │   ├── network.yaml           # Network layer only
│   │   ├── controllers.yaml       # Controllers layer only
│   │   ├── storage.yaml           # Storage layer only
│   │   ├── monitoring.yaml        # Monitoring layer only
│   │   └── observability.yaml     # Observability layer only
│   ├── network/
│   │   ├── cilium/                 # CNI with Gateway API
│   │   ├── istio-*/                # Service mesh stack
│   │   └── gateway/                # Envoy Gateway
│   ├── storage/
│   │   ├── rook-ceph/             # Distributed storage
│   │   ├── proxmox-csi/           # VM storage
│   │   └── minio/                 # Object storage
│   ├── controllers/
│   │   ├── argocd/                # GitOps engine
│   │   ├── cert-manager/          # Certificates
│   │   └── sealed-secrets/        # Secret encryption
│   ├── monitoring/
│   │   ├── prometheus/            # Metrics
│   │   ├── grafana/               # Dashboards
│   │   └── loki/                  # Logs (disabled)
│   └── backup/
│       └── velero/                 # Disaster recovery
│
├── platform/                         # 🛠️ Platform Services (10 Services)
│   ├── kustomization.yaml          # Platform ApplicationSets
│   ├── layers/                     # 🎯 GRANULAR CONTROL
│   │   ├── data.yaml              # Data platform only
│   │   ├── messaging.yaml         # Messaging platform only
│   │   └── developer.yaml         # Developer platform only
│   ├── data/
│   │   ├── n8n/                   # Workflow DB (PostgreSQL)
│   │   ├── cloudbeaver/           # DB management UI
│   │   └── influxdb/              # Time-series DB
│   ├── messaging/
│   │   ├── kafka/                 # Event streaming
│   │   ├── schema-registry/       # Schema management
│   │   └── redpanda-console/      # Kafka UI
│   └── developer/
│       └── backstage/             # Developer portal
│
└── apps/                            # 📱 Applications (4 Services x 2 Envs)
    ├── applications.yaml           # Matrix generator
    ├── layers/                     # 🎯 GRANULAR CONTROL
    │   ├── audiobookshelf.yaml    # Audiobookshelf only
    │   ├── n8n.yaml               # N8N only
    │   ├── kafka-demo.yaml        # Kafka Demo only
    │   ├── kustomization-*.yaml   # Individual app kustomizations
    │   └── all-apps.yaml          # All applications together
    ├── base/                      # Service templates
    │   ├── audiobookshelf/        # Media platform
    │   ├── n8n/                   # Workflow automation
    │   ├── kafka-demo/            # Event demo
    │   └── quantlab.disabled/     # Analytics (disabled)
    └── overlays/                   # Environment configs
        ├── dev/                   # Development
        └── prod/                  # Production
```

---

## 🎛️ Kustomize Control

### **Bootstrap Layer**
```yaml
# sets/kustomization.yaml
resources:
  - infrastructure.yaml    # Deploys infrastructure ApplicationSets
  - platform.yaml        # Deploys platform ApplicationSets
  - apps.yaml            # Deploys application ApplicationSets
```

### **Infrastructure Layer**
```yaml
# infrastructure/kustomization.yaml
resources:
  - ../applicationsets/infrastructure-network.yaml
  - ../applicationsets/infrastructure-storage.yaml
  - ../applicationsets/infrastructure-monitoring.yaml
```

### **Application Generation**
```yaml
# apps/applications.yaml - Matrix Generator
generators:
  - matrix:
      generators:
        - git:
            directories: ["kubernetes/apps/base/*"]
        - list:
            elements:
              - env: dev
              - env: prod
# Result: audiobookshelf-dev, audiobookshelf-prod, n8n-dev, n8n-prod
```

---

## 📊 Storage Classes

```bash
$ kubectl get storageclass
rook-ceph-block-enterprise (default)   # Primary storage
rook-ceph-block-ssd                    # SSD storage
rook-cephfs-enterprise                 # Shared filesystem
proxmox-csi                            # VM storage
```

---

## 🚦 Verification

```bash
# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check applications (should show 60+)
kubectl get applications -n argocd

# Check infrastructure
kubectl get pods -n rook-ceph
kubectl get pods -n argocd

# Check platform
kubectl get pods -n kafka
kubectl get pods -n backstage

# Check apps
kubectl get pods -n audiobookshelf-prod
kubectl get pods -n n8n-dev
```

---

## 🚨 Troubleshooting

**Rook-Ceph stuck:**
```bash
kubectl patch cephcluster rook-ceph -n rook-ceph --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

**ApplicationSet not generating:**
```bash
kubectl describe applicationset applications -n argocd
```

**Velero issues:**
```bash
kubectl get crd | grep velero
```

---

*Enterprise GitOps following Netflix/Google/Amazon patterns*