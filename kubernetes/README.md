# 🏢 Enterprise Tier-0 GitOps Architecture

Netflix/Google/Amazon/Meta Style Platform Engineering

---

## 🚀 Bootstrap Commands

### **Foundation Bootstrap (Manual)**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🌐 Step 1: Network Foundation
kubectl apply -k kubernetes/infrastructure/network/cilium
kubectl apply -k kubernetes/infrastructure/network/istio-base
kubectl apply -k kubernetes/infrastructure/network/istio-cni
kubectl apply -k kubernetes/infrastructure/network/istio-control-plane
kubectl apply -k kubernetes/infrastructure/network/istio-gateway

# 🔐 Step 2: Security & Secrets
kubectl apply -k kubernetes/infrastructure/controllers/sealed-secrets

# 💾 Step 3: Storage Foundation
kubectl apply -k kubernetes/infrastructure/storage/proxmox-csi
kubectl apply -k kubernetes/infrastructure/storage/rook-ceph

# 🎮 Step 4: GitOps Engine
kubectl apply -k kubernetes/infrastructure/controllers/argocd

# Wait for ArgoCD to be ready, then deploy ApplicationSets
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### **ApplicationSet Deployment (After Foundation)**
```bash
# 🚀 Deploy ApplicationSets for automation
kubectl apply -k kubernetes/infrastructure  # Infrastructure ApplicationSets
kubectl apply -k kubernetes/platform       # Platform ApplicationSets
kubectl apply -k kubernetes/apps           # Application ApplicationSets

# OR single command (after foundation is ready)
kubectl apply -k kubernetes/sets
```

### **Verification Commands**
```bash
# Check foundation pods
kubectl get pods -n cilium-system
kubectl get pods -n istio-system
kubectl get pods -n argocd
kubectl get pods -n rook-ceph

# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check generated Applications
kubectl get applications -n argocd
```

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
│   │   └── loki/                  # Logs
│   └── backup/
│       └── velero/                 # Disaster recovery
│
├── platform/                         # 🛠️ Platform Services (10 Services)
│   ├── kustomization.yaml          # Platform ApplicationSets
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
    ├── base/                      # Service templates
    │   ├── audiobookshelf/        # Media platform
    │   ├── n8n/                   # Workflow automation
    │   ├── kafka-demo/            # Event demo
    │   └── quantlab/              # Analytics
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