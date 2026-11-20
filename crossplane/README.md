# crossplane-apis

Configuration package with the platform APIs, released to `ghcr.io/tim275/talos-homelab/crossplane-apis`
on every merge to main (`VERSION` holds major.minor). Renovate bumps the version per environment in
`kubernetes/platform/automation/crossplane/overlays/<env>/configuration.yaml`.

Orders live in `kubernetes/customers/<env>/<customer>.yaml`:

```yaml
apiVersion: customers.tim275.github.io/v1alpha1
kind: Customer
metadata:
  name: k100
spec:
  address: lab
  services: [n8n]
```

## Adding a service

1. `apis/<name>instance/definition.yaml` and `composition.yaml`, plus `examples/<name>instance.yaml`
2. service name in the `services` enum of `apis/customer/definition.yaml` and in `$kinds` of `apis/customer/composition.yaml`
3. ClusterRole for the composed kinds in `kubernetes/platform/automation/crossplane/base/rbac-<name>instance.yaml`
4. raise the minor version in `VERSION`

Settings a service needs go into new optional fields, existing orders keep working.
