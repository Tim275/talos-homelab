# Loki Best Practices Guide - Log Aggregation

## Current State Analysis

### Deployment Configuration

**Deployment Mode:** SingleBinary
**Loki Version:** v3.1.1
**Chart:** grafana/loki (Helm)
**Namespace:** monitoring
**Replicas:** 1 (single instance)

### Storage Configuration

**Backend:** Filesystem (local disk)
**Storage Class:** rook-ceph-block-enterprise
**PVC Size:** 10Gi
**Schema:** v13 (TSDB - modern standard)
**Schema Start:** 2024-01-01

```yaml
loki:
  storage:
    type: "filesystem"  # ❌ NOT production-ready
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb          # ✅ Modern TSDB index
        schema: v13          # ✅ Latest schema
        object_store: filesystem  # ❌ Should be S3
```

**Status:** Schema is correct, but storage backend needs migration

### Resource Configuration

```yaml
singleBinary:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

gateway:  # nginx proxy
  resources:
    requests:
      cpu: 25m
      memory: 32Mi
    limits:
      cpu: 250m
      memory: 256Mi
```

**Status:** Good for homelab (<100GB/day logs)

### Cache Configuration

```yaml
chunksCache:
  allocatedMemory: 500   # 500MB for chunk cache
resultsCache:
  allocatedMemory: 200   # 200MB for query results
```

**Status:** Adequate for homelab workload

### Authentication & Security

**Current:** auth_enabled: false
**Status:** ❌ NOT production-ready (no multi-tenancy)

---

## Best Practices Assessment

### 1. Deployment Modes

**Current:** SingleBinary (monolithic)
**Status:** Good for homelab, NOT production-ready

**Loki Deployment Modes Comparison:**

#### A. SingleBinary (Monolithic) - Current

**Architecture:**
```
┌─────────────────────────────┐
│   Loki SingleBinary Pod     │
│  ┌──────────────────────┐  │
│  │  Distributor         │  │  ← Receives logs
│  │  Ingester            │  │  ← Writes chunks
│  │  Querier             │  │  ← Queries logs
│  │  Query Frontend      │  │  ← Cache queries
│  │  Compactor           │  │  ← Cleanup old data
│  └──────────────────────┘  │
└─────────────────────────────┘
```

**Pros:**
- ✅ Simplest deployment (1 pod)
- ✅ Lowest resource usage (~1GB RAM)
- ✅ No coordination overhead

**Cons:**
- ❌ Single point of failure
- ❌ Cannot scale horizontally
- ❌ No HA (downtime during pod restart)

**Use Cases:**
- Homelabs (<50GB/day)
- Development environments
- Testing/evaluation

#### B. Simple Scalable (Recommended for Production)

**Architecture:**
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Write      │  │    Read      │  │   Backend    │
│ (Distributor)│  │  (Querier)   │  │ (Compactor)  │
│ (Ingester)   │  │ (QueryFront) │  │              │
│              │  │              │  │              │
│  Replicas: 3 │  │  Replicas: 2 │  │  Replicas: 1 │
└──────────────┘  └──────────────┘  └──────────────┘
```

**Pros:**
- ✅ High availability (3 write replicas)
- ✅ Horizontal scaling (add more read pods)
- ✅ Separate read/write resources
- ✅ Production-ready

**Cons:**
- ⚠️ More complex (3 StatefulSets)
- ⚠️ Higher resource usage (~4GB RAM total)

**Use Cases:**
- Production (<500GB/day)
- Scale-ups (10-100 users)
- Mission-critical logging

#### C. Microservices (Enterprise)

**Architecture:**
```
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│Distributor│ │ Ingester │ │ Querier  │ │Compactor │
│ (3 pods) │ │ (3 pods) │ │ (2 pods) │ │ (1 pod)  │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
     │             │             │             │
     └─────────────┴─────────────┴─────────────┘
               Shared Object Storage (S3)
