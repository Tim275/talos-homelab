# Prometheus Best Practices Guide

## Current State Analysis

### Deployment Configuration

**Stack:** kube-prometheus-stack v3.5.0
**Storage:** 20GB Ceph Block (rook-ceph-block-enterprise)
**Retention:** Not explicitly configured (default 15d)
**HA:** Single replica (not production-ready)
**Resource Limits:**
- Prometheus Operator: 100m CPU / 256Mi RAM (request), 1000m CPU / 1Gi RAM (limit)
- kube-state-metrics: 50m CPU / 64Mi RAM (request), 500m CPU / 512Mi RAM (limit)

### ServiceMonitor Configuration

**Scope:** Cluster-wide discovery enabled
```yaml
podMonitorNamespaceSelector: {}        # All namespaces
podMonitorSelectorNilUsesHelmValues: false
serviceMonitorNamespaceSelector: {}    # All namespaces
serviceMonitorSelectorNilUsesHelmValues: false
```

**Monitored Components:**
- kube-apiserver
- kube-controller-manager
- kube-etcd
- kube-scheduler
- kubelet
- kube-state-metrics
- node-exporter
- prometheus-operator

**Disabled Components:**
- kube-proxy (replaced by Cilium)

### Alert Configuration

**Enterprise 4-Tier Alert System:**
- Tier 0: Control Plane (kube-apiserver, etcd, controller-manager, scheduler, kubelet)
- Tier 1: Infrastructure (Talos, Cilium, ArgoCD, Cert-Manager)
- Tier 2: Storage (Rook Ceph, Velero, PostgreSQL)
- Tier 3: Applications (N8N, Audiobookshelf, Kafka, Elasticsearch)

**Priority Levels:**
- P1 (Critical): 5min SLA, instant notification, 5min repeat
- P2 (High): 15min SLA, 10s wait, 15min repeat
- P3 (Warning): 1h SLA, 30s wait, 1h repeat
- P5 (Info): 4h SLA, 2min wait, 4h repeat

**Alert Routing:**
- All alerts sent to Keep AIOps + Ollama AI for enrichment
- Priority-based Slack channels with custom templates
- Inhibit rules prevent alert spam

---

## Best Practices Assessment

### 1. Retention Policy

**Current State:** Default 15d
**Recommendation:** Explicitly configure retention

```yaml
# kubernetes/infrastructure/monitoring/kube-prometheus-stack/values.yaml
prometheus:
  prometheusSpec:
    retention: 15d           # Homelab standard
    retentionSize: "18GB"    # 90% of 20GB storage
```

**Why:**
- **15 days** is sufficient for homelab incident investigation
- **retentionSize** prevents disk full issues
- For longer retention, migrate to VictoriaMetrics or Thanos

**Enterprise Comparison:**
- **Startups:** 7-15 days (cost-conscious)
- **Scale-ups:** 30-90 days (compliance requirements)
- **Enterprise:** 6-12 months (via Thanos/VictoriaMetrics)

### 2. Scrape Intervals

**Current State:** Default 30s (via global config)
**Status:** Good

```yaml
# Already configured correctly
prometheus:
  prometheusSpec:
    scrapeInterval: 30s    # Current setting
    evaluationInterval: 30s
```

**Best Practice:**
- **30-60s** for production/homelab
- **15s** only for critical services (API servers, databases)
- **5m** for slow-changing metrics (storage capacity, certificate expiry)

**Why:**
- 30s balances metric granularity vs storage/CPU cost
- Lower intervals increase cardinality and storage requirements exponentially

### 3. High Availability

**Current State:** Single replica
**Status:** NOT production-ready
**Risk:** Single point of failure

**Recommendation:** Enable HA for production

```yaml
prometheus:
  prometheusSpec:
    replicas: 2             # Minimum for HA
    # Optional: podAntiAffinity to spread replicas across nodes
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/name
                    operator: In
                    values:
                      - prometheus
              topologyKey: kubernetes.io/hostname
```

**Homelab Decision:**
- **Single replica:** Acceptable for homelab (lower resource usage)
- **2 replicas:** Recommended if uptime is critical
- **3+ replicas:** Enterprise only (high availability + load balancing)

**Resource Impact:**
- 2 replicas = 2x storage (40GB total)
- 2 replicas = 2x CPU/RAM usage

### 4. Storage Configuration

**Current State:** 20GB Ceph Block
**Status:** Good for homelab

