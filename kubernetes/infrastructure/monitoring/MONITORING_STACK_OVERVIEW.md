# Monitoring Stack Overview - Enterprise Tier 0 Observability

## Introduction

This document provides a comprehensive overview of the Homelab monitoring stack based on enterprise best practices from US companies in 2025.

**Documentation Structure:**
- `MONITORING_STACK_OVERVIEW.md` ← You are here (master guide)
- `PROMETHEUS_BEST_PRACTICES.md` - Metrics collection and storage
- `GRAFANA_SETUP_GUIDE.md` - Visualization and dashboards
- `LOKI_BEST_PRACTICES.md` - Log aggregation and analysis

**Similar to:**
- `kubernetes/infrastructure/observability/elasticsearch/LICENSE_COMPARISON.md`
- `kubernetes/infrastructure/observability/elasticsearch/snapshots/POLICIES_GUIDE.md`

---

## Stack Architecture

### Current Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                    TIER 0 MONITORING STACK                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  PROMETHEUS  │  │   GRAFANA    │  │     LOKI     │          │
│  │   (Metrics)  │  │(Visualization)│  │    (Logs)    │          │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤          │
│  │ • v3.5.0     │  │ • v12.1.0    │  │ • v3.1.1     │          │
│  │ • 20GB       │  │ • Operator   │  │ • SingleBin  │          │
│  │ • 1 replica  │  │ • LoadBalancer│  │ • 10Gi      │          │
│  │ • 15d default│  │ • OSS        │  │ • Filesystem │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                   │                   │                │
│         └───────────────────┴───────────────────┘                │
│                             │                                     │
│                    ┌────────▼────────┐                           │
│                    │  ALERTMANAGER   │                           │
│                    │  (P1-P5 Alerts) │                           │
│                    ├─────────────────┤                           │
│                    │ • 2 replicas    │                           │
│                    │ • Slack webhooks│                           │
│                    │ • Keep AIOps   │                           │
│                    └─────────────────┘                           │
│                                                                   │
│  ┌──────────────────────────────────────────────────────┐       │
│  │          ENTERPRISE ADDITIONS                         │       │
│  ├──────────────────────────────────────────────────────┤       │
│  │ • VictoriaMetrics (partially deployed)               │       │
│  │ • Jaeger (distributed tracing)                       │       │
│  │ • Hubble (Cilium network flows)                      │       │
│  │ • Robusta (AI troubleshooting)                       │       │
│  │ • Keep (AIOps + Ollama AI alert enrichment)          │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Versions

| Component | Version | Status | Production Ready |
|-----------|---------|--------|------------------|
| **kube-prometheus-stack** | Chart: latest, Prometheus: v3.5.0 | ✅ Running | ⚠️ Single replica |
| **Grafana Operator** | v5.19.1, Grafana: v12.1.0 | ✅ Running | ✅ Yes |
| **Loki** | v3.1.1 (SingleBinary) | ✅ Running | ⚠️ Filesystem storage |
| **Alertmanager** | v0.27.0 (2 replicas) | ✅ Running | ✅ Yes |
| **VictoriaMetrics** | Operator deployed | ⚠️ Partial | 🔄 Migration pending |
| **Jaeger** | v1.61.0 | ✅ Running | ✅ Yes |
| **Hubble** | Cilium v1.16.4 | ✅ Running | ✅ Yes |
| **Keep** | Latest | ✅ Running | ✅ Yes |
| **Robusta** | Latest | ✅ Running | ✅ Yes |

---

## Three Pillars of Observability

### 1. Metrics (Prometheus/VictoriaMetrics)

**Purpose:** Time-series numeric data (CPU, memory, request rate)

**Current State:**
- ✅ kube-prometheus-stack deployed
- ✅ 20GB Ceph storage
- ✅ ServiceMonitor discovery enabled (all namespaces)
- ⚠️ Single replica (no HA)
- ⚠️ Default 15d retention (not explicit)
- ❌ No remote write (no long-term storage)

**Best Practices Implemented:**
- ✅ Custom enterprise alert rules (Tier 0-3)
- ✅ Priority-based alerting (P1-P5)
- ✅ Resource limits configured
- ✅ Talos-specific relabeling (kube-etcd, controller-manager)

**Missing Best Practices:**
- ❌ Explicit retention configuration
- ❌ HA setup (2+ replicas)
- ❌ Remote write to VictoriaMetrics/Thanos
- ❌ Recording rules for expensive queries

