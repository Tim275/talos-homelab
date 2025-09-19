# Kubernetes Infrastructure

## Bootstrap Order

```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 1. Foundation (REQUIRED ORDER!)
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -

# Istio (Microservice Architecture - 4 components)
kustomize build --enable-helm kubernetes/infra/network/istio-cni | kubectl apply -f - && \
kustomize build --enable-helm kubernetes/infra/network/istio-base | kubectl apply -f - && \
kustomize build --enable-helm kubernetes/infra/network/istio-control-plane | kubectl apply -f - && \
kustomize build --enable-helm kubernetes/infra/network/istio-gateway | kubectl apply -f -

# Alternative: Istio (Monolithic - single command, if available)
# kustomize build --enable-helm kubernetes/infra/network/istio | kubectl apply -f -

kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -

# Rook-Ceph (requires 2x deployment for CRDs)
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -
sleep 10
kubectl wait --for=condition=established crd/cephclusters.ceph.rook.io --timeout=60s
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -

# 2. 🚨 CRITICAL: Fix Sealed Secrets after cluster recreation
./post-deploy-restore.sh

# 3. Deploy everything else via GitOps (Enterprise Structure)
kubectl apply -k kubernetes/sets
```

## 🏗️ GitOps Architecture Explanation

### Why only 2 commands for everything?

**1️⃣ Bootstrap Phase (Manual)**
```bash
kubectl apply -k kubernetes/infra     # Foundation components - ArgoCD, etc.
```

**2️⃣ GitOps Phase (Automatic via ApplicationSets)**
```bash
kubectl apply -k kubernetes/sets      # Deploy ApplicationSets (Auto-discovery)
```

### 🔄 What `kubernetes/sets` actually does (Enterprise Structure):

**ApplicationSets are "Apps that create Apps"** - they deploy controlled services:

**`infrastructure.yaml` ApplicationSet:**
- Deploys `kubernetes/infrastructure/services/longhorn` ✅ (Enterprise Storage)
- Deploys `kubernetes/infrastructure/services/cert-manager` ✅ (Enterprise TLS)
- Legacy `kubernetes/infra/monitoring` ✅ (Being migrated)
- Legacy `kubernetes/infra/network` ✅ (Being migrated)
- Legacy `kubernetes/infra/observability` ✅ (Being migrated)

**`platform.yaml` ApplicationSet:**
- Deploys `kubernetes/platform-enterprise/services/n8n` ✅ (Enterprise Automation)
- Deploys `kubernetes/platform-enterprise/services/influxdb` ✅ (Enterprise Metrics)
- Deploys `kubernetes/platform-enterprise/services/kafka` ✅ (Enterprise Messaging)
- 🚫 EXCLUDES: kafdrop, mongodb, quantlab-postgres (commented out)

**`apps.yaml` ApplicationSet:**
- Deploys `kubernetes/services/audiobookshelf` ✅ (Enterprise Service Pattern)
- Deploys `kubernetes/services/n8n` ✅ (Enterprise Service Pattern)

### 🤔 Why not directly `kubectl apply -k kubernetes/platform`?

**Because it's GitOps!**

1. You deploy only the **ApplicationSets** with `kubectl apply -k kubernetes/sets`
2. ApplicationSets **automatically scan** git repository
3. They **create Applications** for everything they find
4. ArgoCD **automatically syncs** all discovered Applications

### 🎯 Summary:

```bash
# Manual Bootstrap (Foundation)
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -
# ... (other manual steps - see above)

# GitOps Bootstrap (Enterprise)
kubectl apply -k kubernetes/sets      # Deploy Enterprise ApplicationSets
# ApplicationSets then automatically deploy:
# - kubernetes/infrastructure/services/* (Enterprise Infrastructure)
# - kubernetes/platform-enterprise/services/*  (Enterprise Platform)
# - kubernetes/services/* (Enterprise Applications)
```

**You deploy EVERYTHING with GitOps Enterprise Structure!** 🚀

This is the difference between imperative (manual) and declarative (GitOps) deployments!

## 🌊 ArgoCD Sync Wave Strategy

**Deployment waves ensure proper order and prevent dependency issues:**

### **Wave 0-5: Infrastructure**
- Wave 0: CNI (Cilium) - Network foundation
- Wave 1: Service Mesh (Istio) - Traffic management
- Wave 2: Certificate Management (Cert-Manager) - TLS certificates
- Wave 3: Controllers (Sealed Secrets, ArgoCD) - Core controllers
- Wave 4: Storage (Rook-Ceph, Proxmox CSI) - Storage infrastructure
- Wave 5: Monitoring/Observability - Metrics & logging

### **Wave 10-19: Platform (Database Layer)**
- Wave 10: Database Operators (CloudNative-PG, MongoDB Community)
- Wave 12: Database Clusters (PostgreSQL, MongoDB instances)

