# Manual bootstrap

## Cilium
Comes with the Talos machine config, see `tofu/stacks/cluster`.

## CRDs
```bash
kustomize build --enable-helm kubernetes/argocd/crds | kubectl apply --server-side --force-conflicts -f -
```

## Argo CD
```bash
kubectl apply -f kubernetes/argocd/bootstrap/base/priority-classes.yaml
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/argocd/bootstrap/argocd/overlays/prod | kubectl apply --server-side --force-conflicts -f -
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
```

## Root app
```bash
kubectl apply --server-side --force-conflicts -k kubernetes/argocd/projects
kubectl apply --server-side --force-conflicts -k kubernetes/argocd/bootstrap/prod
```

## Staging
Same steps with `overlays/staging` and `bootstrap/staging`.

The root app labels the cluster with its environment, the ApplicationSets deploy `overlays/<environment>`.

```bash
kubectl -n argocd get applications -l environment=staging
```

## Apps and tenants
```bash
kubectl config set-context --current --namespace=argocd
argocd app sync --core -l app.kubernetes.io/part-of=apps
argocd app sync --core -l app.kubernetes.io/part-of=tenants
```