**See:** `PROMETHEUS_BEST_PRACTICES.md` for detailed analysis

### 2. Logs (Loki)

**Purpose:** Application and system log aggregation

**Current State:**
- ✅ Loki v3.1.1 SingleBinary deployed
- ✅ Modern TSDB v13 schema
- ✅ 10Gi Ceph storage
- ⚠️ Filesystem backend (not production-ready)
- ⚠️ No retention policy configured
- ⚠️ Single replica (no HA)

**Best Practices Implemented:**
- ✅ Gateway (nginx) proxy configured
- ✅ Cache configured (500MB chunks, 200MB results)
- ✅ Resource limits appropriate for homelab

**Missing Best Practices:**
- ❌ S3/Object storage backend (use Ceph RGW)
- ❌ Retention policy (30d recommended)
- ❌ Rate limits (prevent ingestion overload)
- ❌ Label cardinality audit

**See:** `LOKI_BEST_PRACTICES.md` for detailed analysis

### 3. Traces (Jaeger)

**Purpose:** Distributed request tracing (microservices)

**Current State:**
- ✅ Jaeger v1.61.0 deployed
- ✅ OpenTelemetry Collector integration
- ✅ Grafana datasource configured

**Status:** Production-ready for homelab

**Trace Sources:**
- Istio service mesh (if deployed)
- N8N automation workflows
- Kafka streaming pipelines

---

## Alerting Architecture

### Enterprise Priority-Based Alerting

**4-Tier Alert System:**

```
┌─────────────────────────────────────────────────────────┐
│  TIER 0: CONTROL PLANE (P1/P2 only)                     │
│  • kube-apiserver, etcd, controller-manager, scheduler  │
│  • SLA: P1 = 5min, P2 = 15min                           │
├─────────────────────────────────────────────────────────┤
│  TIER 1: INFRASTRUCTURE (P1/P2/P3)                      │
│  • Talos, Cilium, ArgoCD, Cert-Manager, Storage        │
│  • SLA: P1 = 5min, P2 = 15min, P3 = 1h                 │
├─────────────────────────────────────────────────────────┤
│  TIER 2: STORAGE & DATABASES (P2/P3)                    │
│  • Rook Ceph, Velero, PostgreSQL, Elasticsearch        │
│  • SLA: P2 = 15min, P3 = 1h                             │
├─────────────────────────────────────────────────────────┤
│  TIER 3: APPLICATIONS (P3/P5)                           │
│  • N8N, Audiobookshelf, Kafka, CloudBeaver             │
│  • SLA: P3 = 1h, P5 = 4h                                │
└─────────────────────────────────────────────────────────┘
```

**Priority Levels:**

| Priority | Severity | Response SLA | Group Wait | Repeat Interval | Example |
|----------|----------|--------------|------------|-----------------|---------|
| **P1** | Critical (🔴) | 5 minutes | 0s (instant) | 5 minutes | API server down |
| **P2** | High (🟠) | 15 minutes | 10 seconds | 15 minutes | ETCD leader changes |
| **P3** | Warning (🟡) | 1 hour | 30 seconds | 1 hour | High memory usage |
| **P5** | Info (🔵) | 4 hours | 2 minutes | 4 hours | Certificate renewal |

**Notification Channels:**

1. **Slack** (Priority-based templates)
   - P1: `@Sysadmins` mention, red color, rotating_light emoji
   - P2: Warning color, detailed metrics
   - P3: Yellow color, summary only
   - P5: Blue color, informational

2. **Keep AIOps + Ollama AI** (All alerts)
   - AI-powered alert enrichment
   - Root cause analysis
   - Automated remediation suggestions
   - Alert correlation across services

**Inhibit Rules:**
- Critical suppresses warnings (same target)
- P1 suppresses P2/P3 (same service)
- NodeDown suppresses pod alerts (same node)

**Alert Files:**
- `alertmanager/tier0-control-plane-alerts.yaml` - 307 lines (Kubernetes core)
- `alertmanager/tier1-infrastructure-alerts.yaml` - Infrastructure services
- `alertmanager/tier2-storage-alerts.yaml` - Storage & databases
- `alertmanager/tier3-application-alerts.yaml` - User applications

---

## Dashboards & Visualization

### Grafana Operator Setup

