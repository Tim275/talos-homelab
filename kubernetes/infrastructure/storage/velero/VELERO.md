# Velero Enterprise Backup System

## Overview

Production-grade Kubernetes cluster backup and disaster recovery system using Velero with Ceph RGW S3-compatible object storage.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Velero Backup System (Enterprise 3-Tier)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐      │
│  │   Hourly    │     │    Daily    │     │   Weekly    │      │
│  │  Critical   │────▶│   Cluster   │────▶│    Full     │      │
│  │  Backups    │     │   Backups   │     │   Backups   │      │
│  │             │     │             │     │             │      │
│  │ 0 * * * *   │     │ 0 3 * * *   │     │ 0 2 * * 0   │      │
│  │ (Every hour)│     │ (Daily 3AM) │     │ (Sun 2AM)   │      │
│  │ 7d retention│     │ 30d retain  │     │ 90d retain  │      │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘      │
│         │                   │                    │              │
│         └───────────────────┴────────────────────┘              │
│                             ▼                                    │
│         ┌───────────────────────────────────────┐              │
│         │ Velero Node Agent (DaemonSet)         │              │
│         │ • Restic/Kopia file-level PV backups  │              │
│         │ • Client-side encryption              │              │
│         │ • Incremental snapshots               │              │
│         └───────────────────┬───────────────────┘              │
│                             ▼                                    │
│         ┌───────────────────────────────────────┐              │
│         │ Velero Server (Deployment)            │              │
│         │ • Kubernetes API resource backup      │              │
│         │ • PV metadata orchestration           │              │
│         └───────────────────┬───────────────────┘              │
│                             ▼                                    │
│  ┌──────────────────────────────────────────────────┐          │
│  │ BackupStorageLocations (BSL)                    │          │
│  ├──────────────────────────────────────────────────┤          │
│  │ 1. cluster-backups (default)                     │          │
│  │    └─▶ velero-cluster-backups bucket             │          │
│  │        (ConfigMaps, Secrets, Deployments, etc.)  │          │
│  │                                                   │          │
│  │ 2. pv-backups                                     │          │
│  │    └─▶ velero-pv-backups bucket                  │          │
│  │        (Volume snapshots via Restic)             │          │
│  └──────────────────┬───────────────────────────────┘          │
│                     ▼                                            │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Ceph RGW S3-Compatible Object Storage                │    │
│  │ • Enterprise-grade reliability                        │    │
│  │ • 3x replication (homelab-objectstore)               │    │
│  │ • Zone/Realm configured for metadata persistence     │    │
│  │ • HTTP endpoint (internal cluster networking)        │    │
│  └────────────────────┬───────────────────────────────────┘    │
│                       ▼                                          │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Ceph Storage Cluster (Rook-managed)                   │    │
│  │ • 6 OSDs across worker nodes                          │    │
│  │ • Wire encryption (msgr2 secure mode)                │    │
│  │ • PG autoscaler enabled                               │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## ✅ Fixed: Ceph RGW Zone Configuration

**Critical Fix Applied**: Added Zone configuration to CephObjectStore to fix bucket metadata persistence.

### Root Cause
Ceph RGW was running **without Zone/Realm/Period configuration**, causing:
- ❌ Buckets created via S3 API but metadata not persisted
- ❌ `radosgw-admin bucket list` returned empty despite successful S3 operations
- ❌ Velero backups failing due to missing bucket metadata

### Solution
**File**: `kubernetes/infrastructure/storage/rook-ceph-rgw/ceph-object-store.yaml:29-32`

```yaml
# 🔧 FIX: Explicit zone configuration for proper RGW metadata persistence
# Without this, bucket metadata is not persisted correctly
zone:
  name: "homelab"
```

**Additional Fix**: Manually configured Realm/Period
```bash
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin realm default --rgw-realm=homelab-objectstore
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin period update --commit
```

**Result**: ✅ Buckets now persist correctly in Ceph!

## Components

### 1. S3 Buckets (Ceph RGW)

**Created Buckets:**
```bash
velero-cluster-backups   # Kubernetes manifests, ConfigMaps, Secrets
velero-pv-backups        # PersistentVolume data via Restic/Kopia
n8n-prod-backups         # N8N PostgreSQL backups
infisical-prod-backups   # Infisical PostgreSQL backups
elasticsearch-snapshots  # Elasticsearch SLM snapshots
```

**CephObjectStoreUsers:**
- `velero-cluster-backups` - Velero cluster resources
- `velero-pv-backups` - Velero volume snapshots
- `n8n-prod-backups` - N8N backup automation
- `infisical-prod-backups` - Infisical backup automation
- `elasticsearch-snapshots` - Elasticsearch snapshots

### 2. BackupStorageLocations (BSL)

