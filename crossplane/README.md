# crossplane-apis

Configuration package with the platform APIs, published as `ghcr.io/tim275/talos-homelab/crossplane-apis`.

```
crossplane.yaml           package metadata, required functions
apis/customer/            Customer: services list, creates one instance per service
apis/customernamespace/   namespace per instance: Pod Security restricted, quota, limits, default-deny network
apis/n8ninstance/         n8n with its own namespace, database and encryption key
apis/postgresdatabase/    role, database and credentials in the central Postgres
examples/                 one example per API, rendered in CI
VERSION                   major.minor, the patch number counts releases
```

Crossplane itself, the functions and the RBAC for the compositions live in
`kubernetes/platform/automation/crossplane`, the domain per environment in its `environment.yaml`.

## Release

- Pull request: the `crossplane-apis` workflow renders every example, validates the output against the XRDs and builds the package.
- Merge to main with changes in `crossplane/`: the workflow pushes the next patch version and tags it `crossplane-apis/v<version>`.
- Renovate bumps `overlays/<env>/configuration.yaml`: staging merges itself, prod waits for review.

Render and validate locally (needs Docker):

```bash
crossplane composition render --include-full-xr examples/customer.yaml apis/customer/composition.yaml \
  ../kubernetes/platform/automation/crossplane/overlays/prod/functions.yaml \
  --required-resources examples/environmentconfig.yaml --crossplane-version v2.4.3 > /tmp/customer.yaml
crossplane resource validate apis /tmp/customer.yaml
```

Kinds of other operators (CNPG, External Secrets, Cilium, Gateway API) show up as missing schemas, not as errors.

## Orders

`kubernetes/customers/<env>/<customer>.yaml`, written by the `customer` workflow:

```yaml
apiVersion: customers.tim275.github.io/v1alpha1
kind: Customer
metadata:
  name: k100
spec:
  address: lab
  services: [n8n]
```

Hosts are `<service>-<address>.<domain>`. Deleting an order removes everything except databases and the
secrets in OpenBao.

## Isolation

Every service runs in a `CustomerNamespace`, never in a Namespace of its own making:

- Pod Security `restricted` enforced
- ResourceQuota (default 1 CPU and 2Gi requested, 4Gi memory limit) and LimitRange defaults
- ingress only from the gateway, the namespace itself and the node (probes)
- egress only DNS, the namespace itself, Postgres when `postgres: true`, and 80/443 outside private ranges
- secrets only through the ClusterSecretStore `openbao-customers`, which reads and writes `kv/customers/*` and nothing else

Secrets of a service live in `kv/customers/<customer>/<service>/`, for n8n `postgres` and `encryption-key`.

## Adding a service

1. `apis/<name>instance/definition.yaml` and `composition.yaml` with a `CustomerNamespace`, plus `examples/<name>instance.yaml`
2. service name in the `services` enum of `apis/customer/definition.yaml` and in `$kinds` of `apis/customer/composition.yaml`
3. ClusterRole for the composed kinds in `kubernetes/platform/automation/crossplane/base/rbac-<name>instance.yaml`
4. raise the minor version in `VERSION`

Settings a service needs go into new optional fields, existing orders keep working.
