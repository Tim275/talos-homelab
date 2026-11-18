# Manual bootstrap

## Cilium
Comes with the Talos machine config, see `tofu/stacks/cluster`.

## Argo CD
```bash
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone kubernetes/argocd/bootstrap > /tmp/bootstrap.yaml
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
kubectl wait --for=condition=Established --timeout=180s crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
```

## Apps and tenants
```bash
kubectl config set-context --current --namespace=argocd
argocd app sync --core -l app.kubernetes.io/part-of=apps
argocd app sync --core -l app.kubernetes.io/part-of=tenants
```
