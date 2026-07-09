# Tenant: drova

Vollständiger Fußabdruck des Drova-Tenants + wo welcher Teil bewusst liegt.

## In DIESEM Ordner (tenant-eigen, namespaced)

| Datei / Ordner        | Was                                             |
|-----------------------|-------------------------------------------------|
| `namespace.yaml`      | der Namespace                                   |
| `resourcequota.yaml`  | Verbrauchs-Obergrenze des NS                    |
| `limitrange.yaml`     | Default-Requests/Limits (löst die Quota-Falle)  |
| `rbac.yaml`           | **namespaced** Role + RoleBinding (Tenant-Admin via OIDC-Group `drova-admins`) |
| `atlas-allowlist-sync.yaml` | CronJob: hält die MongoDB-Atlas-IP-Allowlist aktuell |
| `kafka/ postgres/ redis/`   | die Daten-Dienste (via `drova-tenant` ApplicationSet) |

## Bewusst NICHT hier — Separation of Duties (DAX / MaRisk AT 4.3.1, BAIT)

Sicherheits­kontrollen gehören dem **Security-Team**, nicht dem Tenant. Wer die App
betreibt, darf seine eigene Firewall NICHT schreiben. Deshalb liegen diese unter
`security/` (App `security-foundation`, Project `security`) — der Tenant (Project
`platform`) kann sie nicht ändern:

| Ressource                | Ort                                                        |
|--------------------------|------------------------------------------------------------|
| NetworkPolicies (default-deny · egress · mTLS) | `security/foundation/network-policies/tenants/drova/` |
| Rate-Limiting (Envoy `BackendTrafficPolicy`)   | `security/foundation/rate-limiting/tenants/drova/`    |
| Cluster-weite OIDC-ClusterRoleBindings         | `security/foundation/rbac/oidc-bindings.yaml`         |

> Muster: **Scope bestimmt den Ort.** Namespaced + tenant-eigen → hier.
> Cluster-weit ODER Sicherheits­kontrolle (SoD) → `security/`.
> Innerhalb `security/` sind die Policies *pro Tenant* gruppiert
> (`.../tenants/drova/`) → trotzdem an einem Fleck auffindbar.

## Sonstige Drova-Referenzen (Cross-Cutting, gehören ihrem jeweiligen Layer)

- ApplicationSet:      `applicationsets/tenants/drova-tenant.yaml`
- Grafana-Dashboards:  `infrastructure/observability/dashboards/configs/drova/`
- Renovate:            `platform/gitops/renovate/base/renovate-drova.yaml`
- App-Workloads (Go):  Repo `Tim275/drova-gitops` → `overlays/production`