**File**: `backup-storage-locations.yaml`

#### BSL 1: cluster-backups (Default)
```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: cluster-backups
spec:
  provider: aws
  default: true  # Default BSL for all backups
  objectStorage:
    bucket: velero-cluster-backups
    prefix: cluster
  config:
    s3Url: http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
    s3ForcePathStyle: "true"  # Required for Ceph RGW
    insecureSkipTLSVerify: "true"  # HTTP endpoint (internal cluster)
```

**Use Case**: Kubernetes API resources (ConfigMaps, Secrets, Deployments, Services, etc.)

#### BSL 2: pv-backups
```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: pv-backups
spec:
  provider: aws
  default: false  # Explicit use for PV backups
  objectStorage:
    bucket: velero-pv-backups
    prefix: volumes
```

**Use Case**: PersistentVolume file-level backups via Restic/Kopia

### 3. Backup Schedules

**File**: `backup-schedules.yaml`

#### Schedule 1: Hourly Critical Backups
```yaml
schedule: "0 * * * *"  # Every hour
includedNamespaces:
  - kube-system
  - rook-ceph
  - cert-manager
  - argocd
  - sealed-secrets
  - velero
ttl: 168h  # 7 days
```
**Purpose**: Fast recovery for critical infrastructure

#### Schedule 2: Daily Cluster Backup
```yaml
schedule: "0 3 * * *"  # Daily 3 AM UTC
includedNamespaces: ["*"]
excludedResources:
  - nodes
  - events
  - backups.velero.io
  - restores.velero.io
snapshotVolumes: false  # No PV snapshots
ttl: 720h  # 30 days
```
**Purpose**: Complete Kubernetes resource backup (no PVs)

#### Schedule 3: Daily PV Backup
```yaml
schedule: "0 4 * * *"  # Daily 4 AM UTC (1 hour after cluster backup)
includedResources:
  - persistentvolumeclaims
  - persistentvolumes
defaultVolumesToFsBackup: true  # Enable Restic
ttl: 720h  # 30 days
```
**Purpose**: Separate PV data backup with Restic encryption

#### Schedule 4: Weekly Full Backup
```yaml
schedule: "0 2 * * 0"  # Every Sunday 2 AM UTC
includedNamespaces: ["*"]
defaultVolumesToFsBackup: true  # Include PVs
ttl: 2160h  # 90 days
```
**Purpose**: Long-term disaster recovery backup

### 4. S3 Credentials Management

**Script**: `create-s3-credentials.sh`

**Purpose**: Extract S3 credentials from CephObjectStoreUser Secrets and create Velero-compatible credential secrets.

**Process**:
1. Extract AccessKey/SecretKey from Rook-generated secrets
2. Format as AWS credentials file
3. Create Velero credential secrets

**Output Secrets**:
- `velero-s3-credentials-cluster` - For cluster-backups BSL
- `velero-s3-credentials-pv` - For pv-backups BSL

**Format**:
```ini
[default]
aws_access_key_id=<ACCESS_KEY>
aws_secret_access_key=<SECRET_KEY>
```

## Deployment

### Prerequisites
1. ✅ Velero deployed with AWS plugin (`infrastructure/storage/velero/kustomization.yaml`)
2. ✅ Ceph RGW with Zone configured (`infrastructure/storage/rook-ceph-rgw/`)
3. ✅ CephObjectStoreUsers created
4. ✅ S3 buckets created

### Step 1: Create CephObjectStoreUsers
```bash
kubectl apply -f infrastructure/storage/velero/ceph-users/
kubectl get cephobjectstoreuser -n rook-ceph
```

### Step 2: Create S3 Buckets
```bash
kubectl apply -f infrastructure/storage/velero/bucket-jobs/
kubectl get jobs -n rook-ceph | grep create-.*-bucket
```

### Step 3: Create S3 Credential Secrets
```bash
./infrastructure/storage/velero/create-s3-credentials.sh
kubectl get secrets -n velero | grep velero-s3-credentials
```

### Step 4: Deploy BackupStorageLocations
```bash
kubectl apply -f infrastructure/storage/velero/backup-storage-locations.yaml
kubectl get backupstoragelocations -n velero
```

### Step 5: Deploy Backup Schedules
```bash
kubectl apply -f infrastructure/storage/velero/backup-schedules.yaml
kubectl get schedules.velero.io -n velero
```

## Verification

### Check BSL Status
```bash
kubectl get backupstoragelocations -n velero
```

**Expected Output**:
```
NAME              PHASE       LAST VALIDATED   AGE   DEFAULT
cluster-backups   Available   1m               5m    true
pv-backups        Available   1m               5m    false
```

**Note**: BSLs may show "Unavailable" initially (empty bucket). They become "Available" after first backup completes.

