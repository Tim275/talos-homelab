# OMS Tenant — PARKED

**Status:** Folder existiert, NICHT in `apps/overlays/prod/kustomization.yaml` referenziert.
External Tenant-Repo: `github.com/Tim275/oms-tenant`.

## Warum entfernt

- OMS-Tenant war geplant als zweiter Tenant neben Drova
- External Repo `oms-tenant` ist noch nicht produktionsreif
- Application-CR zeigt auf externes Repo `path: overlays/production`

## Restore (wenn OMS produktionsreif)

```bash
# 1. apps/overlays/prod/kustomization.yaml ergänzen:
#    - oms/application.yaml
# 2. External Repo verifizieren: github.com/Tim275/oms-tenant existiert + main-Branch hat overlays/production
# 3. git push → ArgoCD synct
```