```

**Pros:**
- ✅ Maximum scalability (>1TB/day)
- ✅ Independent component scaling
- ✅ Enterprise HA (multi-AZ)

**Cons:**
- ❌ Most complex (8+ deployments)
- ❌ Highest resource usage (>10GB RAM)
- ❌ Requires object storage (S3/MinIO)

**Use Cases:**
- Enterprise (>500GB/day)
- Multi-tenant SaaS
- Global deployments

**Recommendation for Homelab:**

**Current:** Keep SingleBinary for now
**Next Step:** Migrate to Simple Scalable when:
- Log volume exceeds 50GB/day
- Uptime becomes critical (SLA >99%)
- Multiple users need log access

### 2. Storage Backend

**Current:** Filesystem (local disk)
**Status:** ❌ NOT production-ready

**Storage Backend Comparison:**

| Backend | HA | Cost | Performance | Use Case |
|---------|-----|------|-------------|----------|
| **Filesystem** | ❌ | Free | Fast | Development/testing |
| **S3/MinIO** | ✅ | Low | Good | Production (recommended) |
| **Ceph RGW** | ✅ | Free (self-hosted) | Good | Homelab with Ceph |
| **GCS/Azure** | ✅ | Medium | Excellent | Cloud deployments |

**Why Filesystem is NOT Production-Ready:**

1. **No HA:** Logs lost if pod/node fails
2. **No Scalability:** Cannot add more ingesters (shared PVC required)
3. **No Retention:** Manual cleanup required
4. **No Backup:** Logs gone if PVC deleted

**Recommended Migration: Ceph RGW S3**

**Why Ceph RGW:**
- ✅ You already have Rook Ceph deployed
- ✅ Free (self-hosted object storage)
- ✅ S3-compatible API (works with Loki)
- ✅ Same infrastructure as Velero backups

**Migration Configuration:**

```yaml
# kubernetes/infrastructure/monitoring/loki/values.yaml
loki:
  auth_enabled: false
  storage:
    type: s3  # Changed from filesystem
    bucketNames:
      chunks: loki-chunks
      ruler: loki-ruler
    s3:
      endpoint: rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
      region: eu-west-1  # Berlin (arbitrary for Ceph)
      s3ForcePathStyle: true
      insecure: true  # Internal traffic
      accessKeyId: ${LOKI_S3_ACCESS_KEY}
      secretAccessKey: ${LOKI_S3_SECRET_KEY}

  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: s3  # Changed from filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

# Credentials from Secret
extraEnvFrom:
  - secretRef:
      name: loki-s3-credentials  # SealedSecret with Ceph RGW keys
```

**S3 Bucket Creation:**

```bash
# Create Ceph RGW S3 user for Loki
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin user create --uid=loki --display-name="Loki Logs" \
  --access-key=<ACCESS_KEY> --secret-key=<SECRET_KEY>

# Create S3 buckets
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  s3cmd mb s3://loki-chunks
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  s3cmd mb s3://loki-ruler
```

**Migration Steps:**

1. **Phase 1:** Deploy new Loki with S3 backend (parallel to old)
2. **Phase 2:** Switch log collectors (Promtail/Vector) to new Loki
3. **Phase 3:** Run both for 7 days (old logs still searchable)
4. **Phase 4:** Decommission filesystem-based Loki

**Benefits:**
- ✅ No data loss (old logs preserved during migration)
- ✅ Rollback possible (switch log collectors back)
- ✅ Zero downtime

### 3. Retention Policy

**Current:** No retention configured
**Status:** ❌ Logs will fill disk

**Problem:** 10Gi PVC will fill up eventually

**Recommended Configuration:**

```yaml
loki:
  limits_config:
    retention_period: 30d  # Keep logs for 30 days

  compactor:
    retention_enabled: true
    retention_delete_delay: 2h
    retention_delete_worker_count: 150
    working_directory: /tmp/loki/compactor
```

**Homelab Retention Recommendations:**

| Log Type | Retention | Reason |
|----------|-----------|--------|
| **Tier 0 (Control Plane)** | 90 days | Compliance, incident investigation |
| **Tier 1 (Infrastructure)** | 60 days | Troubleshooting, capacity planning |
| **Tier 2 (Storage)** | 30 days | Performance tuning |
| **Tier 3 (Applications)** | 14 days | Debug, development |

**Per-Stream Retention (Advanced):**

```yaml
loki:
  limits_config:
    retention_period: 30d  # Default for all streams
    retention_stream:
      - selector: '{namespace="kube-system"}'
        priority: 1
        period: 90d  # Control plane logs kept longer
      - selector: '{namespace="monitoring"}'
        priority: 2
        period: 60d
      - selector: '{job="n8n"}'
        priority: 3
        period: 14d  # Application logs kept shorter
