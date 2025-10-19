# Elasticsearch S3 Snapshot Backup System

## Overview

Enterprise-grade automated backup solution for Elasticsearch cluster using Rook Ceph S3-compatible object storage.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Elasticsearch Cluster (3 Nodes)                    │
│ ✅ S3 Credentials in Keystore                       │
│ ✅ SLM Policy: daily-snapshots                      │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ S3 API (HTTP)
                   ▼
┌─────────────────────────────────────────────────────┐
│ Rook Ceph RGW (S3-compatible Object Storage)       │
│ ✅ Bucket: elasticsearch-snapshots-5a264d68...      │
│ ✅ Endpoint: rook-ceph-rgw-homelab-objectstore      │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ RBD (RADOS Block Device)
                   ▼
┌─────────────────────────────────────────────────────┐
│ Ceph Storage Cluster (6 OSDs)                      │
│ ✅ 3x Replication                                   │
│ ✅ Enterprise-grade Reliability                     │
└─────────────────────────────────────────────────────┘
```

## Components

### 1. S3 Bucket Provisioning
**File**: `bucket.yaml`

- **ObjectBucketClaim** dynamically provisions S3 bucket via Rook Ceph
- Auto-generates access credentials and endpoint configuration
- Storage class: `rook-ceph-bucket`

### 2. Credentials Setup Job
**File**: `create-s3-credentials-job.yaml`

**Purpose**: Extract S3 credentials from OBC and create ECK SecureSettings Secret

**Process**:
1. Waits for ObjectBucketClaim to reach `phase=Bound` status
2. Extracts S3 credentials from auto-generated secret
3. Creates ECK-compatible SecureSettings Secret for Elasticsearch keystore
4. Creates ConfigMap with S3 endpoint information

**Output Secrets**:
- `elasticsearch-s3-credentials`: ECK SecureSettings with `s3.client.default.access_key` and `s3.client.default.secret_key`
- `elasticsearch-s3-config`: ConfigMap with S3 endpoint and bucket name

### 3. Repository Registration Job
**File**: `register-repository-job.yaml`

**Purpose**: Register S3 snapshot repository in Elasticsearch via API

**Configuration**:
```json
{
  "type": "s3",
  "settings": {
    "bucket": "elasticsearch-snapshots-...",
    "client": "default",
    "endpoint": "http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc",
    "protocol": "http",
    "path_style_access": true,
    "compress": true,
    "max_snapshot_bytes_per_sec": "100mb",
    "max_restore_bytes_per_sec": "100mb"
  }
}
```

**Key Features**:
- Waits for Elasticsearch cluster health (GREEN or YELLOW)
- Registers repository named `ceph-s3-snapshots`
- Verifies repository connectivity
- Path-style S3 access (required for Ceph RGW)

### 4. SLM Policy Configuration Job
**File**: `slm-policy-job.yaml`

**Purpose**: Configure automated daily snapshots with retention policy

**Schedule**: `0 0 2 * * ?` (Quartz Cron: Daily at 2:00 AM UTC)

**Policy Configuration**:
```json
{
  "schedule": "0 0 2 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "ceph-s3-snapshots",
  "config": {
    "indices": ["logs-*"],
    "ignore_unavailable": true,
    "include_global_state": false
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 5,
    "max_count": 50
  }
}
```

**Features**:
- Automatic daily execution at 2 AM UTC
- Backs up all `logs-*` data streams
- Retains snapshots for 30 days
- Keeps minimum 5 snapshots (even if older than 30 days)
- Caps at maximum 50 snapshots

## Deployment

### Prerequisites
1. Rook Ceph cluster with CephObjectStore deployed
2. StorageClass `rook-ceph-bucket` available
3. Elasticsearch cluster running in `elastic-system` namespace

### Deployment Order (via Kustomize)
```yaml
resources:
  - bucket.yaml                      # 1. Provision S3 bucket
  - create-s3-credentials-job.yaml   # 2. Extract credentials
  - register-repository-job.yaml     # 3. Register repository
  - slm-policy-job.yaml              # 4. Configure SLM
