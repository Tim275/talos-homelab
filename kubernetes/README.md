# 🚀 Enterprise Kubernetes Homelab


## 🎯 Quick Start

### **One Command Bootstrap**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 🔐 Security Foundation (Wave 5)
kubectl apply -k security/

# 🏗️ Infrastructure Layer (Wave 0-10)
kubectl apply -k infrastructure/

# 🛠️ Platform Layer (Wave 12-20)
kubectl apply -k platform/

# 📱 Applications Layer (Wave 20)
kubectl apply -k apps/
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
└── apps/                             # 📱 APPLICATIONS LAYER (5 Apps)
    ├── kustomization.yaml            #     Main applications control
    │
    ├── base/                         # Service base configurations
    │   ├── audiobookshelf/          #     Media server templates
    │   ├── n8n/                     #     Workflow automation with rollouts
    │   │   └── environments/        #     Environment-specific configs
    │   │       ├── dev/             #     Development environment
    │   │       └── production/      #     Production with Argo Rollouts
    │   │           ├── rollout.yaml #     ✅ Progressive delivery
    │   │           ├── analysis-template.yaml # ✅ Automated rollback
    │   │           └── resource-quota.yaml    # ✅ Enterprise quotas
    │   └── kafka-demo/              #     Kafka demo applications
    │
    ├── overlays/                     # 🎯 ENTERPRISE TIER-0 PATTERNS
    │   ├── dev/                     #     Development overrides
    │   │   └── patches/             #     Environment-specific patches
    │   │       ├── resource-limits.yaml    # ✅ Conservative dev limits
    │   │       ├── security-context.yaml   # ✅ Relaxed dev security
    │   │       └── environment-vars.yaml   # ✅ Dev configurations
    │   └── prod/                    #     Production overrides
    │       └── patches/             #     Production-grade patches
    │           ├── resource-limits.yaml    # ✅ High-performance limits
    │           ├── security-context.yaml   # ✅ Strict prod security
    │           └── environment-vars.yaml   # ✅ Prod configurations
    │
    ├── audiobookshelf-dev-app.yaml  # ✅ Media server (development)
    ├── audiobookshelf-prod-app.yaml # ✅ Media server (production)
    ├── n8n-dev-app.yaml             # ✅ Workflow automation (dev)
    ├── n8n-prod-app.yaml            # ✅ Workflow automation (prod w/ rollouts)
    └── kafka-demo-dev-app.yaml      # ✅ Kafka demo (development)
```


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
kubectl apply -k infrastructure/

# Deploy only platform services
kubectl apply -k platform/

# Deploy only applications
kubectl apply -k apps/
```

### **Manual Bootstrap (Step-by-Step)**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

# 1. Cilium CNI
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -

# 2. Sealed Secrets
kustomize build --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -

# 3. Proxmox CSI Plugin
kustomize build --enable-helm infrastructure/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A

# 4. ArgoCD
kustomize build --enable-helm infrastructure/controllers/argocd | kubectl apply -f -
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# 5. Deploy everything else via GitOps
kubectl apply -k infrastructure
kubectl apply -k platform
kubectl apply -k apps
```

### **Direct Kustomize Deployment (without ArgoCD)**
```bash
# Enable Helm in kustomize and deploy directly
kubectl kustomize --enable-helm infrastructure/ | kubectl apply -f -
kubectl kustomize --enable-helm platform/ | kubectl apply -f -
kubectl kustomize --enable-helm apps/ | kubectl apply -f -

# Or layer by layer with Helm support
kubectl kustomize --enable-helm security/ | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/ | kubectl apply -f -
kubectl kustomize --enable-helm platform/ | kubectl apply -f -
kubectl kustomize --enable-helm apps/ | kubectl apply -f -
```

### **Wave-by-Wave Manual Bootstrap (Production Ready)**
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
kubectl get applications -n argocd | grep -E "(security|infrastructure|platform|apps)"
```

### **Storage Verification**
```bash
# Check available storage classes
kubectl get storageclass

# Check Ceph cluster health
kubectl -n rook-ceph exec deployment/rook-ceph-tools -- ceph status
```

### **Sealed Secrets Verification**
```bash
# Check sealed secrets controller
kubectl get pods -n sealed-secrets

# Check bootstrap job completion
kubectl get job -n sealed-secrets sealed-secrets-bootstrap

# Test sealed secrets (after bootstrap)
kubeseal --fetch-cert > public.pem
echo -n mypassword | kubectl create secret generic test-secret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal --cert=public.pem -o yaml
```

---

## 📊 Enterprise Metrics

- **🎯 Total Components**: ~40 infrastructure + platform components
- **⚡ Deployment Layers**: 4 (Security → Infrastructure → Platform → Apps)
- **🌊 Sync Waves**: 9 orchestrated deployment phases
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

