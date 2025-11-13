# Velero CSI Backup - Complete Setup Guide

## Overview

Enterprise-grade backup solution for Kubernetes using Velero with CSI volume snapshots backed by Rook Ceph storage.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VELERO BACKUP FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Backup Request → Velero Controller                      │
│  2. Kubernetes Resources → S3 (Ceph RGW)                    │
│  3. PVC Detection → CSI Snapshot Creation                   │
│  4. Volume Snapshots → Ceph RBD Pool                        │
│  5. Snapshot Metadata → S3 (Ceph RGW)                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Components Deployed

### 1. CSI Snapshot Infrastructure
**Location:** `kubernetes/infrastructure/storage/csi-drivers/`

- **VolumeSnapshot CRDs** (v8.2.0)
  - `volumesnapshotclasses.snapshot.storage.k8s.io`
  - `volumesnapshotcontents.snapshot.storage.k8s.io`
  - `volumesnapshots.snapshot.storage.k8s.io`

- **Snapshot Controller** (v8.2.1)
  - Cluster-wide controller for ALL CSI drivers
  - Kyverno-compliant resource limits
  - High availability: 2 replicas

- **VolumeSnapshotClasses**
  - `csi-rbdplugin-snapclass` - Rook Ceph RBD (block storage)
  - `csi-cephfs-snapclass` - Rook Ceph CephFS (filesystem)

### 2. Velero Deployment
**Location:** `kubernetes/infrastructure/storage/velero/`

**Helm Chart:** vmware-tanzu/velero v10.1.3
**Velero Version:** v1.14.1

**Key Configuration:**
```yaml
configuration:
  features: "EnableCSI"  # ⚠️ CRITICAL: Must be under configuration!
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero-backups
      config:
        s3Url: http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
        s3ForcePathStyle: "true"
        serverSideEncryption: ""  # Disabled for Ceph RGW compatibility
  volumeSnapshotLocation:
    - name: default
      provider: csi
      config: {}  # Empty - CSI driver handles snapshot creation
```

## Setup History & Troubleshooting

### Problem 1: EnableCSI Flag Not Working ❌ → ✅ SOLVED

**Symptom:**
- Velero backups completed but NO volume snapshots created
- Logs showed: "no applicable volumesnapshotter found"

**Root Cause:**
Helm chart expects `features:` under `configuration:` section, not at top-level.

**Solution:**
```yaml
# ❌ WRONG (top-level)
valuesInline:
  features: "EnableCSI"
  configuration:
    defaultBackupTTL: 168h

# ✅ CORRECT (under configuration)
valuesInline:
  configuration:
    features: "EnableCSI"
    defaultBackupTTL: 168h
```

**File:** `kustomization.yaml:30`

### Problem 2: S3 Server-Side Encryption Conflict ❌ → ✅ SOLVED

**Symptom:**
```
Error: algorithm <AES256> but got sse-kms attributes
```

**Root Cause:**
Ceph RGW's SSE-AES256 implementation conflicts with Velero's AWS S3 plugin expectations.

**Solution:**
```yaml
backupStorageLocation:
  config:
    serverSideEncryption: ""  # Disable SSE
```

**Note:** Data still encrypted at-rest by Ceph itself.

### Problem 3: VolumeSnapshot CRDs Missing ❌ → ✅ SOLVED

**Symptom:**
- CSI snapshots not created
- No VolumeSnapshotClasses available

**Root Cause:**
VolumeSnapshot CRDs were accidentally removed during infrastructure refactoring.

**Solution:**
Created complete CSI infrastructure in `csi-drivers/`:
- Deployed CRDs from kubernetes-csi/external-snapshotter v8.2.0
- Deployed snapshot-controller with resource limits (Kyverno compliance)
- Created VolumeSnapshotClasses for Rook Ceph

## Backup Workflow

### Manual Backup Example

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: n8n-prod-backup
  namespace: velero
  annotations:
    velero.io/csi-volumesnapshot-class_rook-ceph.rbd.csi.ceph.com: csi-rbdplugin-snapclass
spec:
  includedNamespaces:
    - n8n-prod
  snapshotVolumes: true
  defaultVolumesToFsBackup: false  # Use CSI snapshots, not file-level backup
  ttl: 168h
  storageLocation: default
  volumeSnapshotLocations:
    - default
  hooks:
    resources:
      - name: postgres-backup-hook
        includedNamespaces:
          - n8n-prod
        labelSelector:
          matchLabels:
            cnpg.io/cluster: n8n-postgres
        pre:
          - exec:
              container: postgres
              command: ["/bin/bash", "-c", "psql -U postgres -c 'CHECKPOINT;'"]
              onError: Continue
              timeout: 30s
```

**Execute:**
```bash
kubectl apply -f backup.yaml
```

### Automated Backup Schedules

**Location:** `backup-schedule.yaml`

**Tier-0 (Critical Databases):**
- **Frequency:** Every 24 hours
- **Retention:** 7 days
- **Namespaces:** n8n-prod, postgresql-prod

**Tier-1 (Stateful Apps):**
- **Frequency:** Daily at 2 AM
- **Retention:** 7 days

**Tier-2 (Platform Services):**
- **Frequency:** Weekly (Sunday 3 AM)
- **Retention:** 30 days

**Tier-3 (Full Cluster):**
- **Frequency:** Monthly (1st day, 4 AM)
- **Retention:** 90 days

**Tier-4 (Config Only):**
- **Frequency:** Every 4 hours
- **Retention:** 48 hours
- **Note:** Excludes volumes (manifests only)

## Verification Commands

### 1. Check Velero Status
```bash
kubectl get deployment velero -n velero
kubectl logs -n velero -l app.kubernetes.io/name=velero --tail=50
```

### 2. Verify EnableCSI Flag
```bash
kubectl get pod -n velero -l app.kubernetes.io/name=velero \
  -o jsonpath='{.items[0].spec.containers[0].args}' | jq -r '.[]'