**Deployment Method:** Grafana Operator (not Helm)
**Benefits:**
- ✅ GrafanaDashboard CRDs (Kubernetes-native)
- ✅ GrafanaDatasource CRDs (GitOps-friendly)
- ✅ GrafanaFolder CRDs (organization)
- ✅ Multi-instance support

**Datasources Configured:**

| Datasource | UID | Default | URL | Status |
|------------|-----|---------|-----|--------|
| **Prometheus** | `bcc9d3ee-...` | Yes | `prometheus-operated.monitoring.svc:9090` | ✅ Synced |
| **Loki** | `d2b40721-...` | No | `loki-gateway.monitoring.svc:80` | ✅ Synced |
| **Alertmanager** | `4a200eff-...` | No | `alertmanager-operated.monitoring.svc:9093` | ✅ Synced |

**CRITICAL ISSUE:** Many dashboards showing "datasource not found" due to UID mismatch

**Solution:** Update dashboard JSONs to use datasource names instead of hardcoded UIDs

```json
// BEFORE (broken)
{"datasource": {"uid": "WRONG_UID_12345"}}

// AFTER (works)
{"datasource": "Prometheus"}
```

**See:** `GRAFANA_SETUP_GUIDE.md` for detailed fix

### Dashboard Organization

**Current:** Flat structure (no folders)
**Recommended:** Enterprise hierarchy

```
Tier 0 - Control Plane/
├── Kubernetes API Server
├── ETCD Cluster Health
├── Controller Manager
└── Scheduler Performance

Tier 1 - Infrastructure/
├── Talos System Overview
├── Cilium Network
├── ArgoCD GitOps
└── Cert-Manager SSL

Tier 2 - Storage/
├── Ceph Cluster Overview
├── Ceph Pool Details
├── Velero Backup
└── PostgreSQL (CNPG)

Tier 3 - Applications/
├── N8N Automation
├── Audiobookshelf Media
├── Kafka Streaming
└── Elasticsearch Logs

Executive/
├── Homelab Overview
└── Resource Costs
```

**See:** `GRAFANA_SETUP_GUIDE.md` for implementation guide

### Monitoring Methodologies

**Enterprise Standards:**

1. **Golden Signals** (Google SRE)
   - Latency, Traffic, Errors, Saturation
   - Use for: User-facing services (N8N, Audiobookshelf)

2. **RED Method** (Microservices)
   - Rate, Errors, Duration
   - Use for: APIs, microservices, Istio mesh

3. **USE Method** (Resources)
   - Utilization, Saturation, Errors
   - Use for: Infrastructure (nodes, disks, network)

**Recommended Application:**
- **Tier 0-1:** USE Method (infrastructure)
- **Tier 2:** Golden Signals (storage services)
- **Tier 3:** RED Method (application services)

---

## Current Issues & Quick Wins

### CRITICAL Issues (Fix Immediately)

#### 1. Grafana Datasource UID Mismatch

**Problem:** User reports many dashboards showing "datasource not found"

**Impact:** Dashboards unusable, poor user experience

**Root Cause:** Dashboard JSONs reference wrong datasource UIDs

**Solution:**
```bash
# 1. Get current datasource UIDs
kubectl get grafanadatasources -n grafana -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.uid}{"\n"}{end}'

# 2. Update all dashboards to use datasource names (not UIDs)
# Find all dashboards: kubectl get grafanadashboard -A
# Update each dashboard JSON to use datasource name
```

**Effort:** 2-4 hours (one-time fix)
**Benefit:** All dashboards work immediately

**See:** `GRAFANA_SETUP_GUIDE.md` section "Datasource Configuration"

#### 2. Loki Filesystem Storage (Not Production-Ready)

**Problem:** Logs stored on local disk (no HA, no retention)

**Impact:**
- Logs lost if pod/node fails
- 10Gi PVC will fill up eventually
- Cannot scale horizontally

**Solution:** Migrate to Ceph RGW S3

**Effort:** 4-6 hours (includes testing)
**Benefit:** Production-ready storage, automatic retention, HA-ready

**See:** `LOKI_BEST_PRACTICES.md` section "Migration Path: Filesystem to S3"

### High-Priority Quick Wins

#### 3. Add Explicit Retention Configuration

**Prometheus:**
```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: "18GB"  # 90% of 20GB PVC
```

**Loki:**
```yaml
loki:
  limits_config:
    retention_period: 30d
  compactor:
    retention_enabled: true
```