```

**Storage Estimation:**

```
Storage = (Log Rate × Retention) ÷ Compression Ratio
Example: 1GB/day × 30 days ÷ 10 = 3GB

Homelab estimate:
- 10 pods × 100KB/s = 1MB/s = 86GB/day (compressed ~8.6GB/day)
- 30 days retention = 258GB total
```

**Recommendation:** Increase PVC from 10Gi to 50Gi when migrating to S3

### 4. Label Strategy (CRITICAL)

**Problem:** Wrong label design = query performance disaster

**Loki is NOT Elasticsearch:**
- ❌ Cannot index arbitrary fields (like user_id, request_path)
- ✅ Only indexes labels (namespace, pod, container)
- ⚠️ High-cardinality labels = performance killer

**Label Cardinality Examples:**

| Label | Cardinality | Status | Impact |
|-------|-------------|--------|--------|
| `namespace` | 20 | ✅ Low | Fast queries |
| `pod` | 100 | ✅ Low | Fast queries |
| `level` (info/warn/error) | 3 | ✅ Low | Fast queries |
| `user_id` | 10,000 | ❌ HIGH | **DISASTER** |
| `request_path` | 1,000+ | ❌ HIGH | **DISASTER** |
| `timestamp` | ∞ | ❌ INFINITE | **CLUSTER KILLER** |

**Golden Rule:**
```
Total Stream Count = Label1_Values × Label2_Values × Label3_Values × ...

Example (BAD):
{namespace, pod, user_id} = 20 × 100 × 10,000 = 20,000,000 streams ❌

Example (GOOD):
{namespace, pod, level} = 20 × 100 × 3 = 6,000 streams ✅
```

**Best Practice Label Design:**

**GOOD Labels (Low Cardinality):**
```yaml
# Static labels
{namespace="monitoring", pod="loki-0", app="loki"}

# Low-cardinality labels
{level="error"}              # 3-5 values (debug, info, warn, error, fatal)
{environment="production"}   # 2-3 values (dev, staging, prod)
{tier="0"}                   # 4 values (0, 1, 2, 3)
```

**BAD Labels (High Cardinality):**
```yaml
# ❌ User IDs
{user_id="12345"}  # Could be millions!

# ❌ Request paths
{path="/api/v1/users/12345"}  # Infinite unique values

# ❌ Timestamps
{timestamp="1234567890"}  # Every log has unique timestamp

# ❌ UUIDs
{request_id="550e8400-e29b-41d4-a716-446655440000"}  # Infinite
```

**Solution: Use Structured Metadata (Loki v2.9+)**

```yaml
# Labels (low cardinality, indexed)
{namespace="monitoring", pod="loki-0", level="error"}

# Structured metadata (high cardinality, NOT indexed but searchable)
user_id="12345"
request_path="/api/v1/users/12345"
request_id="550e8400-e29b-41d4-a716-446655440000"
```

**Query Example:**

```logql
# Filter by labels (fast, indexed)
{namespace="monitoring", level="error"}

# THEN filter by structured metadata (slower, but works)
| user_id="12345"
| request_path="/api/v1/users/12345"
```

**Promtail Configuration for Structured Metadata:**

```yaml
scrape_configs:
  - job_name: kubernetes-pods
    pipeline_stages:
      # Extract fields from JSON logs
      - json:
          expressions:
            level: level
            user_id: user_id
            request_path: path

      # Use level as label (low cardinality)
      - labels:
          level:

      # Use user_id and path as structured metadata (high cardinality)
      - structured_metadata:
          user_id:
          request_path:
