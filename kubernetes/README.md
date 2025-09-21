# 🚀 Enterprise Kubernetes Homelab
## Netflix/Google/Meta Tier-0 Architecture Pattern

**30 Applications deployed across 3 enterprise layers with granular Kustomize control**

---

## 🎯 Quick Start

### **One Command Bootstrap**
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 🏗️ Infrastructure Layer (22 apps)
kubectl apply -k kubernetes/infrastructure/

# 🛠️ Platform Layer (6 apps)
kubectl apply -k kubernetes/platform/

# 📱 Applications Layer (2 apps x 2 environments)
kubectl apply -k kubernetes/apps/
```

### **Verification**
```bash
# Check all applications (should show 30)
kubectl get applications -n argocd

# Check application health
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'
```

---

## 📁 Directory Structure

```
kubernetes/
├── infrastructure/                    # 🏗️ INFRASTRUCTURE LAYER (22 Apps)
│   ├── kustomization.yaml            #     Main infrastructure control
│   ├── project.yaml                  #     ArgoCD project definition
│   │
│   ├── network/                      # 🌐 Network Layer (Wave 0-1)
│   │   ├── cilium-app.yaml          #     ✅ CNI with eBPF
│   │   ├── gateway-app.yaml         #     ✅ Gateway API CRDs
│   │   ├── envoy-gateway-app.yaml   #     ✅ Envoy Gateway implementation
│   │   ├── istio-base-app.yaml      #     ✅ Service mesh base
│   │   ├── istio-cni-app.yaml       #     ✅ Istio CNI plugin
│   │   ├── istio-control-plane-app.yaml # ✅ Istiod control plane
│   │   ├── istio-gateway-app.yaml   #     ✅ Istio ingress gateway
│   │   ├── istio-operator-app.yaml  #     ✅ Sail Operator
│   │   └── cloudflared-app.yaml     #     ✅ Cloudflare tunnel
│   │
│   ├── controllers/                  # 🎮 Controllers Layer (Wave 2-3)
│   │   ├── argocd-app.yaml          #     ✅ GitOps engine
│   │   ├── cert-manager-app.yaml    #     ✅ Certificate management
│   │   ├── sealed-secrets-app.yaml  #     ✅ Secret encryption
│   │   ├── argo-rollouts-app.yaml   #     ✅ Progressive delivery
│   │   └── cloudnative-pg-app.yaml  #     ✅ PostgreSQL operator
│   │
│   ├── storage/                      # 💾 Storage Layer (Wave 1)
│   │   ├── rook-ceph-app.yaml       #     ✅ Distributed storage
│   │   ├── proxmox-csi-app.yaml     #     ✅ VM storage integration
│   │   └── velero-app.yaml          #     ✅ Backup & disaster recovery
│   │
│   ├── monitoring/                   # 📊 Monitoring Layer (Wave 5)
│   │   ├── prometheus-app.yaml      #     ✅ Metrics & alerting
│   │   ├── alertmanager-app.yaml    #     ✅ Alert routing & notifications
│   │   ├── grafana-app.yaml         #     ✅ Dashboards & visualization
│   │   └── jaeger-app.yaml          #     ✅ Distributed tracing
│   │
│   └── observability/                # 🔍 Observability Layer (Wave 5-6)
│       ├── vector-app.yaml          #     ✅ Log collection & processing
│       ├── elasticsearch-app.yaml   #     ✅ Search & analytics
│       └── kibana-app.yaml          #     ✅ Log visualization
│
├── platform/                         # 🛠️ PLATFORM LAYER (6 Apps)
│   ├── kustomization.yaml            #     Main platform control
│   ├── project.yaml                  #     ArgoCD project definition
│   │
│   ├── data/                         # 🗄️ Data Layer (Wave 12)
│   │   ├── influxdb-app.yaml        #     ✅ Time-series database
│   │   ├── cloudbeaver-app.yaml     #     ✅ Database management UI
│   │   └── n8n-app.yaml             #     ✅ N8N PostgreSQL cluster
│   │
│   └── messaging/                    # 📨 Messaging Layer (Wave 12-13)
│       ├── kafka-app.yaml           #     ✅ Message broker
│       ├── schema-registry-app.yaml #     ✅ Schema management
│       └── redpanda-console-app.yaml#     ✅ Modern Kafka UI
│
└── apps/                             # 📱 APPLICATIONS LAYER (2 Apps x 2 Envs)
    ├── kustomization.yaml            #     Main applications control
    │
    ├── base/                         # Service base configurations
    │   ├── audiobookshelf/          #     Media server templates
    │   ├── n8n/                     #     Workflow automation templates
    │   └── kafka-demo/              #     Kafka demo applications
    │
    ├── audiobookshelf-dev-app.yaml  # ✅ Media server (development)
    ├── audiobookshelf-prod-app.yaml # ✅ Media server (production)
    ├── n8n-dev-app.yaml             # ✅ Workflow automation (dev)
    ├── n8n-prod-app.yaml            # ✅ Workflow automation (prod)
    └── kafka-demo-dev-app.yaml      # ✅ Kafka demo (development)
