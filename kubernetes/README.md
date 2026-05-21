# Kubernetes Homelab (GitOps)

ArgoCD App-of-Apps + ApplicationSets. One `kubectl apply -k bootstrap/` brings up the whole cluster.

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

## Bootstrap

GitOps — ArgoCD syncs the whole cluster from Git. The manual part is just enough to get
ArgoCD running; ArgoCD then deploys every stack (network, storage, controllers, observability,
apps) via ApplicationSets — server-side apply + retry, ordered by sync-waves.

```sh
# 1. Infra: VMs + Talos + Cilium (inline CNI) + sealed-secrets key + Proxmox CSI + PVs
cd tofu && tofu apply && cd ..

# 2. Push — ArgoCD syncs from GitHub, so your commits must be on the remote
git push

# 3. Install ArgoCD (the only manual kubectl step). Run twice: 1st pass installs the CRDs,
#    2nd the App-of-Apps that reference them.
export KUBECONFIG=tofu/output/kube-config.yaml
kustomize build --enable-helm kubernetes/bootstrap | kubectl apply --server-side -f -
kustomize build --enable-helm kubernetes/bootstrap | kubectl apply --server-side -f -

# 4. Watch ArgoCD bring up everything
kubectl get applications -n argocd -w
```

Fresh cluster + single ArgoCD-driven apply = no `--force-conflicts` needed; `--server-side`
alone handles the large CRDs. ArgoCD then reconciles cilium (full config), sealed-secrets,
cert-manager, the operators, storage and all apps in wave order, retrying until CRDs settle.

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
