# Kubernetes

## Manual bootstrap

Cilium is already there when the nodes come up, OpenTofu puts it into the Talos machine config (`tofu/stacks/cluster`). Everything below runs from the repo root.

### Argo CD

Applied twice: the first run brings the CRDs, the second one the resources that need them.

```sh
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone \
  kubernetes/argocd/bootstrap > /tmp/bootstrap.yaml
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
kubectl wait --for=condition=Established --timeout=180s \
  crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
```

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
```

### Root app

From here Argo CD pulls the rest from Git. `root` syncs in waves:

- `-2` `crds`: cert-manager, External Secrets, Gateway API and Envoy Gateway, Prometheus Operator
- `-1` `clusters`, `projects`, `priority-classes`
- `1` `argocd` (manages itself from now on), `applicationsets`

```sh
kubectl -n argocd get applications -w
```

### Apps and tenants

`infrastructure` and `platform` sync on their own and retry until healthy. `apps` and `tenants` wait for a manual sync:

```sh
kubectl config set-context --current --namespace=argocd
argocd app sync --core -l app.kubernetes.io/part-of=apps
argocd app sync --core -l app.kubernetes.io/part-of=tenants
```

## What needs what

```
Cilium -> Argo CD -> Rook -> OpenBao -> External Secrets -> Postgres -+-> Keycloak -> Grafana (login only)
                                                                      +-> n8n
                                                                      +-> drova
```

Nothing enforces this order between apps. They all start at once and retry until the thing they need is up.

## Environments

One branch, `main` is prod. Every app is `base/` plus `overlays/prod`; the cluster label `environment` picks the overlay. `overlays/staging` exists for the OpenBao stack only, there is no staging cluster yet.

## Layout

```
argocd/           bootstrap (Argo CD itself, root), projects, clusters, applicationsets, crds
infrastructure/   network, storage, security, monitoring, cluster
platform/         identity, observability, data, delivery, automation
apps/             forgejo, uptime-kuma, pgadmin, homepage, n8n, excalidraw
tenants/          drova
```
