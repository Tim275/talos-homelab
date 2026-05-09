# MinIO — PARKED

**Status:** Folder existiert, NICHT in `storage/kustomization.yaml`. Replaced durch Ceph-RGW (homelab-objectstore).

## Warum entfernt

- Ceph-RGW (RADOS Gateway) liefert S3-API direkt aus dem Ceph-Cluster
- Selbe 3-fach Replikation wie Block-Storage
- 1 Storage-System statt 2 separate Daemons

## Wo S3-Buckets jetzt leben

`storage/radosgateway/` → `homelab-objectstore` CephObjectStore

Buckets:
- velero-backups
- loki-chunks
- tempo-traces
- cnpg-drova-backup

## Restore

```bash
# Wenn jemals MinIO statt Ceph-RGW gewünscht:
# 1. application.yaml anlegen
# 2. storage/kustomization.yaml: + - minio/application.yaml
```