```

### Manual Deployment
```bash
# Deploy all components
kubectl apply -k infrastructure/observability/elasticsearch/snapshots/

# Monitor job completion
kubectl get jobs -n elastic-system -l app.kubernetes.io/component=backup -w

# Check snapshot status
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/_all?pretty"
```

## Verification

### Check SLM Policy Status
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/policy/daily-snapshots?pretty"
```

**Expected Output**:
```json
{
  "daily-snapshots": {
    "version": 1,
    "policy": {
      "name": "<daily-snap-{now/d}>",
      "schedule": "0 0 2 * * ?",
      "repository": "ceph-s3-snapshots"
    },
    "next_execution": "2025-10-20T02:00:00.000Z",
    "stats": {
      "snapshots_taken": 1,
      "snapshots_failed": 0,
      "snapshots_deleted": 0
    }
  }
}
```

### Check Snapshot Repository
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots?pretty"
```

### List All Snapshots
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/_all?pretty"
```

## Snapshot Statistics

**Example Snapshot**:
```json
{
  "snapshot": "daily-snap-2025.10.19-naexhlf4tgglcamg65orqw",
  "state": "SUCCESS",
  "indices": 113,
  "data_streams": 113,
  "shards": {
    "total": 113,
    "failed": 0,
    "successful": 113
  },
  "start_time": "2025-10-19T23:33:31.287Z",
  "end_time": "2025-10-19T23:35:42.123Z",
  "duration_in_millis": 130836,
  "failures": []
}
```

## Manual Operations

### Trigger Immediate Snapshot
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X POST -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/policy/daily-snapshots/_execute"
```

### Restore from Snapshot
```bash
# List snapshots
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/_all?pretty"

# Restore specific snapshot
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X POST -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/daily-snap-YYYY.MM.DD-xxx/_restore" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "logs-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

### Delete Snapshot
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X DELETE -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/daily-snap-YYYY.MM.DD-xxx"
```

## Troubleshooting

### Jobs Not Completing

**Issue**: Jobs stuck in pending or failed state

**Solution**:
```bash
# Check job logs
kubectl logs -n elastic-system job/elasticsearch-s3-credentials-setup

# Verify OBC is bound
kubectl get objectbucketclaim elasticsearch-snapshots -n elastic-system

# Check Elasticsearch cluster health
kubectl get elasticsearch -n elastic-system
```

### Repository Registration Fails

**Issue**: S3 connection timeout or authentication errors

**Checklist**:
1. Verify Elasticsearch pods have S3 credentials in keystore (requires pod restart)
2. Check RGW service is accessible: `kubectl get svc -n rook-ceph rook-ceph-rgw-homelab-objectstore`
3. Verify endpoint format (no double `http://` prefix)
4. Test network connectivity from Elasticsearch pod:
   ```bash
   kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
     curl -v http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc
   ```

### SLM Policy Cron Error

**Issue**: `invalid schedule [0 2 * * *]: must be a valid cron expression`

**Cause**: Elasticsearch uses Quartz Cron format (includes seconds field)

**Solution**: Use 6-field cron: `0 0 2 * * ?` instead of `0 2 * * *`

**Quartz Cron Format**:
```
┌───────────── second (0-59)
│ ┌───────────── minute (0-59)
│ │ ┌───────────── hour (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12)
│ │ │ │ │ ┌───────────── day of week (0-6 or SUN-SAT)
│ │ │ │ │ │
0 0 2 * * ?  = Daily at 2:00 AM UTC
```

### ArgoCD Job Immutability

**Issue**: `Job.batch is invalid: spec.template: Invalid value: ... field is immutable`

**Cause**: Kubernetes Jobs cannot be updated in-place

