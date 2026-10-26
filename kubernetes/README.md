# Kubernetes Homelab (GitOps)

ArgoCD App-of-Apps + ApplicationSets. Bootstrap ArgoCD → it syncs everything else from Git.

## Structure

```
kubernetes/
├── bootstrap/          ArgoCD + App-of-Apps (argocd, projects, clusters, applicationsets)
├── applicationsets/    infrastructure, platform, apps, security, tenants, edge
├── infrastructure/     argocd, network, storage, certificates, secrets, operators, ingress, observability
├── platform/           identity, gitops
├── apps/               cloudbeaver, uptime-kuma, forgejo
├── tenants/            drova, n8n-prod, keycloak, lldap, ml, oms
└── security · projects · clusters · scripts
```

Every component has three parts:
- `base/` is the same everywhere: plain Kubernetes objects, the component's own technology, shared Helm values.
- `components/<technology>/` plugs it into another platform technology (envoy-gateway, rook-ceph, kube-prometheus-stack, cert-manager, cilium, cnpg). Swapping a technology means swapping that folder.
- `overlays/prod/` is prod only: chart version and prod values, SealedSecrets, hostnames (`settings.yaml`), replicas and resources (`sizing.yaml`), and which components this cluster uses (`components:` for manifests, `additionalValuesFiles` for charts).

## Bootstrap

```sh
cd tofu && tofu apply && cd ..
git push
export KUBECONFIG=tofu/output/kube-config.yaml

kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/bootstrap | kubectl apply --server-side -f -
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/bootstrap | kubectl apply --server-side -f -

kubectl get applications -n argocd -w
```

Apply twice — first pass installs the CRDs, second the CRs that reference them. `--server-side` is needed when a CRD >256 KB is created (fresh cluster); on re-apply plain works. No `--force-conflicts` on a fresh cluster.

## Components individually (optional — ArgoCD does this otherwise)

```sh
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/infrastructure/secrets/sealed-secrets/overlays/prod | kubectl apply -f -
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/infrastructure/network/cilium/overlays/prod         | kubectl apply -f -
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/infrastructure/storage/rook-ceph/overlays/prod      | kubectl apply --server-side -f -
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/infrastructure/argocd/overlays/prod                 | kubectl apply --server-side -f -
```

sealed-secrets first — it ships the `sealedsecrets.bitnami.com` CRD that cilium (hubble-oidc) and rook-ceph reference. Wrong order → `NotFound` on the SealedSecret (ArgoCD retries past this, a manual apply does not).

## ArgoCD login

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Or via OIDC: https://argocd.timourhomelab.org

## New tenant

1. `tenants/<name>/base/` (namespace + resourcequota + limitrange + rbac), quota and limit values in `overlays/prod/sizing.yaml`, data subdirs as their own components
2. add `<name>/overlays/prod` to `tenants/kustomization.yaml` + `<name>` to the `tenants-config.yaml` AppSet list
3. add `applicationsets/tenants/<name>-tenant.yaml`
4. commit + push → ArgoCD reconciles
