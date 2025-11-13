# Current Backup Status

**Last Updated**: 2025-10-28
**Status**: Production Ready for Homelab

---

## Current Implementation

### Velero Backup Schedules (Active)

| Schedule | Frequency | Retention | What | Status |
|----------|-----------|-----------|------|--------|
| `daily-cluster-backup` | Daily 3 AM | 7 days | All Kubernetes resources | ✅ Active |
| `daily-pv-backup` | Daily 4 AM | 7 days | CSI volume snapshots (PVs) | ✅ Active |
| `weekly-full-backup` | Sunday 2 AM | 30 days | Full cluster state | ✅ Active |

### Storage Backend

- **Primary**: Ceph RGW S3 (on-premises)
  - Buckets: `velero-cluster-backups`, `velero-pv-backups`
  - Endpoint: `http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80`
  - Credentials: CephObjectStoreUser `velero-user`
- **Replication**: 3x within Ceph cluster
- **Encryption**: SSE-S3 + TLS

### What Gets Backed Up

1. **Kubernetes Resources** (daily-cluster-backup)
   - Deployments, Services, ConfigMaps, Secrets
   - ArgoCD Applications
   - Cert-Manager Certificates
   - All application manifests

2. **Persistent Volumes** (daily-pv-backup)
   - PostgreSQL databases (n8n-prod, n8n-dev)
   - All PVCs via CSI snapshots
   - Rook-Ceph block storage snapshots

3. **Full Cluster State** (weekly-full-backup)
   - Complete cluster snapshot for disaster recovery
   - All namespaces (except kube-system, kube-public)

---

## Known Limitations

### CNPG Barman Backups: DISABLED

**Status**: ❌ Disabled
**Reason**: Ceph RGW multipart upload bug
**File**: `kubernetes/platform/data/n8n-prod-cnpg/cluster.yaml` (lines 46-67 commented out)

**Details**:
- CloudNativePG Barman requires S3 multipart uploads for large backups
- Ceph RGW returns `InvalidRequest` on `CreateMultipartUpload` operations
- Small uploads (<10 bytes) work, but PostgreSQL backups fail
- Last test: 2025-10-28

**Workaround**: Using Velero CSI volume snapshots instead
- Daily PV backups at 4 AM capture entire PostgreSQL volumes
- Storage-level snapshots (instant, consistent)
- No logical pg_dump backups (trade-off accepted)

**Future**: Re-enable when Ceph RGW multipart uploads are fixed or migrate to external S3

---

## Database Backup Strategy

### Current Approach: CSI Volume Snapshots

```
┌─────────────────────────────────────────────┐
│ PostgreSQL (n8n-prod)                       │
│ └─ PVC: n8n-postgres-data (8Gi)           │
└─────────────────────────────────────────────┘
                  │
                  │ Daily at 4 AM
                  ▼
┌─────────────────────────────────────────────┐
│ Velero CSI Snapshot                         │
│ └─ Storage-level snapshot (Ceph RBD)       │
│ └─ Retention: 7 days                       │
└─────────────────────────────────────────────┘
```

**Advantages**:
- ✅ Works with Ceph RGW (no multipart uploads needed)
- ✅ Instant snapshots (no backup window)
- ✅ Consistent (filesystem-level snapshot)
- ✅ Daily backups (max 24h data loss)

**Trade-offs**:
- ⚠️ No logical backups (pg_dump)
- ⚠️ No Point-in-Time Recovery (PITR)
- ⚠️ No WAL archiving
- ⚠️ Restore requires full PV restore (not individual tables)

**Accepted Risk**: For homelab, storage snapshots are sufficient. No transaction-level recovery needed.

---

## Disaster Recovery

### RPO/RTO (Recovery Point/Time Objectives)

| Scenario | RPO | RTO | Recovery Method |
|----------|-----|-----|-----------------|
| Accidental deletion | 24h | 30min | Velero restore |
| Node failure | 0h | 1h | Ceph auto-recovery |
| Complete cluster loss | 24h | 4h | GitOps + Velero restore |
| Ransomware | 24h | 2h | S3 versioning + restore |