# Should include: --features=EnableCSI
```

### 3. List Backups
```bash
kubectl get backups.velero.io -n velero
kubectl describe backup <backup-name> -n velero
```

### 4. Check Volume Snapshots
```bash
kubectl get volumesnapshotcontents -A
kubectl get volumesnapshots -A
```

### 5. S3 Backup Contents
```bash
# Run helper script
./s3-ls.sh <backup-name>
```

**Expected Files:**
- `<backup>-csi-volumesnapshots.json.gz` - Snapshot references (>1 KB = snapshots exist!)
- `<backup>-csi-volumesnapshotcontents.json.gz` - Snapshot metadata
- `<backup>.tar.gz` - Kubernetes manifests
- `velero-backup.json` - Backup descriptor

## Restore Workflow

### Full Namespace Restore
```bash
velero restore create --from-backup n8n-prod-backup
```

### Selective Restore
```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: n8n-postgres-restore
  namespace: velero
spec:
  backupName: n8n-prod-backup
  includedNamespaces:
    - n8n-prod
  includedResources:
    - persistentvolumeclaims
    - persistentvolumes
  restorePVs: true
```

### Restore to Different Namespace
```yaml
spec:
  backupName: n8n-prod-backup
  namespaceMapping:
    n8n-prod: n8n-staging
```

## Monitoring & Alerts

### Prometheus Metrics
**Endpoint:** `http://velero.velero.svc:8085/metrics`

**Key Metrics:**
- `velero_backup_success_total` - Successful backups
- `velero_backup_failure_total` - Failed backups
- `velero_backup_duration_seconds` - Backup duration
- `velero_volume_snapshot_success_total` - CSI snapshots created

### AlertManager Rules
**Location:** `kubernetes/infrastructure/monitoring/alerts/`

**Critical Alerts:**
- Backup failed
- No backups in last 48 hours
- Volume snapshot creation failed

## Storage Backend (Ceph RGW)

### S3 Configuration
- **Endpoint:** `http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80`
- **Bucket:** `velero-backups` (auto-created via ObjectBucketClaim)
- **Credentials:** SealedSecret `velero-s3-credentials`

### Bucket Management
```bash
# List buckets
kubectl get objectbucketclaims -n velero

# Get S3 credentials
kubectl get secret velero-s3-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d
```

## Disaster Recovery Scenarios

### Scenario 1: Single PVC Recovery
1. Identify backup: `kubectl get backups.velero.io -n velero`
2. Create restore with PVC filter
3. Verify snapshot restore: `kubectl get pvc -n <namespace>`

### Scenario 2: Full Namespace Recovery
1. Delete namespace (if corrupted): `kubectl delete ns <namespace>`
2. Restore backup: `velero restore create --from-backup <backup>`
3. Monitor: `velero restore describe <restore-name>`

### Scenario 3: Cluster Migration
1. Install Velero on new cluster (same S3 bucket)
2. List available backups: `velero backup get`
3. Restore selected namespaces
4. Update DNS/Ingress for new cluster

## Best Practices

### 1. Backup Hooks
Always use pre-backup hooks for databases:
```yaml
hooks:
  resources:
    - name: db-checkpoint
      pre:
        - exec:
            container: postgres
            command: ["pg_checkpoint"]
```

### 2. Retention Policies
- **Critical Data (Tier-0):** 7 days minimum
- **Compliance:** 90+ days for audit requirements
- **Dev/Test:** 24-48 hours sufficient

### 3. Testing Restores
**Monthly drill:** Restore to staging environment to verify backups work.

### 4. Snapshot Deletion Policy
Use `Retain` for production:
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-rbdplugin-snapclass
deletionPolicy: Retain  # Snapshots survive backup deletion
```

## Troubleshooting Guide

### Backup Shows "Completed" but No Snapshots

**Check:**
```bash
# 1. Verify EnableCSI flag
kubectl get pod -n velero -l app.kubernetes.io/name=velero \
  -o jsonpath='{.items[0].spec.containers[0].args}' | grep features

# 2. Check VolumeSnapshotClass exists
kubectl get volumesnapshotclasses

# 3. Verify CSI driver
kubectl get csidrivers | grep ceph
```

### S3 Upload Failures

**Check:**
```bash
# 1. Verify bucket exists
kubectl get objectbucketclaim velero-backups -n velero

# 2. Test S3 connectivity
kubectl run aws-cli --rm -it --image=amazon/aws-cli -- \
  s3 ls --endpoint-url http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
```

### VolumeSnapshot Not ReadyToUse

**Check:**
```bash
# 1. Describe VolumeSnapshotContent
kubectl describe volumesnapshotcontent <name>

# 2. Check Ceph RBD snapshots
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  rbd snap ls replicapool/<volume-name>
```

## Additional Resources

- **Velero Docs:** https://velero.io/docs/v1.14/
- **CSI Snapshot Docs:** https://kubernetes-csi.github.io/docs/snapshot-controller.html
- **Rook Ceph Backup:** https://rook.io/docs/rook/latest/Storage-Configuration/Ceph-CSI/ceph-csi-snapshot/

## Support & Maintenance

**Maintainer:** Homelab Infrastructure Team
**Last Updated:** 2025-10-05
**Velero Version:** v1.14.1
**CSI Snapshot Controller:** v8.2.1
