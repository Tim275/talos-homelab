# Kubernetes Homelab

Talos K8s 1.36 + ArgoCD GitOps + Cilium + Rook-Ceph.

63 ArgoCD-managed Applications across 9 logical tiers.

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

## Application-Inventory

```
Network          5  cilium, hubble, envoy-gateway, cloudflared, coredns
Storage          4  rook-ceph, rook-ceph-rgw, csi-snapshot-controller, velero(+ui+schedules)
Data            10  drova-postgres, keycloak-db, n8n-postgres, redis-{drova,gateway,n8n},
                    elasticsearch, kibana, cloudbeaver, drova-kafka
Identity         2  keycloak, lldap
Apps             3  drova-prod, n8n-prod, uptime-kuma-prod
Observability   10  kube-prometheus-stack, grafana, loki, tempo, jaeger, kibana,
                    opentelemetry, vector, blackbox-exporter, pve-exporter
Security         5  sealed-secrets, cert-manager, security-{foundation,compliance,kyverno}
GitOps/CI        8  argocd, argo-rollouts, renovate, dashboards, velero-{ui,schedules},
                    gitlab-platform, infrastructure-alerts
Operators        7  Strimzi, CNPG, ECK, Keycloak, Grafana, Redis, OpenTelemetry
```

## Multi-Cluster Pattern

Alerts und Dashboards nutzen path-only-Annotations + external_labels.
Bei staging/dev-cluster-Aufbau: nur `grafana_url` external-label per Overlay setzen,
Alert-rules selbst bleiben in base/.

Siehe `infrastructure/observability/metrics/kube-prometheus-stack/overlays/{prod,staging}/values-*.yaml`.

## ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Production: OIDC via Keycloak (SSO-only, admin.enabled=false) → https://argo.timourhomelab.org

## Friday-Freeze Sync-Windows

Production-AppProjects haben sync-windows konfiguriert:
- Schedule: `0 16 * * 5` (Friday 16:00 Europe/Berlin)
- Duration: 50h (bis Sunday 18:00)
- Kind: `deny` (auto-syncs blocked)
- manualSync: true (admin-override via argocd CLI)

Renovate-PRs gemerged während Freeze warten auf Sunday 18:00.

## Operational Notes

- Talos + Kubernetes Versionen: Manuelle Upgrades via `talosctl`, NIE via Renovate
  (siehe `tofu/talos_cluster.auto.tfvars` in renovate.json `ignorePaths`).
- Rook-Ceph Apply: Immer mit `--server-side` (große CRDs).
- Sealed-Secrets-Cert: In Tofu-Bootstrap gemanaged. Bei cluster-recreate
  bleibt der gleiche cert → SealedSecrets in Git decryptable.
- From-scratch Guides: Siehe `notes/CLAUDE-GUIDES.md` (gitignored, lokal).
