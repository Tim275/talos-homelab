# Custom Dashboards

Hand-geschriebene `GrafanaDashboard`-CRs (nicht die importierten Community-Dashboards
unter `../community-dashboards/`), nach Domäne sortiert:

```
apps/            cloudflared, keycloak, n8n, velero-backup-status
business/        business-kpis
drova/           overview, service-detail, slo-burnrate
infrastructure/  proxmox, talos-os
network/         edge-slo
observability/   alertmanager-state, jaeger-internals, tempo-service-graph, vector-throughput
security/        waf-coraza
```

## Neues Dashboard anlegen

`json: |` inline in einer `GrafanaDashboard`-CR (Vorlage: eine bestehende Datei
kopieren, z.B. `drova/drova-overview.yaml`). `folderRef` bestimmt den Ordner in der
Grafana-UI, `uid` muss eindeutig und stabil sein (ändern reißt die Bookmark-Links).

Danach den Pfad in der passenden `kustomization.yaml` eintragen.

## Debugging

- Dashboard taucht nicht auf → `kubectl get grafanadashboard -n grafana <name>` auf
  `DashboardSynchronized` prüfen
- Query liefert nichts → Query direkt in Grafana Explore gegen Prometheus/Loki testen
- `uid` nachträglich geändert → hängt die App auf `Unknown`, CR muss gelöscht + neu
  angelegt werden (siehe `reference_grafana_dashboard_uid_immutable` in den Notes)
