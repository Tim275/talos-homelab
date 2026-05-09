# Audiobookshelf — PARKED

**Status:** Folder existiert, NICHT in `apps/overlays/{prod,dev}/kustomization.yaml` referenziert.
`apps/base/kustomization.yaml` ist `resources: []`.

## Warum entfernt

- Privat-App während Lernphase, nicht Teil der Senior-Demo
- Würde Cluster-Ressourcen verbrauchen ohne Operational-Wert

## Restore

```bash
# Wenn Audiobookshelf auf Cluster gehosted werden soll:
# 1. apps/overlays/prod/kustomization.yaml: + - audiobookshelf/application.yaml
# 2. apps/overlays/prod/audiobookshelf/kustomization.yaml hat schon Setup
# 3. git push → ArgoCD synct
```