### Restore Examples

**Restore N8N namespace:**
```bash
velero backup get | grep daily-cluster-backup
velero restore create n8n-restore \
  --from-backup daily-cluster-backup-20251028030000 \
  --include-namespaces n8n-prod \
  --wait
```

**Restore PostgreSQL PV:**
```bash
velero backup get | grep daily-pv-backup
velero restore create n8n-pv-restore \
  --from-backup daily-pv-backup-20251028040000 \
  --include-namespaces n8n-prod \
  --wait
```

---

## Future Enhancements (Optional)

### Phase 1: Cloud DR (Offsite Backups)

**Status**: ⏭️ Skipped for homelab (not cost-justified)

**Reason**:
- Homelab has no business revenue risk
- On-premises 3x Ceph replication sufficient
- Total loss scenario: Rebuild from Git/IaC (2-3 days acceptable)
- Cost: $50/month not justified for hobby project

**If needed in future**:
```yaml
# AWS S3 DR location
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: aws-dr
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: homelab-velero-dr
  config:
    region: eu-central-1
```

**Cost**: ~$20-50/month for 500GB (S3 Standard → Glacier)

### Phase 2: Fix Ceph RGW Multipart Uploads

**Goal**: Re-enable CNPG Barman backups for logical PostgreSQL backups

**Options**:
1. **Upgrade Ceph**: Test if newer Rook-Ceph versions fix multipart bug
2. **External S3**: Use AWS S3 or MinIO for CNPG backups only
3. **Alternative tool**: Evaluate PGBackRest or Stash instead of Barman

**Benefit**: Point-in-Time Recovery (PITR), WAL archiving, individual table restore

### Phase 3: Automated Restore Testing

**Goal**: Monthly CronJob that tests restore functionality

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: velero-restore-test
  namespace: velero
spec:
  schedule: "0 5 1 * *"  # Monthly on 1st at 5 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: test-restore
            image: velero/velero:v1.14
            command:
            - /bin/bash
            - -c
            - |
              velero restore create test-$(date +%Y%m%d) \
                --from-backup daily-cluster-backup-latest \
                --namespace-mappings n8n-prod:n8n-test \
                --wait
              kubectl delete namespace n8n-test
```

**Benefit**: Verify backups actually work before you need them

---

## Monitoring

### Current Status

- ⚠️ Manual verification only
- Check: `velero backup get` shows latest backups
- Check: `velero backup-location get` shows Available status

### Future: Prometheus Alerts

```yaml
- alert: VeleroBackupFailed
  expr: velero_backup_failure_total > 0
  for: 15m
  annotations:
    summary: "Velero backup {{ $labels.schedule }} failed"

- alert: VeleroBackupTooOld
  expr: time() - velero_backup_last_successful_timestamp > 86400
  annotations:
    summary: "No backup in 24h for {{ $labels.schedule }}"
```

**Status**: Not yet implemented (low priority for homelab)

---

## Summary

### What Works ✅

- Daily Kubernetes resource backups (manifests, secrets, configs)
- Daily PV snapshots (PostgreSQL databases, all PVCs)
- Weekly full cluster backups
- S3 storage with 3x replication
- Encryption at rest and in transit
- 7-30 day retention

### What Doesn't Work ❌

- CNPG Barman backups (Ceph RGW multipart bug)
- Logical PostgreSQL backups (pg_dump)
- Point-in-Time Recovery (PITR)
- Offsite/cloud DR (skipped by choice)

### What's Acceptable for Homelab ✅

- CSI snapshots sufficient for database backups
- Daily backups = max 24h data loss acceptable
- On-premises only (no cloud costs)
- Manual restore testing (no automation)
- No business revenue at risk

---

## Conclusion

**Status**: Production-ready backup strategy for homelab workloads

**Risk accepted**: In case of total homelab loss (fire, flood, theft), infrastructure can be rebuilt from Git/IaC in 2-3 days. Max 24h of data loss from last backup.

**Next action**: None - backup strategy is complete and operational.