```yaml
storageSpec:
  volumeClaimTemplate:
    spec:
      storageClassName: rook-ceph-block-enterprise
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 20G
```

**Best Practice:**
- **15-30GB:** Homelab with 15d retention
- **50-100GB:** Production with 30d retention
- **200GB+:** Enterprise with local retention + remote write

**Storage Estimation Formula:**
```
Storage = Samples/s × Retention × Bytes/Sample
Example: 10,000 samples/s × 15 days × 2 bytes ≈ 25.9GB
```

**Current Metrics:**
- Check cardinality: `prometheus_tsdb_symbol_table_size_bytes`
- Check series: `prometheus_tsdb_head_series`

### 5. Remote Write (Long-term Storage)

**Current State:** Not configured
**Status:** Missing for long-term metrics

**Option A: VictoriaMetrics (Recommended for Homelab)**

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: http://vminsert-vmcluster.monitoring.svc:8480/insert/0/prometheus/
        queueConfig:
          capacity: 10000
          maxShards: 5
          minShards: 1
          maxSamplesPerSend: 5000
          batchSendDeadline: 5s
```

**Benefits:**
- **50% less RAM** than Prometheus
- **3x better compression** (30GB → 10GB)
- **PromQL compatible** (drop-in replacement)
- **Simpler than Thanos** (no object storage required)

**Option B: Thanos (Enterprise Alternative)**

```yaml
prometheus:
  prometheusSpec:
    thanos:
      objectStorageConfig:
        key: thanos.yaml
        name: thanos-objstore-config
    externalLabels:
      cluster: homelab
      replica: $(POD_NAME)
```

**When to use Thanos:**
- Multi-cluster metrics aggregation
- Unlimited retention (S3/MinIO storage)
- Global query view across clusters
- Downsampling for cost optimization

**Cost Comparison:**
- **VictoriaMetrics:** Free, single binary, <1GB RAM
- **Thanos:** Free, 5+ components, 2-4GB RAM total

### 6. Recording Rules

**Current State:** Default rules disabled
**Status:** Good (using custom rules only)

```yaml
defaultRules:
  create: false  # Disabled to use custom enterprise rules
```

**Best Practice:** Create recording rules for expensive queries

**Example Recording Rule:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules-performance
  namespace: monitoring
spec:
  groups:
    - name: performance.recording
      interval: 30s
      rules:
        # Pre-aggregate pod CPU usage (expensive query!)
        - record: namespace:pod_cpu_usage:sum
          expr: |
            sum(rate(container_cpu_usage_seconds_total{container!=""}[5m]))
            by (namespace, pod)

        # Pre-aggregate pod memory usage
        - record: namespace:pod_memory_usage:sum
          expr: |
            sum(container_memory_working_set_bytes{container!=""})
            by (namespace, pod)

        # API server request rate (dashboard optimization)
        - record: cluster:apiserver_request_rate:sum
          expr: sum(rate(apiserver_request_total[5m]))
```

**When to use recording rules:**
- Query takes >5s in Grafana
- Same query used in multiple dashboards
- Complex aggregations (rate + sum + histogram_quantile)

**Storage impact:**
- Each recording rule = new metric = storage cost
- Use sparingly (10-20 rules max for homelab)

### 7. Cardinality Management

**Current Problem:** User reported broken dashboards ("datasource not found")
**Root Cause Analysis Required:**

**Check current cardinality:**

```bash
# Total series
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -- \
  promtool tsdb analyze /prometheus

# Top 10 high-cardinality metrics
topk(10, count by (__name__)({__name__=~".+"}))
```

**Common cardinality explosions:**
- **User ID in labels** → Millions of series
- **Request path in labels** → Thousands of series
- **Dynamic labels** (timestamps, UUIDs)

**Best Practice - Label Design:**

**GOOD:**
```yaml
method="GET"
status="200"
endpoint="/api/v1/users"
```

**BAD:**
```yaml
user_id="12345"           # High cardinality!
path="/api/v1/users/12345"  # Unbounded!
timestamp="1234567890"      # Infinite cardinality!
```

**Mitigation:**
- Drop high-cardinality labels via relabeling
- Use `metric_relabel_configs` in ServiceMonitors
- Monitor cardinality growth: `prometheus_tsdb_symbol_table_size_bytes`

### 8. Resource Limits

**Current State:** Configured
**Status:** Good for homelab