**Effort:** 5 minutes (just add config)
**Benefit:** Prevent disk full, explicit documentation

#### 4. Create Dashboard Folder Hierarchy

**Action:**
1. Create GrafanaFolder resources (Tier 0-3, Executive)
2. Assign existing dashboards to folders

**Effort:** 1-2 hours
**Benefit:** Professional organization, easy navigation

#### 5. Configure Loki Rate Limits

```yaml
loki:
  limits_config:
    ingestion_rate_mb: 10
    max_line_size: 256kb
    max_streams_per_user: 10000
```

**Effort:** 5 minutes
**Benefit:** Prevent runaway apps from killing Loki

---

## Migration Paths

### Option A: VictoriaMetrics (Recommended)

**Goal:** Replace Prometheus with VictoriaMetrics for better performance

**Benefits:**
- 50% less RAM than Prometheus
- 3x better compression (30GB → 10GB)
- PromQL compatible (no query changes)
- Simpler than Thanos (single binary)

**Current State:** VictoriaMetrics Operator partially deployed

**Migration Strategy:**

**Phase 1:** Dual-stack (Prometheus + VictoriaMetrics)
1. Configure Prometheus remote_write to VictoriaMetrics
2. Update Grafana datasources to use VictoriaMetrics
3. Run both for 30 days (validation)

**Phase 2:** Full migration
1. Stop Prometheus scraping
2. VictoriaMetrics vmagent takes over
3. Decommission Prometheus after 90 days

**Effort:** 8-12 hours total
**ROI:** 50% RAM savings, 3x storage savings

**See:** `PROMETHEUS_BEST_PRACTICES.md` section "Migration Path: VictoriaMetrics"

### Option B: Thanos (Enterprise Alternative)

**Goal:** Multi-cluster metrics with unlimited retention

**Benefits:**
- Multi-cluster global view
- Unlimited retention (S3 storage)
- Downsampling for cost optimization
- High availability

**Cons:**
- More complex (5+ components)
- Higher resource usage (2-4GB RAM total)
- Requires object storage (S3/MinIO)

**Recommendation:** Only if you need:
- Multi-cluster metrics aggregation
- Unlimited retention (>90 days)
- Global query view

**Effort:** 16-24 hours (complex setup)

**See:** `PROMETHEUS_BEST_PRACTICES.md` section "Remote Write (Long-term Storage)"

### Option C: Loki Simple Scalable

**Goal:** Upgrade from SingleBinary to production-ready HA setup

**Current:** SingleBinary (1 pod, no HA)
**Target:** Simple Scalable (3 write + 2 read + 1 backend)

**Benefits:**
- High availability (3 write replicas)
- Horizontal scaling (add more read pods)
- Separate read/write resources

**Prerequisites:**
- Migrate storage to S3/Ceph RGW first
- Increase total RAM budget (1GB → 4GB)

**Effort:** 6-8 hours
**Recommended When:** Log volume exceeds 50GB/day

**See:** `LOKI_BEST_PRACTICES.md` section "Deployment Modes"

---

## Resource Summary

### Current Resource Usage

| Component | Pods | CPU Request | CPU Limit | RAM Request | RAM Limit |
|-----------|------|-------------|-----------|-------------|-----------|
| **Prometheus** | 1 | N/A | N/A | N/A | N/A |
| **Prometheus Operator** | 1 | 100m | 1000m | 256Mi | 1Gi |
| **kube-state-metrics** | 1 | 50m | 500m | 64Mi | 512Mi |
| **Grafana** | 1 | 100m | 500m | 128Mi | 512Mi |
| **Grafana Operator** | 1 | ~100m | ~1000m | ~256Mi | ~1Gi |
| **Loki SingleBinary** | 1 | 100m | 500m | 256Mi | 1Gi |
| **Loki Gateway** | 1 | 25m | 250m | 32Mi | 256Mi |
| **Alertmanager** | 2 | ~200m | ~1000m | ~512Mi | ~1Gi |
| **Keep** | 2 | ~200m | ~1000m | ~512Mi | ~1Gi |
| **Jaeger** | 1 | ~100m | ~500m | ~256Mi | ~512Mi |
| **Robusta** | 1 | ~100m | ~500m | ~256Mi | ~512Mi |

