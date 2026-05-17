# Kubernetes Homelab

Talos K8s 1.36 + ArgoCD GitOps + Cilium + Rook-Ceph.
**63 ArgoCD-managed Applications** across 9 logical tiers.

## Structure (Stand 2026-05-17)

```
kubernetes/
├── bootstrap/                    # LAYER 1: Bootstrap entrypoint (App-of-Apps)
│   ├── kustomization.yaml
│   ├── security.yaml             # → security/  (Wave 0)
│   ├── infrastructure.yaml       # → infrastructure/  (Wave 1)
│   ├── platform.yaml             # → platform/  (Wave 15)
│   └── apps.yaml                 # → apps/  (Wave 25)
│
├── applicationsets/              # ApplicationSet generators (multi-cluster)
│   ├── infrastructure/           # generates infrastructure-apps per cluster
│   ├── platform/                 # generates platform-apps per cluster
│   ├── security/                 # generates security-apps per cluster
│   ├── edge/                     # future: edge-cluster-specific
│   └── tenants/                  # multi-tenant per-cluster apps (drova-tenant)
│
├── clusters/                     # Per-cluster identifiers + secrets
│   ├── in-cluster.yaml           # current prod-talos cluster
│   └── staging.yaml.template     # future Pi-staging-cluster
│
├── projects/                     # ArgoCD AppProjects (RBAC + sync-windows)
│
├── components/                   # Kustomize components (reusable patches)
│   ├── arm64-arch/               # for Pi-staging future
│   ├── short-retention/          # dev/staging retention-overrides
│   └── single-replica/           # dev/staging HA-disabled patches
│
├── infrastructure/               # LAYER 2: Cluster-infra-apps
│   ├── controllers/              # ArgoCD, cert-manager, sealed-secrets, operators
│   ├── network/                  # Cilium, Gateway-API, Cloudflared, CoreDNS
│   ├── observability/            # kube-prometheus-stack, Grafana, Loki, Tempo, OTel
│   ├── storage/                  # Rook-Ceph, Velero, CSI-snapshot-controller
│   └── vpn/                      # NetBird (self-hosted mesh-VPN)
│
├── platform/                     # LAYER 2: Platform services (tenant-facing)
│   ├── data/                     # CNPG-Postgres, Redis (drova/n8n), Elasticsearch
│   ├── developer-platform/       # Renovate, GitLab (optional)
│   ├── drova-infra/              # Drova-tenant-shared infra (Kafka cluster)
│   ├── gitlab/                   # GitLab platform
│   ├── governance/               # Tenant-policies + RBAC
│   ├── identity/                 # Keycloak + LLDAP (OIDC + LDAP-backend)
│   └── messaging/                # Strimzi-Kafka, Schema-Registry
│
├── apps/                         # LAYER 2: Tenant workloads
│   ├── base/                     # base-manifests
│   └── overlays/                 # prod/staging-overlays per tenant
│
├── security/                     # LAYER 2: Security policies
│   ├── compliance/               # Kubescape (runtime scanning)
│   ├── foundation/               # Cilium NetPols (default-deny, mTLS, FQDN-egress)
│   ├── governance/               # PolicyExceptions
│   ├── kyverno/                  # Kyverno policies (image-allowlist, no-privileged)
│   └── rbac/                     # ClusterRoleBindings
│
└── scripts/                      # Operational scripts (not ArgoCD-managed)
    ├── identity/                 # Keycloak/LLDAP user-bootstrap helpers
    ├── runbooks/                 # Incident-response scripts
    └── upgrades/                 # Pre-upgrade-checks (Strimzi, CNPG, etc.)
```

## Bootstrap

**Standard (App-of-Apps via ArgoCD):**
```bash
export KUBECONFIG="../tofu/output/kube-config.yaml"
kubectl apply -k bootstrap/
kubectl get applications -n argocd -w
```

**Layer-by-Layer (für DR/troubleshooting):**
```bash
kubectl apply -k security/         # Wave 0
kubectl apply -k infrastructure/   # Wave 1
kubectl apply -k platform/         # Wave 15
kubectl apply -k apps/             # Wave 25
```

**Manual Core (no ArgoCD-Bootstrap, für initial-setup):**
```bash
# 1. Cilium first (no CNI = nothing else works)
kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -

# 2. Sealed-Secrets (before any other secret)
kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -

# 3. Rook-Ceph (CRDs too large for client-side apply)
kubectl kustomize --enable-helm infrastructure/storage/rook-ceph | \
  kubectl apply --server-side --force-conflicts -f -

# 4. ArgoCD (after which app-of-apps takes over)
kubectl kustomize --enable-helm infrastructure/controllers/argocd | kubectl apply -f -
```

## Application-Inventory (Stand 2026-05-17)

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

## Multi-Cluster Pattern (Stand 2026-05-17)

Alerts und Dashboards nutzen jetzt **path-only-Annotations** + **external_labels**.
Bei staging/dev-cluster-Aufbau: nur `grafana_url` external-label per Overlay setzen,
Alert-rules selbst bleiben in base/.

Siehe: `infrastructure/observability/metrics/kube-prometheus-stack/overlays/{prod,staging}/values-*.yaml`

## ArgoCD

```bash
# Initial-admin-password (one-time before SSO)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Production: OIDC via Keycloak (SSO-only, admin.enabled=false)
# → https://argo.timourhomelab.org
```

## Friday-Freeze Sync-Windows

Production-AppProjects haben sync-windows konfiguriert:
- **Schedule:** `0 16 * * 5` (Friday 16:00 Europe/Berlin)
- **Duration:** 50h (bis Sunday 18:00)
- **Kind:** `deny` (auto-syncs blocked)
- **manualSync:** true (admin-override via argocd CLI)

Renovate-PRs gemerged während Freeze warten auf Sunday 18:00.

## Operational Notes

- **Talos + Kubernetes Versionen:** Manuelle Upgrades via `talosctl`, NIE via Renovate
  (siehe `tofu/talos_cluster.auto.tfvars` in renovate.json `ignorePaths`).
- **Rook-Ceph Apply:** Immer mit `--server-side` (große CRDs).
- **Sealed-Secrets-Cert:** In Tofu-Bootstrap gemanaged. Bei cluster-recreate
  bleibt der gleiche cert → SealedSecrets in Git decryptable.
- **From-scratch Guides:** Siehe `notes/CLAUDE-GUIDES.md` (gitignored, lokal).
