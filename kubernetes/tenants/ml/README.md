# ML — Machine Learning Department (Tenant)

Namespace-isolierter Tenant für Drovas ML-Workloads. Gleiches Muster wie jeder andere
Tenant (`namespace` + `resourcequota` + `limitrange` + `rbac`), gescoped auf die
`ml`-Namespace, deployed über die `tenants-config` AppSet (Project `platform`, manual-sync).

## Wofür (Drova-ML-Use-Cases)

- **Dynamic Pricing** — Surge-Preise aus Angebot/Nachfrage (trip-service Events)
- **ETA-Prediction** — Ankunftszeit-Modell (driver-service Geo-Daten)
- **Fraud-Detection** — Auffällige Zahlungen (payment-service)
- **Matching** — Driver↔Rider Zuordnung

## Geplanter Stack (CPU-first, GPU-gated)

| Layer | Tool | Status |
|-------|------|--------|
| Experiment-Tracking | MLflow | geplant |
| Model-Serving | KServe | geplant |
| Pipelines | Argo Workflows | geplant |
| Feature-Store | Feast | geplant |

**Status:** Department-Struktur + Guardrails stehen (Namespace, Quota, LimitRange, RBAC).
Tools kommen inkrementell — GPU-Workloads sind geblockt bis ein GPU-Node da ist
(CPU-first Starter zuerst). Volle Landkarte: `notes/CLAUDE-MLOPS.md`.

## Ownership / RBAC

- ServiceAccount `ml-admin-sa` (interim, wie oms)
- OIDC-Pfad vorbereitet: Keycloak-Gruppe `keycloak-ml-engineers` → Namespace-Admin
  (in `rbac.yaml` einkommentieren sobald die LLDAP/Keycloak-Gruppe existiert)

## Aktivieren

`ml` ist bereits in der `tenants-config` AppSet verdrahtet. Deployen (manual-sync/DAX-Gate):

```bash
argocd app sync ml-config
```