```

---

## 🎛️ Granular Control System

### **🔥 Infrastructure Control** (`infrastructure/kustomization.yaml`)
```yaml
resources:
  # 🌐 NETWORK LAYER (Wave 0-1) - Comment/uncomment to enable/disable
  - network/cilium-app.yaml           # ✅ Core CNI
  - network/gateway-app.yaml          # ✅ Gateway API
  - network/envoy-gateway-app.yaml    # ✅ Envoy Gateway
  - network/istio-base-app.yaml       # ✅ Service Mesh Base
  # - network/cloudflared-app.yaml    # ❌ DISABLED - Tunnel not needed

  # 🎮 CONTROLLERS LAYER (Wave 2-3)
  - controllers/argocd-app.yaml       # ✅ GitOps Controller
  - controllers/cert-manager-app.yaml # ✅ Certificate Management
  # - controllers/cloudnative-pg-app.yaml # ❌ DISABLED - No PostgreSQL needed
```

### **🛠️ Platform Control** (`platform/kustomization.yaml`)
```yaml
resources:
  # 🗄️ DATA LAYER (Wave 12)
  - data/influxdb-app.yaml            # ✅ Time-series database
  # - mongodb-app.yaml                # ❌ DISABLED - Document DB not needed
  - data/cloudbeaver-app.yaml         # ✅ DB management UI

  # 📨 MESSAGING LAYER (Wave 12-13)
  - messaging/kafka-app.yaml          # ✅ Message broker
  - messaging/schema-registry-app.yaml # ✅ Schema management
  # - messaging/kafdrop-app.yaml      # ❌ DISABLED - Use Redpanda Console
```

### **📱 Applications Control** (`apps/kustomization.yaml`)
```yaml
resources:
  # 🎯 DEVELOPMENT LAYER (Wave 20)
  - audiobookshelf-dev-app.yaml       # ✅ Media server (dev)
  - n8n-dev-app.yaml                  # ✅ Workflow automation (dev)
  - kafka-demo-dev-app.yaml           # ✅ Messaging demo (dev)

  # 🏭 PRODUCTION LAYER (Wave 20)
  - audiobookshelf-prod-app.yaml      # ✅ Media server (prod)
  - n8n-prod-app.yaml                 # ✅ Workflow automation (prod)
  # - kafka-demo-prod-app.yaml        # ❌ DISABLED - No prod demo needed
