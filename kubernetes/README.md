# Kubernetes Homelab

## Structure

```
kubernetes/
├── bootstrap/
│   ├── kustomization.yaml       # LAYER 1: Bootstrap entry point
│   ├── security.yaml
│   ├── infrastructure.yaml
│   ├── platform.yaml
│   └── apps.yaml
│
├── security/
│   └── kustomization.yaml       # LAYER 2: Security ApplicationSets
│
├── infrastructure/
│   ├── kustomization.yaml       # LAYER 2: Infrastructure ApplicationSets
│   ├── monitoring-app.yaml
│   ├── network-app.yaml
│   ├── storage-app.yaml
│   │
│   ├── monitoring/
│   │   ├── kustomization.yaml   # LAYER 3: Service selector
│   │   ├── prometheus/
│   │   │   └── kustomization.yaml
│   │   └── grafana/
│   │       └── kustomization.yaml
│   │
│   └── network/
│       ├── kustomization.yaml
│       └── cilium/
│           └── kustomization.yaml
│
├── platform/
│   └── kustomization.yaml       # LAYER 2: Platform ApplicationSets
│
└── apps/
    └── kustomization.yaml       # LAYER 2: Apps ApplicationSets
```

## Bootstrap

**Option 1: ArgoCD**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

kubectl apply -k bootstrap/
kubectl get applications -n argocd -w
```

**Option 2: Layer-by-Layer**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

kubectl apply -k security/           # Wave 0: Security ApplicationSets
kubectl apply -k infrastructure/     # Wave 1: Infrastructure ApplicationSets
kubectl apply -k platform/          # Wave 15: Platform ApplicationSets
kubectl apply -k apps/              # Wave 25: Apps ApplicationSets
```

**Option 3: Manual Core**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"

kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | kubectl apply --server-side --force-conflicts -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -
```
> Note: Rook-Ceph uses `--server-side` due to large CSI Operator CRDs (>262KB annotations)

## ArgoCD

```bash
# Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:80
```