### Check Backup Schedules
```bash
kubectl get schedules.velero.io -n velero
```

**Expected Output**:
```
NAME                     STATUS    SCHEDULE    LASTBACKUP   AGE   PAUSED
daily-cluster-backup     Enabled   0 3 * * *                25s
daily-pv-backup          Enabled   0 4 * * *                25s
hourly-critical-backup   Enabled   0 * * * *                25s
weekly-full-backup       Enabled   0 2 * * 0                23s
```

### List Backups
```bash
kubectl get backups -n velero
```

### Verify Buckets in Ceph
```bash
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- radosgw-admin bucket list
```

**Expected Output**:
```json
[
    "velero-cluster-backups",
    "velero-pv-backups",
    "n8n-prod-backups",
    "infisical-prod-backups",
    "elasticsearch-snapshots"
]
```

## Manual Operations

### Trigger Immediate Backup
```bash
# Full cluster backup
velero backup create manual-cluster-backup \
  --storage-location cluster-backups \
  --include-namespaces "*" \
  --snapshot-volumes=false

# PV backup for specific namespace
velero backup create manual-pv-backup \
  --storage-location pv-backups \
  --include-namespaces argocd \
  --default-volumes-to-fs-backup
```

### List Backups
```bash
velero backup get
```

### Describe Backup
```bash
velero backup describe <backup-name> --details
```

### Download Backup Logs
```bash
velero backup logs <backup-name>
```

### Restore from Backup
```bash
# Full cluster restore
velero restore create --from-backup <backup-name>

# Restore specific namespace
velero restore create --from-backup <backup-name> \
  --include-namespaces argocd

# Restore with namespace mapping (disaster recovery)
velero restore create --from-backup <backup-name> \
  --namespace-mappings old-namespace:new-namespace
```

### List Restores
```bash
velero restore get
```

### Describe Restore
```bash
velero restore describe <restore-name> --details
```

## Backup Retention Policies

| Schedule | Frequency | Retention | Purpose |
|----------|-----------|-----------|---------|
| **Hourly Critical** | Every hour | 7 days | Fast infrastructure recovery |
| **Daily Cluster** | Daily 3 AM | 30 days | Regular cluster resources backup |
| **Daily PV** | Daily 4 AM | 30 days | Regular volume data backup |
| **Weekly Full** | Sunday 2 AM | 90 days | Long-term disaster recovery |

## Security

### Encryption
- ✅ **Client-Side Encryption**: Restic/Kopia encrypts PV data before upload
- ✅ **At-Rest Encryption**: Ceph wire encryption (msgr2 secure mode)
- ✅ **Network Security**: Internal cluster networking (no external exposure)

### Credentials Storage
- ✅ S3 credentials stored as Kubernetes Secrets
- ✅ Credentials auto-generated by Rook (rotatable)
- ✅ Access controlled via Kubernetes RBAC

### Restic Repository Passwords
Velero automatically manages Restic repository encryption keys via the `velero-restic-credentials` Secret.

## Monitoring & Alerts

### Velero Metrics
Velero exposes Prometheus metrics on port 8085:

```yaml
metrics:
  enabled: true
  scrapeInterval: 30s
  service:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8085"
```

### Recommended Grafana Dashboard
Import official Velero dashboard: https://grafana.com/grafana/dashboards/11055

### Prometheus Alerts
```yaml
- alert: VeleroBackupFailed
  expr: velero_backup_failure_total > 0
  for: 5m
  annotations:
    summary: "Velero backup failed"

- alert: VeleroBackupStale
  expr: time() - velero_backup_last_successful_timestamp > 86400 * 2
  for: 1h
  annotations:
    summary: "No successful backup in 48 hours"
```

## Troubleshooting

### BSL Shows "Unavailable"
**Cause**: Empty bucket or S3 connection issues

**Solution**:
```bash
# Check BSL details
kubectl describe backupstoragelocation <bsl-name> -n velero

# Test S3 connectivity
kubectl exec -n velero deploy/velero -- \
  aws s3 ls s3://velero-cluster-backups \
  --endpoint-url http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80

# Verify credentials
kubectl get secret velero-s3-credentials-cluster -n velero -o yaml
```

### Backup Stuck in "InProgress"
**Cause**: Node Agent (Restic/Kopia) pod issues

**Solution**:
```bash
# Check Node Agent pods
kubectl get pods -n velero -l component=velero

# Check Node Agent logs
kubectl logs -n velero -l name=node-agent --tail=50

# Restart Node Agent
kubectl rollout restart daemonset/node-agent -n velero
```

### Restore Fails with "Partially Failed"
**Cause**: Resource conflicts or missing dependencies

