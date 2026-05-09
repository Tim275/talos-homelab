# Longhorn — PARKED

**Status:** Folder existiert, NICHT in `storage/kustomization.yaml`. Replaced durch Rook-Ceph.

## Warum entfernt

- Rook-Ceph deckt Block + RWX + S3 ab (3-in-1)
- Longhorn nur Block-Storage → redundant
- 2 parallel laufende Storage-Provider = Confusion

## Restore (falls Longhorn doch gebraucht)

```bash
# 1. application.yaml in Folder anlegen
# 2. storage/kustomization.yaml: + - longhorn/application.yaml
# 3. git push → ArgoCD synct
```