**Total Estimated:**
- **CPU Request:** ~1.2 cores
- **CPU Limit:** ~7 cores (burst capacity)
- **RAM Request:** ~2.5Gi
- **RAM Limit:** ~8Gi (burst capacity)

**Storage:**
- Prometheus: 20Gi (Ceph Block)
- Loki: 10Gi (Ceph Block)
- Grafana: No persistent storage (ephemeral)

**Total Storage:** 30Gi

### Resource Scaling Recommendations

**Current (Homelab - <50GB logs/day, <10k metrics series):**
- ✅ Resources adequate
- ✅ Storage sufficient for 15d metrics + 7d logs

**If scaling to Production (100-500GB logs/day, 50k-100k series):**
- Prometheus: 2 replicas, 4Gi RAM each, 100Gi storage each
- Loki: Migrate to Simple Scalable, 4Gi total RAM, 500Gi S3 storage
- Grafana: Add PVC (5Gi), increase to 1Gi RAM
- VictoriaMetrics: Replace Prometheus (2Gi RAM, 50Gi storage)

---

## Security & Authentication

### Current Security Posture

**Prometheus:**
- ❌ TLS disabled
- ❌ No authentication
- ⚠️ Internal only (not exposed externally)

**Grafana:**
- ❌ Default admin password (not OIDC)
- ⚠️ LoadBalancer exposed
- ✅ OIDC credentials file exists (not enabled)

**Loki:**
- ❌ auth_enabled: false (no multi-tenancy)
- ✅ Internal only (via gateway)

**Alertmanager:**
- ❌ No TLS
- ❌ No authentication
- ✅ Slack webhooks via SealedSecrets (secure)

**Homelab Assessment:**
- ✅ Acceptable for local-only access
- ⚠️ Grafana LoadBalancer needs OIDC for production
- ❌ NOT suitable for internet exposure

**Production Recommendations:**

1. **Enable Grafana OIDC:**
```yaml
# Integrate with Keycloak/Authelia
auth.generic_oauth:
  enabled: true
  client_id: grafana
  auth_url: https://keycloak.timourhomelab.org/...
```

2. **Enable Prometheus TLS:**
```yaml
prometheusOperator:
  tls:
    enabled: true
  admissionWebhooks:
    certManager:
      enabled: true
```

3. **Enable Loki Multi-Tenancy (if needed):**
```yaml
loki:
  auth_enabled: true  # Separate logs per team/namespace
```

---

## Monitoring Best Practices Checklist

### Prometheus

- [x] ServiceMonitor discovery enabled
- [x] Custom alert rules (Tier 0-3)
- [x] Resource limits configured
- [ ] **Explicit retention configuration** ← Quick win
- [ ] HA setup (2+ replicas)
- [ ] Remote write to VictoriaMetrics/Thanos
- [ ] Recording rules for expensive queries
- [ ] TLS enabled
- [ ] Authentication configured

**Status:** 3/9 (33%) - Homelab functional, NOT production-ready

### Grafana

- [x] Grafana Operator deployed
- [x] Datasources configured (Prometheus, Loki, Alertmanager)
- [x] Resource limits configured
- [ ] **Fix datasource UIDs in dashboards** ← CRITICAL
- [ ] Dashboard folder hierarchy (Tier 0-3)
- [ ] OIDC authentication
- [ ] Persistent storage (PVC)
- [ ] Dashboard query optimization

**Status:** 3/8 (38%) - Basic setup complete, dashboards broken

### Loki

- [x] Modern TSDB v13 schema
- [x] Resource limits configured
- [x] Cache configured
- [ ] **Retention policy** ← Quick win
- [ ] **Rate limits** ← Quick win
- [ ] **Migrate to S3/Ceph RGW** ← High priority
- [ ] HA setup (Simple Scalable)
- [ ] Label cardinality audit

**Status:** 3/8 (38%) - Schema correct, storage not production-ready

### Alerting

- [x] Enterprise 4-tier alert system
- [x] Priority-based routing (P1-P5)
- [x] Slack integration
- [x] Keep AIOps + Ollama AI
- [x] Inhibit rules
- [ ] Alert runbooks (links in alerts)
- [ ] PagerDuty integration (optional)

**Status:** 5/7 (71%) - Production-ready alerting

**Overall Homelab Status:** 14/32 (44%) - Functional for homelab, needs work for production

---

## Next Steps

### Immediate Actions (This Week)

