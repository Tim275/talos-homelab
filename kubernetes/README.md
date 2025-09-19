# 🏢 Enterprise Kubernetes Infrastructure (Netflix/Google Style)

## 🚀 Quick Start (2 Commands for Everything!)

```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 1. Foundation Bootstrap (Manual - Required for ArgoCD)
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -
# ... (see Bootstrap Order below for complete setup)

# 2. Enterprise GitOps Deployment (Automatic - Everything Else!)
kubectl apply -k kubernetes/sets/
```

**That's it! ArgoCD will automatically deploy everything else in proper order!** 🎉

## 🏗️ Enterprise GitOps Architecture

### Why This Structure Works at Scale

**🎯 ENTERPRISE DOMINO DEPLOYMENT CHAIN:**

```
kubectl apply -k kubernetes/sets/
├── infrastructure.yaml    → kubernetes/infra/ (Wave 5)
├── platform.yaml         → kubernetes/platform/ (Wave 10)
├── applicationsets.yaml  → kubernetes/components/applicationsets/ (Wave 20)
├── apps.yaml             → kubernetes/components/applications/ (Wave 25)
└── environments.yaml     → kubernetes/apps/ (Wave 25)
```

### 🏢 Enterprise Directory Structure (Google/AWS Best Practice)

```
kubernetes/
├── 🔄 sets/                           # BOOTSTRAP LAYER
│   ├── infrastructure.yaml           # Infrastructure ApplicationSet
│   ├── platform.yaml                 # Platform ApplicationSet
│   ├── applicationsets.yaml          # ApplicationSets bootstrap
│   ├── apps.yaml                     # Applications bootstrap
│   └── environments.yaml             # Environments bootstrap
│
├── 🏗️ infra/                         # INFRASTRUCTURE LAYER
│   ├── network/cilium/               # CNI + LoadBalancer
│   ├── controllers/argocd/           # GitOps engine
│   ├── storage/rook-ceph/            # Distributed storage
│   └── monitoring/prometheus/        # Metrics & observability
│
├── 🗄️ platform/                      # PLATFORM LAYER
│   ├── messaging/kafka/              # Enterprise messaging
│   ├── data/influxdb/                # Enterprise metrics
│   └── security/                     # Enterprise security
│
├── 🧩 components/                     # ARGOCD RESOURCES (NEW!)
│   ├── applicationsets/              # All ApplicationSet CRDs
│   │   └── quantlab.yaml            # Multi-environment ApplicationSet
│   └── applications/                 # All Application CRDs
│       ├── audiobookshelf-dev.yaml  # Development Application
│       ├── audiobookshelf-prod.yaml # Production Application
│       ├── n8n-dev.yaml             # Development Application
│       └── n8n-prod.yaml            # Production Application
│
└── 📦 apps/                          # APPLICATION MANIFESTS (CLEAN!)
    ├── audiobookshelf/
    │   └── environments/
    │       ├── dev/                  # Kubernetes manifests
    │       └── production/           # Kubernetes manifests
    ├── n8n/
    │   └── environments/
    │       ├── dev/                  # Kubernetes manifests
    │       └── production/           # Kubernetes manifests
    └── kafka-demo/
        └── environments/
            └── dev/                  # Kubernetes manifests
```

### 🎯 Key Enterprise Benefits

**✅ SEPARATION OF CONCERNS:**
- `components/` = ArgoCD resources (Applications, ApplicationSets)
- `apps/` = Pure Kubernetes manifests (Deployments, Services, etc.)
- Clean separation like Netflix/Google

**✅ ENTERPRISE SCALE READY:**
- ApplicationSets for automated multi-environment deployments
- Clear environment promotion: dev → production
- Team ownership with proper labels
- GitOps all the way down

**✅ DOMINO DEPLOYMENT:**
- Infrastructure → Platform → ApplicationSets → Applications → Environments
- Proper sync waves prevent dependency issues
- One command deploys everything in correct order

## 🌊 Sync Wave Strategy

**Ensures proper deployment order and prevents dependency issues:**

### **Wave 0-5: Infrastructure Foundation**
- Wave 0: CNI (Cilium) - Network foundation
- Wave 1: Service Mesh (Istio) - Traffic management
- Wave 2: Certificate Management - TLS certificates
- Wave 3: Controllers (ArgoCD, Sealed Secrets) - Core controllers
- Wave 4: Storage (Rook-Ceph) - Storage infrastructure
- Wave 5: Monitoring/Observability - Metrics & logging

### **Wave 10-19: Platform Layer**
- Wave 10: Database Operators (CloudNative-PG, MongoDB)
- Wave 12: Platform Services (Kafka, InfluxDB)

### **Wave 20-29: ArgoCD Resources**
- Wave 20: ApplicationSets deployment
- Wave 25: Applications & Environments deployment

### **Wave 30+: Security & Policies**
- Wave 30: Security policies, NetworkPolicies
- Wave 31: RBAC, Pod Security Standards

## 📋 Complete Bootstrap Order

```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 1. Foundation (REQUIRED ORDER!)
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -

# 2. Istio Service Mesh (4 components in order)
kustomize build --enable-helm kubernetes/infra/network/istio-cni | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/network/istio-base | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/network/istio-control-plane | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/network/istio-gateway | kubectl apply -f -

# 3. Core Controllers
kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -

# 4. Rook-Ceph (requires 2x deployment for CRDs)
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -
sleep 10
kubectl wait --for=condition=established crd/cephclusters.ceph.rook.io --timeout=60s
kustomize build --enable-helm kubernetes/infra/storage/rook-ceph | kubectl apply -f -

# 5. 🚨 CRITICAL: Fix Sealed Secrets after cluster recreation
./post-deploy-restore.sh

# 6. 🚀 Enterprise GitOps (Deploys EVERYTHING else automatically!)
kubectl apply -k kubernetes/sets/
```

## 🚨 Critical: SealedSecrets After Cluster Recreation

### Problem
`tofu destroy && tofu apply` = NEW cluster = NEW keys = ALL secrets BROKEN!

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

## 🔧 Enterprise Operations

### ArgoCD Access
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'

# Port forward
kubectl -n argocd port-forward svc/argocd-server 8080:80
# http://localhost:8080 (admin/[password])
```

### Application Management
```bash
# Check all applications
kubectl get applications -n argocd

# Check ApplicationSets
kubectl get applicationsets -n argocd

# Check specific app status
kubectl get pods -n audiobookshelf-dev
kubectl get pods -n n8n-prod
```

### Troubleshooting
```bash
# SealedSecret issues
kubectl get sealedsecrets --all-namespaces
./post-deploy-restore.sh

# ArgoCD application issues
kubectl describe application audiobookshelf-dev -n argocd
kubectl logs -n argocd deployment/argocd-application-controller

# Check sync waves
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave"
```

## 🎯 Enterprise Features

**✅ SERVICE OWNERSHIP:**
- Each service has clear team responsibility (`team: timour`)
- Service-level SLA annotations
- Proper labeling for monitoring and governance

**✅ ENVIRONMENT PROMOTION:**
- Consistent dev → production deployment flow
- Environment-specific configurations
- Manual promotion gates for production

**✅ GITOPS NATIVE:**
- Everything declarative in Git
- ArgoCD manages all deployments automatically
- Infrastructure as Code with Terraform + GitOps

**✅ ENTERPRISE SCALE:**
- ApplicationSets for multi-environment automation
- Proper sync waves for dependency management
- Clean separation of concerns

**This is how Netflix, Google, and Uber deploy at scale!** 🚀