```yaml
# Prometheus Operator
prometheusOperator:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 1000m      # 10x burst for CRD operations
      memory: 1Gi

# kube-state-metrics
kube-state-metrics:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

**Best Practice - Prometheus Server:**

```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 500m
        memory: 2Gi    # Base for 10k series
      limits:
        cpu: 2000m
        memory: 4Gi    # 2x headroom
```

**Memory Estimation:**
```
RAM = (Series × 1-2KB) + (Samples in RAM × 2 bytes)
Example: 10,000 series × 1.5KB = 15MB (metadata) + 50MB (samples) = 65MB minimum
Add 2x buffer = 130MB
```

**Signs of under-provisioning:**
- OOMKilled pods
- Slow queries (>10s for simple aggregations)
- `prometheus_tsdb_compactions_failed_total` increasing

### 9. Security Best Practices

**Current State:** TLS disabled, no authentication
**Status:** CRITICAL for production

```yaml
# CURRENT (Insecure)
prometheusOperator:
  tls:
    enabled: false
  admissionWebhooks:
    enabled: false
```

**Production Recommendation:**

```yaml
# Enable TLS
prometheusOperator:
  tls:
    enabled: true
  admissionWebhooks:
    enabled: true
    certManager:
      enabled: true  # Auto-provision certs via cert-manager

# Enable authentication
prometheus:
  prometheusSpec:
    web:
      # Option 1: Basic Auth
      httpConfig:
        basicAuth:
          username: admin
          password:
            name: prometheus-basic-auth
            key: password

      # Option 2: OAuth2 Proxy (better)
      # Deploy oauth2-proxy with Keycloak/Authelia
```

**Homelab Decision:**
- **TLS disabled:** Acceptable if Prometheus not exposed externally
- **No auth:** Acceptable for local-only access
- **Production:** MUST enable TLS + OAuth2/OIDC

---

## Migration Path: VictoriaMetrics

**Why VictoriaMetrics?**
- **50% less RAM** than Prometheus (2GB → 1GB)
- **3x better compression** (30GB → 10GB)
- **PromQL compatible** (no query rewriting)
- **Simpler than Thanos** (single binary vs 5+ components)
- **Free & open source**

**Current State:** VictoriaMetrics Operator partially deployed

```yaml
# kubernetes/infrastructure/monitoring/victoriametrics/kustomization.yaml
resources:
  - vmcluster.yaml            # VM Cluster
  - vmagent.yaml              # VM Agent (scrapes ServiceMonitors)
  - grafana-datasource.yaml   # Datasource configured
```

**Migration Strategy:**

**Phase 1: Dual-stack (Prometheus + VictoriaMetrics)**
1. Deploy VictoriaMetrics alongside Prometheus
2. Configure Prometheus remote_write to VictoriaMetrics
3. Update Grafana dashboards to use VictoriaMetrics datasource
4. Run both for 30 days (validation period)

**Phase 2: Full Migration**
1. Stop Prometheus scraping (keep as backup)
2. VictoriaMetrics vmagent takes over scraping
3. Decommission Prometheus after 90 days

**Configuration:**

```yaml
# Step 1: Add remote_write to Prometheus
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: http://vminsert-vmcluster.monitoring.svc:8480/insert/0/prometheus/
        writeRelabelConfigs:
          # Optional: drop high-cardinality metrics
          - sourceLabels: [__name__]
            regex: 'container_network_tcp_usage_total|container_tasks_state'
            action: drop

# Step 2: Configure vmagent to scrape ServiceMonitors
# Already configured in vmagent.yaml
```

**Grafana Datasource Update:**

```yaml
# kubernetes/infrastructure/monitoring/victoriametrics/grafana-datasource.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: victoriametrics
  namespace: grafana
spec:
  datasource:
    name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus/
    isDefault: true  # Replace Prometheus as default
    jsonData:
      timeInterval: 30s
```

**Rollback Plan:**
- Keep Prometheus running for 30 days
- If issues arise, switch Grafana datasource back to Prometheus
- VictoriaMetrics can be deleted without data loss (Prometheus still has data)

---

## Troubleshooting Guide

### Issue: Dashboards show "datasource not found"

**Root Cause:** Datasource UID mismatch

**Current Datasources:**
```yaml
- prometheus: bcc9d3ee-2926-4b20-b364-f067529673ff
- loki: d2b40721-7276-43cf-afbc-d064116217e4
- alertmanager: 4a200eff-39ee-4f38-9608-28b9e8535176
```

**Solution:**

1. Check dashboard datasource UID:
```bash
kubectl get grafanadashboard -A -o yaml | grep -A5 datasource
```

2. Fix UID in dashboard JSON:
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "bcc9d3ee-2926-4b20-b364-f067529673ff"  // Must match GrafanaDatasource
  }
}
```