```

---

## 🚀 Technology Stack

### **Infrastructure (22 Applications)**
| Component | Version | Description | Namespace |
|-----------|---------|-------------|-----------|
| **Cilium** | v1.16.4 | eBPF-based CNI with Gateway API | `cilium-system` |
| **Istio** | v1.24.1 | Service mesh with Sail Operator | `istio-system` |
| **Envoy Gateway** | v1.2.2 | Gateway API implementation | `envoy-gateway-system` |
| **ArgoCD** | v8.2.5 | GitOps continuous delivery | `argocd` |
| **Prometheus** | v65.1.1 | Metrics collection & alerting | `monitoring` |
| **Alertmanager** | v0.27.0 | Alert routing & notifications | `monitoring` |
| **Grafana** | v8.6.1 | Dashboards & visualization | `monitoring` |
| **Rook Ceph** | v1.15.5 | Distributed storage cluster | `rook-ceph` |
| **cert-manager** | v1.16.1 | Certificate lifecycle management | `cert-manager` |
| **Sealed Secrets** | v0.27.2 | Secret encryption controller | `sealed-secrets` |

### **Platform (6 Applications)**
| Component | Version | Description | Namespace |
|-----------|---------|-------------|-----------|
| **Apache Kafka** | v0.47.0 | Event streaming platform | `kafka` |
| **Schema Registry** | v26.0.5 | Kafka schema management | `kafka` |
| **Redpanda Console** | latest | Modern Kafka UI | `kafka` |
| **InfluxDB** | v2.7.10 | Time-series database | `influxdb` |
| **CloudBeaver** | latest | Database management UI | `cloudbeaver` |
| **N8N PostgreSQL** | v16.1 | Workflow automation database | `n8n-prod` |

### **Applications (4 Applications)**
| Component | Version | Description | Environments |
|-----------|---------|-------------|--------------|
| **Audiobookshelf** | v2.15.2 | Media server for audiobooks | `dev`, `prod` |
| **N8N** | v1.78.0 | Workflow automation platform | `dev`, `prod` |
| **Kafka Demo** | latest | Real-time messaging demo | `dev` |

---

## 🌊 Sync Wave Architecture

```
Wave 0:  Gateway API CRDs, Namespaces
Wave 1:  CNI (Cilium), Storage (Rook Ceph), Envoy Gateway
Wave 2:  Controllers (ArgoCD, cert-manager, Sealed Secrets)
Wave 3:  Service Mesh (Istio), CloudNative PostgreSQL
Wave 5:  Monitoring (Prometheus, Grafana, Alertmanager)
Wave 6:  Observability (Vector, Elasticsearch, Kibana)
Wave 12: Platform Data Services (InfluxDB, N8N PostgreSQL)
Wave 13: Platform Messaging (Kafka, Schema Registry)
Wave 20: End-User Applications (Audiobookshelf, N8N)
```

---

## 🔧 Management Commands

### **Individual Layer Control**
```bash
# Deploy only infrastructure
kubectl apply -k kubernetes/infrastructure/

# Deploy only platform services
kubectl apply -k kubernetes/platform/

# Deploy only applications
kubectl apply -k kubernetes/apps/
```

### **Component Toggle**
```bash
# Disable a component (e.g., Envoy Gateway)
vim kubernetes/infrastructure/kustomization.yaml
# Comment: # - network/envoy-gateway-app.yaml

# Apply changes
kubectl apply -k kubernetes/infrastructure/
```

### **Health Check**
```bash
# Check all application sync status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"

# Check specific layer
kubectl get applications -n argocd | grep -E "(infrastructure|platform|apps)"
```

### **Storage Verification**
```bash
# Check available storage classes
kubectl get storageclass

# Check Ceph cluster health
kubectl -n rook-ceph exec deployment/rook-ceph-tools -- ceph status
```

---

## 📊 Enterprise Metrics

- **🎯 Applications Deployed**: 30 total
- **⚡ Deployment Layers**: 3 (Infrastructure → Platform → Apps)
- **🌊 Sync Waves**: 8 orchestrated deployment phases
- **🔄 GitOps Coverage**: 100% (all components managed by ArgoCD)
- **📈 Infrastructure Availability**: 99.9% target with Ceph HA
- **🛡️ Security**: Sealed Secrets + cert-manager + Istio mTLS

---

## 🚨 Troubleshooting

### **Common Issues**
```bash
# ArgoCD login
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Check pod status
kubectl get pods --all-namespaces | grep -v Running

# Force application sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'

# Check Ceph cluster
kubectl -n rook-ceph get cephcluster
```

### **Performance Tuning**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Storage capacity
kubectl get csistoragecapacities -A
```

---

*🏢 Enterprise-grade Kubernetes following Netflix/Google/Meta Tier-0 patterns*