**Solution**:
```bash
# Delete job manually
kubectl delete job elasticsearch-configure-slm-policy -n elastic-system

# Trigger ArgoCD sync to recreate
kubectl patch application elasticsearch -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## Security Considerations

### Credentials Storage
- S3 credentials stored in Elasticsearch keystore (encrypted at rest)
- Credentials automatically rotated via ObjectBucketClaim lifecycle
- Access restricted via Kubernetes RBAC

### Network Security
- S3 traffic uses internal cluster networking (no external exposure)
- HTTP protocol acceptable (traffic never leaves cluster network)
- For production: Consider enabling TLS on RGW for defense-in-depth

### Backup Encryption
- Snapshots compressed in transit (reduces storage and bandwidth)
- Ceph encryption at rest available (configure on CephCluster level)
- Consider Elasticsearch snapshot encryption for compliance (requires license)

## Performance Tuning

### Snapshot Speed
```yaml
settings:
  max_snapshot_bytes_per_sec: "100mb"  # Increase for faster backups
  max_restore_bytes_per_sec: "100mb"   # Increase for faster restores
```

### Compression
```yaml
settings:
  compress: true  # Reduces storage usage (~50% reduction typical)
```

### Parallel Snapshots
- SLM automatically manages concurrent snapshots
- Multiple indices snapshotted in parallel (based on shard count)
- Monitor Elasticsearch thread pool: `snapshot` threads

## Monitoring

### Grafana Dashboard Queries

**Snapshot Success Rate**:
```promql
rate(elasticsearch_slm_stats_snapshots_taken_total[5m]) /
rate(elasticsearch_slm_stats_snapshots_failed_total[5m])
```

**Snapshot Duration**:
```promql
elasticsearch_snapshot_duration_seconds
```

**Storage Usage**:
```promql
ceph_pool_bytes_used{pool="default.rgw.buckets.data"}
```

### Alerts

**Recommended AlertManager Rules**:
```yaml
- alert: ElasticsearchSnapshotFailed
  expr: elasticsearch_slm_stats_snapshots_failed_total > 0
  for: 5m
  annotations:
    summary: "Elasticsearch snapshot failed"

- alert: ElasticsearchSnapshotStale
  expr: time() - elasticsearch_slm_last_success_timestamp > 86400 * 2
  for: 1h
  annotations:
    summary: "No successful snapshot in 48 hours"
```

## Backup Best Practices

1. **Test Restores Regularly**: Schedule quarterly restore drills
2. **Monitor Storage Growth**: Set up alerts for bucket size
3. **Verify Snapshot Integrity**: Check `failures` field in snapshot status
4. **Document Restore Procedures**: Keep runbook updated
5. **Off-Cluster Replication**: Consider Velero for cluster-level backup redundancy

## Related Documentation

- [Elasticsearch Snapshot and Restore](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html)
- [Elasticsearch SLM API](https://www.elastic.co/guide/en/elasticsearch/reference/current/slm-api.html)
- [Rook Ceph Object Storage](https://rook.io/docs/rook/latest/Storage-Configuration/Object-Storage-RGW/object-storage/)
- [ECK Secure Settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-es-secure-settings.html)

## Maintenance

### Cleanup Old Jobs
Jobs auto-cleanup via `ttlSecondsAfterFinished: 600` (10 minutes after completion)

### Manual Cleanup
```bash
# Delete all completed snapshot jobs
kubectl delete jobs -n elastic-system -l app.kubernetes.io/component=backup \
  --field-selector status.successful=1
```

## Success Metrics

- ✅ **113 Data Streams** backed up
- ✅ **0 Failures** in snapshot process
- ✅ **Daily Automated** backups at 2 AM UTC
- ✅ **30-Day Retention** with min/max bounds
- ✅ **S3-Compatible** storage on enterprise Ceph cluster
- ✅ **GitOps Managed** via ArgoCD Infrastructure as Code
