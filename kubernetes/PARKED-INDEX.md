# Parked-Components Master-Index (Stand 2026-05-09)

Diese Komponenten existieren als Folder + Files, sind aber **NICHT in ArgoCD aktiv** (auskommentiert in der jeweiligen `kustomization.yaml`).

**Zweck:** Restore-fähigkeit ohne Daten zu löschen. Wenn du was wieder brauchst → Restore-Steps in der jeweiligen `PARKED.md`.

## Wie das Pattern funktioniert

```
1. application.yaml im Folder bleibt liegen
2. Parent kustomization.yaml hat den Eintrag auskommentiert (#)
3. Folder enthält PARKED.md mit:
   - Warum entfernt
   - Restore-Steps
   - Verweis auf Replacement
4. ArgoCD synct nicht → keine Pod-Erzeugung
5. Restore = einkommentieren + git push (1-3min)
```

## Aktuell parked Components

### Network — Service-Mesh (entfernt April 2026)
| Folder | Reason | Replacement |
|---|---|---|
| `infrastructure/network/istio-base/` | 0 von 8 Features genutzt, 500MB RAM-Overhead | Cilium SPIRE + Hubble + L7-Proxy |
| `infrastructure/network/istio-cni/` | s.o. | Cilium CNI |
| `infrastructure/network/istio-config/` | s.o. | CiliumNetworkPolicy + ClusterPolicy |
| `infrastructure/network/istio-control-plane/` | s.o. (parent kustomization commented) | — |
| `infrastructure/network/istio-gateway/` | s.o. | Envoy Gateway via Gateway API |

### Storage — duplicate Provider (entfernt April 2026)
| Folder | Reason | Replacement |
|---|---|---|
| `infrastructure/storage/longhorn/` | nur Block-Storage, redundant | Rook-Ceph RBD |
| `infrastructure/storage/minio/` | separater S3-Daemon | Ceph-RGW (homelab-objectstore) |
| `infrastructure/storage/proxmox-csi/` | single-host failure-domain | Rook-Ceph RBD (replicated) |

### Platform — non-prod Demos (entfernt 2025)
| Folder | Reason | Replacement |
|---|---|---|
| `platform/data/boutique-postgres/` | Online-Boutique Demo, nie produktiv | — |
| `platform/messaging/kafdrop/` | Topic-UI, replaced durch Strimzi-CLI + Apicurio | Apicurio Schema-Registry |

### Apps — private Apps (entfernt April 2026)
| Folder | Reason | Replacement |
|---|---|---|
| `apps/base/audiobookshelf/` | Privat-App, nicht Teil der Senior-Demo | — |
| `apps/overlays/prod/oms/` | OMS-Tenant external repo nicht produktionsreif | — |

### Security — Dead-Code (entfernt 2026-05-09)
| Folder | Reason | Replacement |
|---|---|---|
| `security/rbac/oidc-users/` | Authelia-Era, wrong prefix `oidc:` statt `oidc-grp:` | `security/foundation/rbac/oidc-bindings.yaml` |

### Kustomization-Comments (in-place parked, no folder rename)
| Pfad | Auskommentiert in |
|---|---|
| `platform/data/lldap-db` | `platform/data/kustomization.yaml` (LLDAP nutzt SQLite) |
| `platform/data/infisical-db` | `platform/data/kustomization.yaml` (Resource-Optimization) |
| `platform/data/druid` | `platform/data/kustomization.yaml` (Apache Druid analytics) |
| `platform/data/n8n-dev-cnpg` | `platform/data/kustomization.yaml` (dev-DB pausiert) |
| `platform/identity/authelia` | `platform/identity/kustomization.yaml` (replaced by Keycloak) |
| `platform/identity/infisical` | `platform/identity/kustomization.yaml` (Resource-Optimization) |
| `platform/messaging/kafka` | `platform/messaging/kustomization.yaml` (Generic, nur drova-kafka aktiv) |
| `apps/overlays/dev/n8n` | `apps/overlays/dev/kustomization.yaml` (dev-Workload pausiert) |

## Reactivation Checklist

Wenn du eine Komponente wieder aktivierst:

```bash
# 1. PARKED.md im Folder lesen — gibt Restore-Steps
# 2. application.yaml in Parent-kustomization.yaml einkommentieren
# 3. CLAUDE.md Eintrag (falls vorhanden) auf "active" updaten
# 4. git commit + push
# 5. ArgoCD UI: prüfen ob neue App synced + healthy
# 6. PARKED.md im Folder löschen ODER auf "REACTIVATED" updaten
```

## Cleanup-Policy

**Niemals löschen** wenn:
- Folder hat funktionierenden Code
- Folder enthält Helm-Charts (vendored)
- Restore-Pfad ist dokumentiert

**Löschen erlaubt** wenn:
- Folder ist komplett leer (z.B. mkdir-Artefakt)
- Folder hat nur veralteten Code der nicht mehr läuft (incompatible API-Versions)
- Komponente wurde durch komplett anderes Konzept ersetzt UND Tests in 6 Monaten OK

## Audit-Befehl

```bash
# Welche PARKED.md gibt's aktuell?
find kubernetes -name PARKED.md -type f
```
