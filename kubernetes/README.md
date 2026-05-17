# Kubernetes Homelab

## Structure

```
kubernetes/
├── bootstrap/
│   ├── kustomization.yaml
│   ├── security.yaml
│   ├── infrastructure.yaml
│   ├── platform.yaml
│   └── apps.yaml
│
├── applicationsets/
│   ├── infrastructure/
│   ├── platform/
│   ├── security/
│   ├── edge/
│   └── tenants/
│
├── clusters/
│   ├── in-cluster.yaml
│   └── staging.yaml.template
│
├── projects/
│
├── components/
│   ├── arm64-arch/
│   ├── short-retention/
│   └── single-replica/
│
├── infrastructure/
│   ├── controllers/
│   ├── network/
│   ├── observability/
│   ├── storage/
│   └── vpn/
│
├── platform/
│   ├── data/
│   ├── developer-platform/
│   ├── drova-infra/
│   ├── gitlab/
│   ├── governance/
│   ├── identity/
│   └── messaging/
│
├── apps/
│   ├── base/
│   └── overlays/
│
├── security/
│   ├── compliance/
│   ├── foundation/
│   ├── governance/
│   ├── kyverno/
│   └── rbac/
│
└── scripts/
    ├── identity/
    ├── runbooks/
    └── upgrades/
```

## Bootstrap

Standard (App-of-Apps via ArgoCD):
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"
kubectl apply -k bootstrap/
kubectl get applications -n argocd -w
```

Layer-by-Layer:
```bash
kubectl apply -k security/
kubectl apply -k infrastructure/
kubectl apply -k platform/
kubectl apply -k apps/
```

Manual Core (initial-setup):
```bash
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | \
  kubectl apply --server-side --force-conflicts -f -
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -
```

## ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:80
```
