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
├── applicationsets/            # 12 AppSets, generate all child Apps
│   ├── infrastructure/         # controllers, network, storage, observability
│   ├── platform/               # identity, gitops
│   ├── apps/                   # apps-stack (audiobookshelf, cloudbeaver, uptime-kuma)
│   ├── security/               # security-stack
│   ├── tenants/                # tenants-config, drova-tenant, n8n-tenant
│   └── edge/                   # staging (Pi cluster, environment=staging)
│
├── infrastructure/             # cluster backbone (everything depends on it)
│   ├── argocd/                 # self-management
│   ├── network/                # cilium, coredns
│   ├── storage/                # rook-ceph, radosgateway, csi-drivers, velero, proxmox-csi
│   ├── certificates/           # cert-manager
│   ├── secrets/                # sealed-secrets
│   ├── operators/              # CNPG, Strimzi, ECK, Keycloak, argo-rollouts
│   ├── ingress/                # gateway (envoy), cloudflared, redis-gateway
│   └── observability/          # prometheus, loki, tempo, jaeger, ES, grafana, OTel, vector, exporters
│
├── platform/                   # developer-platform services
│   ├── identity/               # keycloak (+db), lldap
│   └── gitops/                 # renovate, backstage
│
├── apps/                       # self-deployed apps (own this repo)
│   ├── n8n/                    # base for tenants/n8n-prod/app
│   ├── cloudbeaver/
│   ├── audiobookshelf/
│   └── uptime-kuma/
│
├── tenants/                    # workloads with own data-services + namespace config
│   ├── drova/                  # postgres, kafka, redis, app(ext-repo) + ns/quota/rbac
│   ├── n8n-prod/               # postgres, redis, app + ns/quota/rbac
│   ├── keycloak/               # ns quota+limitrange (app in platform/identity)
│   ├── lldap/                  # ns quota+limitrange
│   ├── oms/                    # PARKED (SA-token interim, OIDC planned)
│   └── infisical/              # PARKED
│
├── security/                   # foundation, compliance, policies/kyverno, rbac, governance
├── projects/                   # AppProject CRs
├── clusters/                   # cluster-secret CRs
├── components/                 # reusable kustomize patches (arm64-arch, short-retention, single-replica)
└── scripts/                    # runbooks, upgrades, monitoring helpers
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

Prerequisite (via Tofu): Talos + Cilium + CoreDNS + sealed-secrets-cert + proxmox-csi.

```bash
export KUBECONFIG=~/.kube/talos-homelab
kubectl apply -k bootstrap/
kubectl get applications -n argocd -w   # ~5min until all green
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
