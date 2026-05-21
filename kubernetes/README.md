# Kubernetes Homelab (GitOps)

ArgoCD App-of-Apps + ApplicationSets. One `kubectl apply -k bootstrap/` brings up the whole cluster via an 11-tier sync-wave cascade.

## Structure

```
kubernetes/
├── bootstrap/                  # kubectl apply -k bootstrap/ = whole cluster
│   ├── kustomization.yaml      # order: argocd -> projects -> clusters -> applicationsets
│   ├── argocd/                 # initial ArgoCD install (Helm via kustomize)
│   ├── projects.yaml           # App -> projects/
│   ├── clusters.yaml           # App -> clusters/
│   └── applicationsets.yaml    # App -> applicationsets/
│
├── applicationsets/
│   ├── infrastructure/
│   ├── platform/
│   ├── apps/
│   ├── security/
│   ├── tenants/
│   └── edge/
│
├── infrastructure/
│   ├── argocd/
│   ├── network/
│   ├── storage/
│   ├── certificates/
│   ├── secrets/
│   ├── operators/
│   ├── ingress/
│   └── observability/
│
├── platform/
│   ├── identity/
│   └── gitops/
│
├── apps/
│   ├── n8n/
│   ├── cloudbeaver/
│   ├── audiobookshelf/
│   └── uptime-kuma/
│
├── tenants/
│   ├── drova/
│   ├── n8n-prod/
│   ├── keycloak/
│   ├── lldap/
│   ├── oms/
│   └── infisical/
│
├── security/
├── projects/
├── clusters/
├── components/
└── scripts/
```

## Sync-Wave Cascade (11 Tiers)

| Wave | Tier | Apps |
|---|---|---|
| -100 | Foundation | sealed-secrets, projects, clusters |
| -50 | Operator CRDs | cert-manager, argo-rollouts, operators, rook-ceph-operator |
| 0 | Network Core | cilium, coredns, metrics-server |
| 10 | Security + Tenant-Config | PSA, RBAC, NetworkPolicies, Kyverno, tenant namespace+quota+rbac |
| 20 | Storage Cluster | CephCluster, RGW, csi-snapshot |
| 30 | Data Layer | CNPG (drova/n8n/keycloak), Kafka, Redis, velero |
| 40 | Observability | prometheus, ES, loki, tempo, jaeger, kibana, grafana |
| 50 | Identity | lldap, keycloak |
| 60 | Apps | drova, n8n, cloudbeaver, audiobookshelf, uptime-kuma |
| 70 | Exposure + Post-deploy | gateway, cloudflared, OTel, vector, dashboards, alerts, hubble, exporters |
| 90 | Self-Update | argocd-self-management |

Tier-Config (namespace+quota+rbac) at wave 10 runs BEFORE data-workloads at wave 30 (data-AppSets use CreateNamespace=false, so namespaces must pre-exist).

## Bootstrap

### Step 1 — Tofu (VMs + Talos + Cilium inline)
```bash
cd tofu/
tofu apply
cp tofu/output/kube-config.yaml ~/.kube/homelab-admin.yaml
cp tofu/output/talosconfig ~/.kube/talos-config
export KUBECONFIG=~/.kube/homelab-admin.yaml
kubectl get nodes   # alle Ready abwarten
```

### Step 2 — Sealed-Secrets cert (vor ArgoCD!)
```bash
cd tofu/bootstrap/sealed-secrets/
tofu init && tofu apply
cd -
```

### Step 3 — Manual Core (aus kubernetes/ directory)
```bash
# 1. Cilium (CNI — verify/update nach Tofu inline)
kubectl kustomize --enable-helm infrastructure/network/cilium/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -

# 2. Sealed-Secrets controller
kubectl kustomize --enable-helm infrastructure/secrets/sealed-secrets/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -

# 3. Rook-Ceph (zweimal wegen CRD-Bootstrap)
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -
kubectl wait --for=condition=Established crd/cephclusters.ceph.rook.io --timeout=60s
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -

# 4. Operators: CNPG, ECK, Strimzi, Redis, Grafana, OTel, Renovate (zweimal wegen CRDs)
kubectl kustomize --enable-helm infrastructure/operators/operators/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -
kubectl wait --for=condition=Established crd/podmonitors.monitoring.coreos.com --timeout=60s
kubectl kustomize --enable-helm infrastructure/operators/operators/overlays/prod | \
  kubectl apply --server-side --force-conflicts -f -
```

### Step 4 — ArgoCD Bootstrap-Cascade
```bash
kubectl kustomize --enable-helm bootstrap/ | \
  kubectl apply --server-side --force-conflicts -f -

kubectl get applications -n argocd -w   # ~10-15min bis alles Synced/Healthy
```

## ArgoCD Access

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
# OR via OIDC: https://argocd.timourhomelab.org (Keycloak login)
```

## Adding a new tenant

1. `tenants/<name>/` with namespace.yaml + resourcequota.yaml + limitrange.yaml + rbac.yaml (+ data subdirs)
2. Add `<name>` to `tenants/kustomization.yaml` + `tenants-config.yaml` AppSet list
3. Add `applicationsets/tenants/<name>-tenant.yaml` for the data-services + app
4. Commit + push, ArgoCD reconciles
```
