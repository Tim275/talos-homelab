# Kubernetes Infrastructure

## Bootstrap Order

```bash
export KUBECONFIG="tofu/output/kube-config.yaml"

# 1. Foundation (REQUIRED ORDER!)
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kustomize build --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -

# 2. Deploy everything else via GitOps
kubectl apply -k kubernetes/infra
kubectl apply -k kubernetes/sets
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

## Complete File Structure

```
kubernetes/
├── apps/                                # 🎯 USER APPLICATIONS
│   ├── README.md
│   ├── base/
│   │   ├── audiobookshelf/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml          # Audiobook server
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── pvc.yaml                 # 100Gi storage
│   │   └── n8n/
│   │       ├── kustomization.yaml
│   │       ├── deployment.yaml          # Workflow automation
│   │       ├── service.yaml
│   │       ├── storage.yaml             # Persistent data
│   │       └── postgres-cluster.yaml    # CloudNative-PG database
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml       # Latest tags, minimal resources
│       └── production/
│           └── kustomization.yaml       # Pinned versions, backups enabled
│
├── platform/                            # 🗄️ DATA LAYER
│   └── data/
│       ├── mongodb/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── rbac.yaml               # ServiceAccount + permissions
│       │   └── mongodb-cluster.yaml    # MongoDB ReplicaSet
│       └── postgresql/
│           ├── kustomization.yaml
│           └── cnpg-cluster.yaml       # PostgreSQL HA clusters
│
├── infra/                              # 🏗️ INFRASTRUCTURE
│   ├── kustomization.yaml
│   ├── network/
│   │   ├── cilium/                    # CNI + LoadBalancer
│   │   ├── cert-manager/              # TLS certificates
│   │   ├── gateway/                   # Gateway API
│   │   └── cloudflared/               # Tunnel for external access
│   ├── controllers/
│   │   ├── argocd/                    # GitOps engine
│   │   └── sealed-secrets/            # Secret encryption
│   ├── storage/
│   │   ├── proxmox-csi/               # Proxmox volumes
│   │   └── rook-ceph/                 # Distributed storage
│   └── monitoring/
│       ├── prometheus/                # Metrics
│       └── grafana/                   # Dashboards
│
├── sets/                               # 🔄 AUTO-DISCOVERY
│   └── applicationsets.yaml           # Matrix generator for all apps
│
└── bootstrap-infrastructure.yaml      # One-shot bootstrap

```

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