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

Kein erfolgreiches Backup für eine existierende Schedule: tier0 seit 13 h, sonst seit 24 h. RPO überschritten. `PartiallyFailed` zählt nicht als Erfolg.

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
  LLDAP, Grafana, Forgejo, Uptime-Kuma und pgAdmin laufen über Ceph-Snapshots, dort zählen die `datauploads`:
  ```bash
  kubectl -n velero get datauploads -l velero.io/backup-name=<backup>
  ```
  OpenBao bleibt beim Datei-Backup, sein Operator verbietet Änderungen an den Volumes und damit Snapshots.
- `PartiallyFailed`: welches Volume, steht in den PodVolumeBackups (`velero backup logs` scheitert hier an `SignatureDoesNotMatch` vom RGW):
  ```bash
  kubectl -n velero get podvolumebackups -l velero.io/backup-name=<backup> -o custom-columns=POD:.spec.pod.name,VOL:.spec.volume,PHASE:.status.phase
  ```
  Kurzlebige Job-Pods (z. B. `lldap-bootstrap`) gehören nicht ins Backup: Pod-Template-Label `velero.io/exclude-from-backup: "true"`.

## VeleroNoRecentWeeklyBackup

Wie [VeleroNoRecentBackup](#veleronorecentbackup), für die Wochen-Schedules (`tier2-*`, `*-weekly`) mit 8 Tagen Grenze.

## BackupCopyStale

Die nächtliche Kopie der Backup-Buckets auf die externe Platte an aoostar ist älter als 36 h. Ceph hält dann die einzige aktuelle Kopie.

```bash
ssh root@aoostar
systemctl status backup-copy.timer
journalctl -u backup-copy -n 50
ls /dev/disk/by-label/backup-hdd
```

- Platte nicht da → Kabel, Strom, `lsblk`. Der Job endet ohne Platte ohne Fehler und schreibt keine Metrik.
- Einrichtung und Skript: `tofu/stacks/proxmox/install/backup-copy.sh`. Kopiert wird um 04:30, gelöscht wird nie.
- Auf der Platte liegt je Bucket ein Ordner unter `rgw/`, lesbar mit jedem Linux.

Wiederherstellen, wenn Ceph weg war und neu steht (RGW läuft, Buckets und Benutzer sind wieder angelegt):

```bash
mount /mnt/backup-hdd
rclone copy /mnt/backup-hdd/rgw/velero-cluster-backups rgw:velero-cluster-backups --s3-acl bucket-owner-full-control
```

Je Bucket einmal, dann den Velero-Speicherort auf `ReadOnly` stellen und wie gewohnt `velero restore create --from-backup <backup>`. Postgres und OpenBao lesen ihre Sicherungen aus denselben Buckets wie vorher.