### **Wave 20-29: Applications**
- Wave 20: Core Applications (n8n, etc.)

### **Wave 30-39: Security**
- Wave 30: Security policies, NetworkPolicies
- Wave 31: RBAC, Pod Security Standards

**Example sync wave annotation:**
```yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "10"
```

## 🚨 CRITICAL: SealedSecrets After Cluster Recreation

### Problem
`tofu destroy && tofu apply` = NEW keys = ALL secrets BROKEN!

### Solution (MUST RUN!)
```bash
# After EVERY cluster recreation:
./post-deploy-restore.sh

# Manual if script fails:
kubectl delete secret sealed-secrets-key* -n sealed-secrets --ignore-not-found
kubectl create secret tls sealed-secrets-key \
  --cert=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --key=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.key \
  -n sealed-secrets
kubectl label secret sealed-secrets-key -n sealed-secrets \
  sealedsecrets.bitnami.com/sealed-secrets-key=active
kubectl rollout restart deployment sealed-secrets-controller -n sealed-secrets
```

### Create New Secret
```bash
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
stringData:
  api-key: "secret-value"
EOF

kubeseal --cert tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt \
  --format yaml < secret.yaml > sealed-secret.yaml
rm secret.yaml
git add sealed-secret.yaml
```

## Complete File Structure (Enterprise-Grade)

```
kubernetes/
├── services/                           # 🎯 ENTERPRISE USER APPLICATIONS
│   ├── audiobookshelf/
│   │   ├── applicationset.yaml         # Service ownership (team, SLA)
│   │   └── environments/
│   │       ├── dev/                    # Development environment
│   │       └── production/             # Production environment
│   └── n8n/
│       ├── applicationset.yaml         # Enterprise service pattern
│       └── environments/
│           ├── dev/
│           └── production/
│
├── infrastructure/                     # 🏗️ ENTERPRISE INFRASTRUCTURE
│   ├── sets/
│   │   └── infrastructure.yaml         # Controlled infrastructure ApplicationSet
│   └── services/
│       ├── longhorn/                   # Enterprise storage
│       │   ├── applicationset.yaml     # Service ownership
│       │   └── environments/production/
│       └── cert-manager/               # Enterprise TLS
│           ├── applicationset.yaml
│           └── environments/production/
│
├── platform-enterprise/               # 🗄️ ENTERPRISE PLATFORM LAYER
│   ├── sets/
│   │   └── platform.yaml              # Controlled platform ApplicationSet
│   └── services/
│       ├── n8n/                       # Enterprise automation
│       │   └── environments/production/
│       ├── kafka/                     # Enterprise messaging
│       └── influxdb/                  # Enterprise metrics
│
├── infra/                             # 🏗️ LEGACY INFRASTRUCTURE (being migrated)
│   ├── network/cilium/                # CNI + LoadBalancer
│   ├── controllers/argocd/            # GitOps engine
│   ├── storage/rook-ceph/             # Distributed storage
│   └── monitoring/prometheus/         # Metrics
│
├── sets/                              # 🔄 ENTERPRISE APPLICATIONSETS
│   ├── infrastructure.yaml            # Enterprise infrastructure control
│   ├── platform.yaml                 # Enterprise platform control
│   └── apps.yaml                     # Enterprise applications control
│
└── README.md                          # This file

```

## 🎯 Enterprise Benefits:
- ✅ **Service Ownership**: Each service has clear team responsibility
- ✅ **Controlled Deployment**: No more auto-discovery chaos
- ✅ **Environment Promotion**: Consistent dev → production flow
- ✅ **SLA Management**: Enterprise annotations for monitoring
- ✅ **Excluded Services**: kafdrop, mongodb, quantlab-postgres disabled by default

## ArgoCD Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# Port forward
kubectl -n argocd port-forward svc/argocd-server 8080:80
# http://localhost:8080 (admin/[password])
```

## Deploy Applications

```bash
# Deploy to dev
kubectl apply -k kubernetes/apps/overlays/dev/

# Deploy to production  
kubectl apply -k kubernetes/apps/overlays/production/

# Check status
kubectl get applications -n argocd
kubectl get pods -n audiobookshelf
kubectl get pods -n n8n
```

## Troubleshooting

```bash
# SealedSecret issues
kubectl get sealedsecrets --all-namespaces  # Check for decrypt errors
./post-deploy-restore.sh                    # Fix all secrets

# MongoDB not starting
kubectl get mongodbcommunity -n mongodb
kubectl describe pod mongodb-cluster-0 -n mongodb

# PostgreSQL issues  
kubectl get clusters -n cnpg-system
kubectl logs -n n8n n8n-postgres-1
```