1. **Fix Grafana Datasource UIDs** (CRITICAL)
   - Effort: 2-4 hours
   - Impact: All dashboards work immediately
   - See: `GRAFANA_SETUP_GUIDE.md`

2. **Add Explicit Retention Configuration**
   - Prometheus: `retention: 15d`, `retentionSize: "18GB"`
   - Loki: `retention_period: 30d`, `compactor.retention_enabled: true`
   - Effort: 5 minutes
   - Impact: Prevent disk full

3. **Configure Loki Rate Limits**
   - Effort: 5 minutes
   - Impact: Prevent runaway apps

### Short-term Actions (This Month)

4. **Create Dashboard Folder Hierarchy**
   - Effort: 1-2 hours
   - Impact: Professional organization

5. **Migrate Loki to Ceph RGW S3**
   - Effort: 4-6 hours
   - Impact: Production-ready storage
   - See: `LOKI_BEST_PRACTICES.md`

6. **Enable Grafana OIDC** (if Keycloak deployed)
   - Effort: 1 hour
   - Impact: Single Sign-On, better security

### Medium-term Actions (This Quarter)

7. **Enable VictoriaMetrics Remote Write**
   - Effort: 2-4 hours
   - Impact: 3x compression, 50% RAM savings
   - See: `PROMETHEUS_BEST_PRACTICES.md`

8. **Create Recording Rules for Slow Queries**
   - Effort: 4-6 hours
   - Impact: 10x faster dashboard loading

9. **Increase Loki PVC to 50Gi**
   - Effort: 1 hour (includes backup)
   - Impact: Support 30d retention

### Long-term Actions (Next 6 Months)

10. **Migrate to VictoriaMetrics** (full replacement)
    - Effort: 8-12 hours
    - Impact: Better performance, lower cost

11. **Migrate Loki to Simple Scalable**
    - Effort: 6-8 hours
    - Impact: HA, horizontal scaling

12. **Add Thanos** (if multi-cluster needed)
    - Effort: 16-24 hours
    - Impact: Multi-cluster metrics, unlimited retention

---

## Comparison with Elasticsearch Documentation

**Similar Structure:**

| Elasticsearch Docs | Monitoring Docs | Purpose |
|--------------------|-----------------|---------|
| `LICENSE_COMPARISON.md` | `PROMETHEUS_BEST_PRACTICES.md` | Feature comparison, cost analysis |
| `POLICIES_GUIDE.md` | `LOKI_BEST_PRACTICES.md` | Retention policies, storage optimization |
| (N/A) | `GRAFANA_SETUP_GUIDE.md` | Visualization & dashboards |
| (N/A) | `MONITORING_STACK_OVERVIEW.md` | Master guide (you are here) |

**Depth of Analysis:**
- Elasticsearch: 710 lines (POLICIES_GUIDE.md)
- Prometheus: 850+ lines (PROMETHEUS_BEST_PRACTICES.md)
- Grafana: 850+ lines (GRAFANA_SETUP_GUIDE.md)
- Loki: 900+ lines (LOKI_BEST_PRACTICES.md)
- Overview: 600+ lines (this file)

**Total:** ~3,200 lines of comprehensive monitoring documentation

**Coverage:**
- ✅ Current state analysis (like Elasticsearch)
- ✅ Best practices assessment (like Elasticsearch)
- ✅ Migration paths (like Elasticsearch license comparison)
- ✅ Quick wins (like Elasticsearch cold tier optimization)
- ✅ Production readiness checklists (like Elasticsearch)

---

## References

**Monitoring Stack Guides:**
- `PROMETHEUS_BEST_PRACTICES.md` - Metrics collection, retention, VictoriaMetrics migration
- `GRAFANA_SETUP_GUIDE.md` - Visualization, dashboards, OIDC, datasource fixes
- `LOKI_BEST_PRACTICES.md` - Log aggregation, storage migration, label design

**External Documentation:**
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [VictoriaMetrics](https://docs.victoriametrics.com/)
- [Thanos](https://thanos.io/)

**Similar Elasticsearch Documentation:**
- `kubernetes/infrastructure/observability/elasticsearch/LICENSE_COMPARISON.md`
- `kubernetes/infrastructure/observability/elasticsearch/snapshots/POLICIES_GUIDE.md`

---

**Document Version:** 1.0
**Last Updated:** 2025-10-20
**Author:** Enterprise Tier 0 Monitoring Stack Analysis
**Status:** Complete - Ready for implementation