```

**Benefits:**
- ✅ Query by user_id without cardinality explosion
- ✅ Filter by request_path without performance impact
- ✅ Loki index stays small (fast queries)

### 5. Multi-Tenancy

**Current:** auth_enabled: false
**Status:** Single-tenant (all logs mixed together)

**When to Enable Multi-Tenancy:**

**Use Cases:**
- Multiple teams sharing Loki cluster
- Dev/Staging/Prod log separation
- Cost allocation per team/project
- Security isolation (team A cannot see team B logs)

**Configuration:**

```yaml
loki:
  auth_enabled: true  # Enable multi-tenancy

  limits_config:
    # Per-tenant limits
    ingestion_rate_mb: 10       # 10MB/s per tenant
    ingestion_burst_size_mb: 20
    max_streams_per_user: 10000
    max_global_streams_per_user: 0  # Unlimited globally
```

**Promtail Tenant Configuration:**

```yaml
clients:
  - url: http://loki-gateway.monitoring.svc/loki/api/v1/push
    tenant_id: team-a  # Logs tagged with tenant ID

    # Or dynamic tenant from pod label
    tenant_id: ""
    pipeline_stages:
      - tenant:
          label: "namespace"  # Use namespace as tenant ID
```

**Grafana Multi-Tenant Queries:**

```yaml
# Datasource per tenant
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: loki-team-a
  namespace: grafana
spec:
  datasource:
    name: Loki (Team A)
    type: loki
    url: http://loki-gateway.monitoring.svc
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: team-a  # Tenant ID
```

**Homelab Decision:**
- ⚠️ Currently disabled (simpler, single tenant)
- ✅ Enable if multiple teams use cluster
- ❌ Skip if only you use homelab

### 6. Query Performance

**Current:** No query optimization configured
**Status:** Queries may be slow for large time ranges

**Query Performance Best Practices:**

#### A. Use Filters Early in Query

**BAD (slow):**
```logql
{namespace="monitoring"}
| json
| line_format "{{.level}}: {{.message}}"
| level="error"  # Filter AFTER parsing - processes all logs!
```

**GOOD (fast):**
```logql
{namespace="monitoring", level="error"}  # Filter FIRST with labels
| json
| line_format "{{.level}}: {{.message}}"
```

**Performance Difference:** 100x faster (filters before parsing)

#### B. Limit Time Range

**BAD:**
```logql
{namespace="monitoring"} [30d]  # Queries 30 days of logs
```

**GOOD:**
```logql
{namespace="monitoring"} [1h]  # Queries 1 hour of logs
```

**Recommendation:**
- Default time range: 6 hours
- Max time range: 7 days
- For older logs: use smaller step intervals

#### C. Use Query Frontend Caching

**Current:** Query frontend included in SingleBinary
**Status:** Good

```yaml
loki:
  query_range:
    results_cache:
      cache:
        enable_fifocache: true
        fifocache:
          max_size_bytes: 209715200  # 200MB
          ttl: 1h  # Cache results for 1 hour
```

**Benefit:** Repeated queries cached (instant results)

#### D. Enable Query Parallelization

```yaml
loki:
  query_scheduler:
    max_outstanding_requests_per_tenant: 2048

  querier:
    max_concurrent: 10  # Process 10 queries in parallel
```

**Benefit:** Faster dashboard loading (parallel queries)

### 7. Log Ingestion Rate Limits

**Current:** No limits configured
**Status:** Risk of ingestion overload

**Recommended Limits:**

```yaml
loki:
  limits_config:
    # Per-stream limits (prevents single app flooding Loki)
    ingestion_rate_mb: 10        # 10MB/s per stream
    ingestion_burst_size_mb: 20  # 20MB burst

    # Global limits (prevents cluster overload)
    max_streams_per_user: 10000        # Max 10k unique label combinations
    max_line_size: 256kb                # Reject logs >256KB
    max_entries_limit_per_query: 10000  # Max 10k lines per query

    # Query limits
    max_query_length: 721h    # 30 days max time range
    max_query_parallelism: 16
    max_query_series: 1000
```

**Why These Limits:**

1. **Prevent DoS:** Runaway app cannot kill Loki
2. **Fair Sharing:** No single app hogs resources
3. **Query Performance:** Large queries timeout gracefully
4. **Storage Protection:** Reject oversized logs

**Monitoring Limits:**

```promql
# Ingestion rate per stream
rate(loki_distributor_bytes_received_total[1m])

