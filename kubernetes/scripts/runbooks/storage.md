# Storage

Ceph-Befehle laufen in der Toolbox:
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
```

## CephHealthError

Ceph meldet HEALTH_ERR. Datenintegrität gefährdet oder I/O blockiert.

```bash
ceph health detail
ceph -s
ceph osd df tree
```

- `OSD_FULL` / `POOL_FULL` → Ceph blockiert Writes. Platz schaffen (alte Snapshots, PVCs) oder OSD hinzufügen. Nicht die full-ratio hochsetzen und vergessen.
- `PG_DAMAGED` / inkonsistente PG:
  ```bash
  ceph health detail | grep inconsistent
  ceph pg repair <pgid>
  ```

## CephMonQuorumAtRisk

Ein MON ist weg, es bleibt nur das Mindest-Quorum. Fällt noch einer aus, steht jeder I/O. Danach meldet auch der MGR nichts mehr, das Signal ist dann `RookCephMgrDown`.

```bash
ceph mon stat
ceph quorum_status -f json-pretty | grep -A5 quorum_names
kubectl -n rook-ceph get pods -l app=rook-ceph-mon -o wide
```

- Node des fehlenden MON prüfen: NotReady → [ProxmoxHostDown](hosts.md#proxmoxhostdown)
- In dieser Zeit keine Nodes rebooten, keine Talos-Upgrades.

## CephOSDMajorityDown

Mehr als die Hälfte der OSDs ist down. Storage steht, Datenverlust möglich.

```bash
ceph osd tree | grep down
kubectl -n rook-ceph get pods -l app=rook-ceph-osd -o wide
```

- Liegen die toten OSDs auf demselben Host → Host-Problem, siehe [hosts.md](hosts.md#proxmoxhostdown)
- `ceph osd set noout`, solange repariert wird, sonst beginnt Ceph mit dem Umverteilen
- Nicht alle OSDs gleichzeitig neu starten.

## LogsDiskIOError

Eine OSD meldet Lese-/Schreibfehler von der Platte. Ceph kann noch HEALTH_OK zeigen, während die SSD schon stirbt.

```bash
stern -n rook-ceph . --since 15m -i 'i/o error'
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph device ls
```

- `ceph device ls` zeigt nur die virtuellen Disks der VMs (worker-X:sdb → osd.N). Welche physische Platte darunter liegt, steht am Host: `ssh root@<host> 'qm config <vmid> | grep scsi1; pvesm status'`
- Physische Platte prüfen → [SSDSmartHealthFailed](hosts.md#ssdsmarthealthfailed)

## PVCCriticallyFull

Ein PVC hat weniger als 10 % frei.

```bash
kubectl df-pv -n <ns>
kubectl -n <ns> patch pvc <pvc> -p '{"spec":{"resources":{"requests":{"storage":"<neu>"}}}}'
kubectl -n <ns> get pvc <pvc> -w
```

- Alle `rook-ceph-*`-StorageClasses erlauben Online-Vergrößerung.
- Danach die Größe in Git nachziehen (Helm-Values oder PVC-Manifest), sonst zeigt ArgoCD dauerhaft Drift und ein Neuaufbau bekommt wieder die alte Größe.
- Verkleinern geht nicht.

## VeleroNoRecentBackup

Seit 24 h kein erfolgreiches Backup für eine existierende Schedule. RPO überschritten.

```bash
kubectl -n velero get backups.velero.io --sort-by=.metadata.creationTimestamp | tail -10
kubectl -n velero describe backups.velero.io <backup> | grep -iA5 -E "phase|error|warning"
kubectl -n velero get backupstoragelocations
kubectl -n velero logs -l name=velero --tail 100 | grep -i error
```

- Immer `backups.velero.io` ausschreiben, `kubectl get backups` trifft die CNPG-CRD.
- BackupStorageLocation nicht `Available` → RGW-Bucket, Credentials, Quota.
- `Completed` heißt nicht, dass Volume-Daten drin sind:
  ```bash
  kubectl -n velero get podvolumebackups -l velero.io/backup-name=<backup> --no-headers | wc -l
  ```

## VeleroNoRecentWeeklyBackup

Wie [VeleroNoRecentBackup](#veleronorecentbackup), für die Wochen-Schedules (`tier2-*`, `*-weekly`) mit 8 Tagen Grenze.
