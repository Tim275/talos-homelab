# Elasticsearch S3 Snapshots - Ceph RGW Backup

## 📦 Overview

Automated Elasticsearch snapshot backups using Ceph RGW S3-compatible storage.

```
┌─────────────────────────────────────────────────────────────┐
│ BACKUP ARCHITECTURE                                         │
└─────────────────────────────────────────────────────────────┘

Primary Data (Live):
  📊 Elasticsearch Cluster (3 nodes)
  └─ Storage: rook-ceph-block-enterprise (SSD)

Snapshot Backups:
  💾 Ceph RGW S3 Bucket
  ├─ Bucket: elasticsearch-snapshots-*
  ├─ Endpoint: rook-ceph-rgw-homelab-objectstore
  ├─ Replication: 3x (Ceph pool)
  └─ Schedule: Daily @ 2:00 AM UTC

Retention:
  📅 30 days automatic deletion
  🔢 Min: 5 snapshots
  🔢 Max: 50 snapshots
```

## 🚀 Deployment Order

```yaml
# 1. S3 Bucket (auto-creates credentials)
kubectl apply -f bucket.yaml

# 2. Extract credentials → Create ECK SecureSettings Secret
kubectl apply -f create-s3-credentials-job.yaml
kubectl wait --for=condition=complete job/elasticsearch-s3-credentials-setup -n elastic-system --timeout=300s

# 3. Restart Elasticsearch to load new keystore
kubectl rollout restart statefulset/production-cluster-es-master-data -n elastic-system
kubectl rollout status statefulset/production-cluster-es-master-data -n elastic-system --timeout=600s

# 4. Register S3 snapshot repository
kubectl apply -f register-repository-job.yaml
kubectl wait --for=condition=complete job/elasticsearch-register-snapshot-repo -n elastic-system --timeout=300s

# 5. Configure automated daily snapshots
kubectl apply -f slm-policy-job.yaml
kubectl wait --for=condition=complete job/elasticsearch-configure-slm-policy -n elastic-system --timeout=300s
```

## 🔍 Verify Snapshot Setup

### Check S3 Bucket
```bash
kubectl get objectbucketclaim elasticsearch-snapshots -n elastic-system
kubectl get configmap elasticsearch-snapshots -n elastic-system -o yaml
```

### Check Snapshot Repository
```bash
ELASTIC_PASSWORD=$(kubectl get secret production-cluster-es-elastic-user -n elastic-system -o jsonpath='{.data.elastic}' | base64 -d)

kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots?pretty"
```

### Check SLM Policy
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/policy/daily-snapshots?pretty"
```

### List All Snapshots
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/_all?pretty"
```

## 📋 Manual Operations

### Trigger Manual Snapshot
```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X POST -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/policy/daily-snapshots/_execute"
```

### Restore from Snapshot
```bash
# 1. List snapshots
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/_all?pretty"

# 2. Restore specific snapshot
SNAPSHOT_NAME="daily-snap-2025.10.20"

kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X POST -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/${SNAPSHOT_NAME}/_restore" \
  -d '{
    "indices": "logs-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

### Delete Old Snapshot
```bash
SNAPSHOT_NAME="daily-snap-2025.09.20"

kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -X DELETE -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_snapshot/ceph-s3-snapshots/${SNAPSHOT_NAME}"
```

## 🔧 Troubleshooting

### Job Failed: ObjectBucketClaim not ready
```bash
# Check OBC status
kubectl describe objectbucketclaim elasticsearch-snapshots -n elastic-system

# Check Rook-Ceph RGW
kubectl get pods -n rook-ceph -l app=rook-ceph-rgw
```

### Snapshot Repository Registration Failed
```bash
# Check Elasticsearch logs
kubectl logs -n elastic-system production-cluster-es-master-data-0

# Verify S3 credentials in keystore
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  bin/elasticsearch-keystore list
```

### Snapshots Not Running
```bash
# Check SLM status
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/status?pretty"

# Check SLM execution history
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_slm/policy/daily-snapshots?pretty" | grep -A 10 last_success
```

## 📊 Monitoring

### Prometheus Metrics
```promql
# Snapshot success rate
elasticsearch_slm_snapshot_success_total

# Snapshot size
elasticsearch_snapshot_stats_size_in_bytes

# Last snapshot age
time() - elasticsearch_snapshot_stats_timestamp_seconds
```

### Kibana Dev Console
```
# List all snapshots
GET _snapshot/ceph-s3-snapshots/_all

# Check SLM policy
GET _slm/policy/daily-snapshots

# Execute policy manually
POST _slm/policy/daily-snapshots/_execute
```

## 🎯 Best Practices

✅ **Retention**: 30 days (adjustable via SLM policy)
✅ **Schedule**: Daily @ 2:00 AM UTC (low traffic time)
✅ **Compression**: Enabled (saves S3 storage)
✅ **Incremental**: Only changed data is backed up
✅ **Verification**: Auto-verify on repository registration

## 📚 References

- [ECK Snapshots Guide](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-snapshots.html)
- [Elasticsearch Snapshot API](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html)
- [SLM Policy Reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-lifecycle-management.html)
- [Ceph RGW S3 Compatibility](https://docs.ceph.com/en/latest/radosgw/s3/)

---

**Created:** 2025-10-20
**Author:** Claude + Tim275
**Cluster:** Talos Homelab
**Storage:** Rook Ceph RGW