# Dropped logs (hitting limits)
rate(loki_distributor_lines_received_total{status="discarded"}[1m])
```

**Alert When Limits Hit:**

```yaml
- alert: LokiIngestingRateLimitHit
  expr: |
    rate(loki_distributor_lines_received_total{status="discarded"}[5m]) > 0
  labels:
    severity: warning
    priority: P3
  annotations:
    summary: "Loki dropping logs due to rate limit"
    description: "Stream {{ $labels.job }} is hitting ingestion rate limit"
```

### 8. Resource Sizing

**Current Resources:**
- SingleBinary: 100m/256Mi → 500m/1Gi
- Gateway: 25m/32Mi → 250m/256Mi

**Status:** Good for homelab

**Resource Estimation Formula:**

**Memory:**
```
RAM = (Active Streams × 1MB) + (Query Concurrency × 100MB) + (Cache Size)
Example: (1000 streams × 1MB) + (10 queries × 100MB) + 500MB cache = 2.5GB
```

**CPU:**
```
CPU = (Ingestion Rate × 0.1 cores/MB/s) + (Query Rate × 0.5 cores/query)
Example: (10MB/s × 0.1) + (5 queries × 0.5) = 3.5 cores
```

**Homelab Sizing Recommendations:**

| Deployment | Log Rate | Streams | RAM | CPU |
|------------|----------|---------|-----|-----|
| **SingleBinary (Small)** | <5GB/day | <1000 | 1Gi | 500m |
| **SingleBinary (Medium)** | <50GB/day | <5000 | 4Gi | 2000m |
| **Simple Scalable (Small)** | <100GB/day | <10k | 8Gi total | 4000m total |
| **Simple Scalable (Medium)** | <500GB/day | <50k | 16Gi total | 8000m total |

**Current Homelab Estimate:**
- 10 pods × 100KB/s = 1MB/s compressed = ~8.6GB/day
- ~1000 active streams
- **Verdict:** Current resources (1Gi RAM) sufficient

**Signs of Under-Provisioning:**
- OOMKilled pods
- Query timeouts (>30s)
- Ingestion lag (logs delayed)
- High CPU usage (>80% sustained)

---

## Migration Path: Filesystem to S3

**Goal:** Production-ready storage with HA and retention

**Step-by-Step Migration:**

### Phase 1: Preparation (Day 0)

1. **Create Ceph RGW S3 Buckets:**
```bash
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin user create --uid=loki --display-name="Loki Logs"

kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  s3cmd mb s3://loki-chunks
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  s3cmd mb s3://loki-ruler
```

2. **Create SealedSecret with S3 Credentials:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loki-s3-credentials
  namespace: monitoring
type: Opaque
stringData:
  LOKI_S3_ACCESS_KEY: <ACCESS_KEY>
  LOKI_S3_SECRET_KEY: <SECRET_KEY>
```

### Phase 2: Deploy New Loki with S3 (Day 1)

1. **Update values.yaml:**
```yaml
# Change storage backend to S3
loki:
  storage:
    type: s3
    bucketNames:
      chunks: loki-chunks
      ruler: loki-ruler
    s3:
      endpoint: rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
      region: eu-west-1
      s3ForcePathStyle: true
      insecure: true

  schemaConfig:
    configs:
      - from: "2025-10-20"  # NEW schema start date (today)
        store: tsdb
        object_store: s3
        schema: v13
```

2. **Deploy new Loki (parallel to old):**
```bash
# Deploy with new name
helm upgrade loki-s3 grafana/loki -n monitoring -f values-s3.yaml
```

### Phase 3: Switch Log Collectors (Day 2-7)

1. **Update Promtail/Vector to send to new Loki:**
```yaml
# Promtail config
clients:
  - url: http://loki-s3-gateway.monitoring.svc/loki/api/v1/push
```

2. **Monitor both Loki instances:**
```bash
# Old Loki (filesystem) - should stop receiving logs
kubectl logs -n monitoring loki-0 -f

# New Loki (S3) - should receive logs
kubectl logs -n monitoring loki-s3-0 -f
```