3. **Best Practice:** Use datasource name instead of UID:
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "${DS_PROMETHEUS}"  // Variable reference
  }
}
```

### Issue: High memory usage / OOMKilled

**Check memory usage:**
```bash
kubectl top pod -n monitoring prometheus-kube-prometheus-stack-0
```

**Check cardinality:**
```promql
# Total series
prometheus_tsdb_head_series

# Series per metric
topk(10, count by (__name__)({__name__=~".+"}))
```

**Solutions:**
1. Increase memory limits (short-term)
2. Reduce retention (15d → 7d)
3. Drop high-cardinality metrics
4. Enable remote_write to VictoriaMetrics

### Issue: Slow queries

**Check query performance:**
```bash
# Query stats
rate(prometheus_engine_query_duration_seconds_sum[5m])
```

**Solutions:**
1. Create recording rules for expensive queries
2. Reduce query time range (30d → 7d)
3. Increase Prometheus CPU limits
4. Migrate to VictoriaMetrics (3x faster queries)

### Issue: Storage full

**Check storage usage:**
```bash
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -- \
  df -h /prometheus
```

**Solutions:**
1. Enable `retentionSize: "18GB"` (prevents disk full)
2. Reduce retention: `retention: 7d`
3. Increase PVC size: `storage: 50G`
4. Enable remote_write and reduce local retention

---

## Quick Wins for Homelab

### 1. Explicit Retention Configuration

```yaml
# kubernetes/infrastructure/monitoring/kube-prometheus-stack/values.yaml
prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: "18GB"  # 90% of 20GB PVC
```

**Benefit:** Prevents disk full, explicit config visible in IaC

### 2. Fix Datasource UIDs in Dashboards

**Problem:** User reports "datasource not found" in many dashboards

**Action Required:**
1. Audit all GrafanaDashboard resources
2. Replace hardcoded UIDs with datasource names
3. Use variables: `${DS_PROMETHEUS}`

```bash
# Find broken dashboards
kubectl get grafanadashboard -A -o yaml | grep -B5 "datasource.*uid"
```

### 3. Enable VictoriaMetrics Remote Write

**Benefit:**
- 3x compression (30GB → 10GB)
- 50% less RAM usage
- Longer retention possible (15d → 90d)

**Effort:** 5 minutes (just add remote_write config)

### 4. Create Recording Rules for Dashboards

**Problem:** Slow dashboard loading (user complaint about broken dashboards)

**Action:** Create recording rules for top 10 queries

```yaml
# Check slow queries in Grafana
# Create recording rules for queries taking >5s
```

**Benefit:** 10x faster dashboard loading

---

## Production Readiness Checklist

- [ ] **Retention:** Explicitly configured (retention + retentionSize)
- [ ] **HA:** 2+ replicas with pod anti-affinity
- [ ] **Remote Write:** VictoriaMetrics or Thanos configured
- [ ] **TLS:** Enabled for all communication
- [ ] **Authentication:** OAuth2/OIDC enabled
- [ ] **Resource Limits:** Configured based on cardinality
- [ ] **Recording Rules:** Created for expensive queries
- [ ] **Cardinality Monitoring:** Alert on high cardinality growth
- [ ] **Backup:** Snapshots or remote_write for disaster recovery
- [ ] **Monitoring:** Prometheus self-monitoring alerts configured

**Homelab Status:**
- ✅ Resource limits configured
- ✅ ServiceMonitor discovery enabled
- ✅ Custom alert rules (Tier 0-3)
- ⚠️ Retention not explicit (using default 15d)
- ⚠️ Single replica (no HA)
- ❌ No remote write (no long-term storage)
- ❌ TLS disabled
- ❌ No authentication

**Recommended Next Steps:**
1. Add explicit retention configuration
2. Enable VictoriaMetrics remote_write
3. Fix Grafana datasource UIDs in dashboards
4. Create recording rules for slow queries

---

## References

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [VictoriaMetrics vs Prometheus](https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#prometheus-vs-victoriametrics)
- [Thanos Documentation](https://thanos.io/tip/thanos/getting-started.md/)
- [Cardinality Management](https://www.robustperception.io/cardinality-is-key)
