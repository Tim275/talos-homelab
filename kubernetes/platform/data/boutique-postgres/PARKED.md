# Boutique-Postgres — PARKED

**Status:** Folder existiert, NICHT in `platform/data/kustomization.yaml`. Demo-DB für GoogleCloud "Online Boutique" Microservices-Demo.

## Warum entfernt

- Boutique war Demo-App während Lernphase, nicht Production-Workload
- Keine Resource auf dem Cluster genutzt diese DB

## Restore

```bash
# Wenn Online-Boutique Demo wieder gewünscht:
# platform/data/kustomization.yaml: + - boutique-postgres/application.yaml
```