### Phase 4: Update Grafana Datasource (Day 7)

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: loki
  namespace: grafana
spec:
  datasource:
    url: http://loki-s3-gateway.monitoring.svc  # Point to new Loki
```

### Phase 5: Decommission Old Loki (Day 14)

1. **Verify new Loki working:**
```bash
# Check query results in Grafana
{namespace="monitoring"} [7d]  # Should show logs from new Loki
```

2. **Delete old Loki:**
```bash
helm uninstall loki -n monitoring
kubectl delete pvc loki-0 -n monitoring  # Old logs deleted
```

**Rollback Plan:**
- If issues arise, switch Grafana datasource back to old Loki
- Old logs still available for 14 days
- No data loss (both Lokis running in parallel)

---

## Troubleshooting Guide

### Issue: "no org id" error in logs

**Cause:** Multi-tenancy enabled but tenant ID not provided

**Solution:**
```yaml
# Disable multi-tenancy for homelab
loki:
  auth_enabled: false
```

### Issue: "maximum active stream limit exceeded"

**Cause:** Too many unique label combinations (high cardinality)

**Solution:**
1. Check label cardinality:
```promql
sum by (__name__) (loki_ingester_streams)
```

2. Reduce label cardinality (remove high-cardinality labels)
3. Increase limit (temporary):
```yaml
loki:
  limits_config:
    max_streams_per_user: 20000  # Doubled from 10k
```

### Issue: Slow queries (>30 seconds)

**Solutions:**
1. Reduce time range ([1h] instead of [30d])
2. Add more label filters
3. Enable query result caching
4. Increase querier resources

### Issue: Logs not appearing in Grafana

**Check:**
1. Loki receiving logs:
```bash
kubectl logs -n monitoring loki-0 | grep "POST /loki/api/v1/push"
```

2. Promtail sending logs:
```bash
kubectl logs -n monitoring promtail-xxxx | grep "POST"
```

3. Label mismatch:
```logql
# Check what labels exist
{namespace="monitoring"}  # Adjust namespace if different
```

---

## Quick Wins for Homelab

### 1. Add Explicit Retention

```yaml
loki:
  limits_config:
    retention_period: 30d
  compactor:
    retention_enabled: true
```

**Benefit:** Prevent disk full, automatic cleanup

### 2. Configure Ingestion Rate Limits

```yaml
loki:
  limits_config:
    ingestion_rate_mb: 10
    max_line_size: 256kb
```

**Benefit:** Prevent runaway apps from killing Loki

### 3. Increase PVC Size

```yaml
singleBinary:
  persistence:
    size: 50Gi  # Increased from 10Gi
```

**Benefit:** Support 30d retention without disk full

---

## Production Readiness Checklist

- [x] **Schema:** v13 TSDB (modern standard)
- [x] **Resources:** Configured for homelab
- [x] **Cache:** Configured (500MB chunks, 200MB results)
- [ ] **Storage Backend:** Migrate filesystem → S3/Ceph RGW
- [ ] **Retention:** Configure 30d retention
- [ ] **Rate Limits:** Configure ingestion limits
- [ ] **HA:** Migrate to Simple Scalable mode
- [ ] **Labels:** Audit for high cardinality
- [ ] **Monitoring:** Add Loki self-monitoring alerts

**Homelab Status:**
- ✅ Modern TSDB v13 schema
- ✅ Resource limits appropriate
- ✅ Gateway proxy configured
- ⚠️ Filesystem storage (not HA)
- ⚠️ No retention policy (will fill disk)
- ⚠️ No rate limits (risk of overload)
- ❌ Single replica (no HA)

**Recommended Next Steps:**
1. Add retention policy (30d)
2. Increase PVC to 50Gi
3. Configure rate limits
4. Plan migration to S3/Ceph RGW

---

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
- [Storage Configuration](https://grafana.com/docs/loki/latest/operations/storage/)
- [Label Design](https://grafana.com/docs/loki/latest/get-started/labels/)
- [Deployment Modes](https://grafana.com/docs/loki/latest/fundamentals/architecture/deployment-modes/)