**Solution**:
```bash
# Get detailed restore logs
velero restore logs <restore-name>

# Check restore warnings
velero restore describe <restore-name> --details | grep -A 10 "Warnings"

# Restore with namespace cleanup
kubectl delete namespace <namespace>
velero restore create --from-backup <backup-name>
```

### "NoSuchKey" Error in BSL
**Cause**: Bucket exists but is empty (no backups yet)

**Solution**: This is normal! BSL becomes "Available" after first successful backup.

## Performance Tuning

### Parallel Backups
```yaml
# Velero deployment configuration
spec:
  podVolumeOperationTimeout: 240m  # Increase for large volumes
  uploaderSettings:
    parallelFilesUpload: 8  # Increase for faster backups
```

### Restic Resource Limits
```yaml
# node-agent configuration
nodeAgent:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

### S3 Upload Speed
Ceph RGW bandwidth is limited by network and OSD performance. Monitor with:
```bash
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool stats
```

## Disaster Recovery Procedures

### Complete Cluster Recovery

**Scenario**: Total cluster loss, need to restore everything

**Steps**:
1. Deploy fresh Kubernetes cluster with Talos
2. Install Rook-Ceph and recreate object storage
3. Install Velero with same configuration
4. Restore credentials and BSLs
5. Restore from latest weekly-full-backup:
   ```bash
   velero restore create --from-backup weekly-full-backup-<date>
   ```

### Namespace Recovery
```bash
# Delete namespace
kubectl delete namespace <namespace>

# Restore specific namespace
velero restore create --from-backup <backup-name> \
  --include-namespaces <namespace>
```

### PVC Recovery
```bash
# Restore specific PVC
velero restore create --from-backup <backup-name> \
  --include-resources persistentvolumeclaims \
  --selector app=<app-label>
```

## Maintenance

### Cleanup Old Jobs
```bash
# Delete completed bucket creation jobs
kubectl delete job -n rook-ceph create-velero-cluster-backups-bucket
kubectl delete job -n rook-ceph create-velero-pv-backups-bucket
kubectl delete job -n rook-ceph create-n8n-prod-backups-bucket
kubectl delete job -n rook-ceph create-infisical-prod-backups-bucket
```

### Backup Deletion
Old backups are automatically deleted based on TTL in Schedule spec. Manual deletion:
```bash
velero backup delete <backup-name>
```

### Pause/Resume Schedules
```bash
# Pause schedule
velero schedule pause <schedule-name>

# Resume schedule
velero schedule unpause <schedule-name>
```

## Best Practices

1. **Test Restores Regularly**: Schedule quarterly restore drills to verify backups
2. **Monitor BSL Status**: Set up alerts for BSL "Unavailable" status
3. **Separate Cluster and PV Backups**: Different retention policies for resources vs data
4. **Use Namespace Selectors**: Backup critical namespaces hourly
5. **Enable Encryption**: Always use Restic/Kopia for PV backups (client-side encryption)
6. **Document Restore Procedures**: Keep runbook updated with restore commands
7. **Monitor Storage Growth**: Track S3 bucket size growth in Grafana

## Success Metrics

- ✅ **4 S3 Buckets** properly created and persisting in Ceph
- ✅ **2 BackupStorageLocations** configured (cluster + PV)
- ✅ **4 Backup Schedules** enabled and running
- ✅ **Zone/Realm/Period** configured for RGW metadata persistence
- ✅ **Restic/Kopia** enabled for encrypted PV backups
- ✅ **30-Day Retention** for daily backups
- ✅ **90-Day Retention** for weekly full backups
- ✅ **GitOps Managed** via ArgoCD Infrastructure as Code

## Related Documentation

- [Velero Official Docs](https://velero.io/docs/)
- [Velero AWS Plugin](https://github.com/vmware-tanzu/velero-plugin-for-aws)
- [Restic Integration](https://velero.io/docs/main/file-system-backup/)
- [Ceph RGW S3 API](https://docs.ceph.com/en/latest/radosgw/s3/)
- [Rook-Ceph Object Storage](https://rook.io/docs/rook/latest/Storage-Configuration/Object-Storage-RGW/object-storage/)

## Files Reference

**Core Configuration:**
- `kustomization.yaml` - Velero Helm chart with plugins
- `backup-storage-locations.yaml` - BSL definitions
- `backup-schedules.yaml` - Automated backup schedules

**Ceph Integration:**
- `ceph-users/` - CephObjectStoreUser definitions
- `bucket-jobs/` - S3 bucket creation Jobs
- `create-s3-credentials.sh` - Credential extraction script

**Secrets:**
- `sealed-secret-s3.yaml` - S3 credentials (sealed)
- `velero-restic-credentials-sealedsecret.yaml` - Restic encryption key

**Patches:**
- `patches/upgrade-job-initcontainer-resources.yaml` - CRD upgrade Job resource limits
