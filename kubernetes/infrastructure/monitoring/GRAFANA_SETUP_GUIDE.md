# Grafana Setup Guide - Enterprise Best Practices

## Current State Analysis

### Deployment Configuration

**Deployment Method:** Grafana Operator v5.19.1
**Grafana Version:** 12.1.0
**Namespace:** grafana
**Service Type:** LoadBalancer (port 3000)
**Authentication:** Default admin secret enabled (no OIDC)
**Storage:** No persistent storage configured (ephemeral)

### Resource Configuration

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Status:** Good for homelab (5x burst capacity)

### Datasources

**Configured Datasources:**
1. **Prometheus** (default)
   - URL: `http://prometheus-operated.monitoring.svc.cluster.local:9090`
   - UID: `bcc9d3ee-2926-4b20-b364-f067529673ff`
   - Default: Yes
   - Scrape interval: 30s

2. **Loki** (logs)
   - URL: `http://loki-gateway.monitoring.svc.cluster.local:80`
   - UID: `d2b40721-7276-43cf-afbc-d064116217e4`
   - Max lines: 1000
   - Timeout: 60s

3. **Alertmanager** (alerting)
   - URL: `http://alertmanager-operated.monitoring.svc.cluster.local:9093`
   - UID: `4a200eff-39ee-4f38-9608-28b9e8535176`
   - Implementation: prometheus

**Status:** All datasources synchronized successfully

### Dashboard Organization

**Current Dashboards (Sample):**
- k8s-cluster-overview
- node-exporter-full
- ceph-cluster-overview
- argocd-overview

**Total Dashboards:** 4 visible in status (likely more deployed via ConfigMaps)

**Dashboard Sources:**
- GrafanaDashboard CRDs (Operator-managed)
- ConfigMaps (kustomize-based deployment)
- Manual imports (ephemeral, lost on restart)

---

## Best Practices Assessment

### 1. Deployment Method: Operator vs Helm

**Current:** Grafana Operator
**Status:** Excellent choice for Kubernetes-native GitOps

**Comparison:**

| Feature | Grafana Operator | Helm Chart |
|---------|-----------------|------------|
| **Dashboard as Code** | ✅ GrafanaDashboard CRD | ❌ ConfigMaps + sidecar |
| **Datasource as Code** | ✅ GrafanaDatasource CRD | ❌ Manual JSON in values |
| **GitOps Native** | ✅ Kubernetes-native | ⚠️ Requires sidecar container |
| **Multi-instance** | ✅ Multiple Grafana instances | ❌ One per namespace |
| **Complexity** | ⚠️ Higher (Operator + CRDs) | ✅ Simpler (single Helm release) |
| **Resource Usage** | ⚠️ Operator overhead (~100MB) | ✅ Lower (no operator) |

**Recommendation:** Keep Grafana Operator for homelab
- You're already using it successfully
- GrafanaDashboard CRDs are cleaner than sidecar pattern
- Aligns with ArgoCD GitOps workflow

### 2. Datasource Configuration

**Current State:** GrafanaDatasource CRDs
**Status:** Excellent - Kubernetes-native approach

**CRITICAL ISSUE:** Datasource UID mismatch in dashboards

**Problem:** User reported many broken dashboards with "datasource not found"

**Root Cause:** Dashboard JSONs reference wrong datasource UIDs

**Example Issue:**
```json
// Dashboard references non-existent UID
{
  "datasource": {
    "type": "prometheus",
    "uid": "WRONG_UID_12345"  // ❌ Not found
  }
}
```

**Solution - Best Practice Datasource References:**

**Method 1: Use datasource name (Recommended)**
```json
{
  "datasource": "Prometheus"  // References datasource by name
}
```

**Method 2: Use dashboard variables**
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "${DS_PROMETHEUS}"  // Variable defined in dashboard
  }
}
```

**Method 3: Use explicit UID (least flexible)**
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "bcc9d3ee-2926-4b20-b364-f067529673ff"  // Hardcoded
  }
}
```

**Recommendation:**
- ✅ Use datasource names for portability
- ✅ Use variables for multi-env dashboards
- ❌ Avoid hardcoded UIDs (breaks when datasource recreated)

**Fix Required:** Audit all GrafanaDashboard resources and fix UID references

```bash
# Find dashboards with datasource references
kubectl get grafanadashboard -A -o yaml | grep -A5 '"datasource"'

# Check for UID mismatches
# Compare against current datasource UIDs:
# prometheus: bcc9d3ee-2926-4b20-b364-f067529673ff
# loki: d2b40721-7276-43cf-afbc-d064116217e4
# alertmanager: 4a200eff-39ee-4f38-9608-28b9e8535176
```

### 3. Dashboard Organization

**Current State:** Flat structure (no folder organization)
**Status:** Needs improvement

**Best Practice - Enterprise Dashboard Hierarchy:**

```
Grafana Dashboards/
├── Tier 0 - Control Plane/
│   ├── Kubernetes API Server
│   ├── ETCD Cluster Health
│   ├── Controller Manager
│   └── Scheduler Performance
│
├── Tier 1 - Infrastructure/
│   ├── Node Overview
│   ├── Talos System
│   ├── Cilium Network
│   ├── ArgoCD GitOps
│   └── Cert-Manager SSL
│
├── Tier 2 - Storage/
│   ├── Ceph Cluster Overview
│   ├── Ceph Pool Details
│   ├── Velero Backup
│   └── PostgreSQL (CNPG)
│
├── Tier 3 - Applications/
│   ├── N8N Automation
│   ├── Audiobookshelf Media
│   ├── Kafka Streaming
│   └── Elasticsearch Logs
│
└── Executive/
    ├── Homelab Overview
    └── Resource Costs
```

**Implementation via GrafanaFolder CRD:**

```yaml
# kubernetes/infrastructure/monitoring/grafana/folders/tier0-control-plane.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaFolder
metadata:
  name: tier0-control-plane
  namespace: grafana
spec:
  instanceSelector:
    matchLabels:
      app: grafana
  title: "Tier 0 - Control Plane"
  permissions:
    - role: Viewer
      permission: view
    - role: Editor
      permission: edit
```

**Dashboard Assignment:**

```yaml
# kubernetes/infrastructure/monitoring/grafana/dashboards/tier0/k8s-api-server.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: k8s-api-server
  namespace: grafana
spec:
  instanceSelector:
    matchLabels:
      app: grafana
  folder: tier0-control-plane  # Assign to folder
  json: |
    {
      "title": "Kubernetes API Server",
      ...
    }
```

**Benefit:**
- Clear visual hierarchy in Grafana UI
- Easy navigation (Tier 0 → Tier 1 → Tier 2 → Tier 3)
- Aligns with alerting priority levels (P1-P5)

### 4. Monitoring Methodologies

**Enterprise Standard Approaches:**

#### A. Golden Signals (Google SRE)

**Applicable to:** User-facing services (N8N, Audiobookshelf, APIs)

**4 Key Metrics:**
1. **Latency:** Request duration (P50, P95, P99)
2. **Traffic:** Requests per second
3. **Errors:** Error rate (4xx, 5xx)
4. **Saturation:** Resource utilization (CPU, memory, disk)

**Example Dashboard Panels:**

```promql
# Latency (P95)
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{job="n8n"}[5m])) by (le)
)

# Traffic (RPS)
sum(rate(http_requests_total{job="n8n"}[5m]))

# Errors (error rate)
sum(rate(http_requests_total{job="n8n", status=~"5.."}[5m]))
/ sum(rate(http_requests_total{job="n8n"}[5m]))

# Saturation (CPU usage)
rate(process_cpu_seconds_total{job="n8n"}[5m])
```

#### B. RED Method (Services)

**Applicable to:** Microservices, APIs

**3 Key Metrics:**
1. **Rate:** Requests per second
2. **Errors:** Failed requests per second
3. **Duration:** Latency distribution (P50, P95, P99)

**vs Golden Signals:**
- RED = Golden Signals minus Saturation
- Simpler, focused on request flow
- Best for Istio/service mesh environments

#### C. USE Method (Resources)

**Applicable to:** Infrastructure (nodes, disks, network)

**3 Key Metrics:**
1. **Utilization:** % busy (CPU, memory, disk)
2. **Saturation:** Queue depth, wait time
3. **Errors:** Error count (failed requests, retries)

**Example Dashboard Panels:**

```promql
# Utilization (CPU)
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Saturation (Load average)
node_load15 / count(node_cpu_seconds_total{mode="idle"}) by (instance)

# Errors (disk errors)
rate(node_disk_io_errors_total[5m])
```

**Recommendation for Homelab:**
- **Tier 0-1:** USE Method (infrastructure focus)
- **Tier 2:** Golden Signals (storage services)
- **Tier 3:** RED Method (application services)

### 5. Grafana OSS vs Enterprise

**Current:** Grafana OSS v12.1.0
**Status:** Sufficient for homelab

**Feature Comparison:**

| Feature | OSS (Free) | Enterprise ($$$) |
|---------|-----------|------------------|
| **Dashboards** | ✅ Unlimited | ✅ Unlimited |
| **Datasources** | ✅ All major | ✅ Premium (Oracle, SAP) |
| **Alerting** | ✅ Unified Alerting | ✅ + Enterprise plugins |
| **RBAC** | ⚠️ Basic (Viewer/Editor/Admin) | ✅ Fine-grained teams |
| **OIDC/SAML** | ✅ OAuth2 | ✅ SAML SSO |
| **Reporting** | ❌ None | ✅ PDF/PNG scheduled reports |
| **Audit Logs** | ❌ None | ✅ Full audit trail |
| **Support** | ❌ Community | ✅ Enterprise SLA |
| **Multi-tenancy** | ⚠️ Basic orgs | ✅ Full isolation |
| **Cost** | Free | $10-100/user/month |

**Enterprise Features Worth Paying For:**
- **Reporting:** Scheduled PDF dashboards (management visibility)
- **RBAC:** Fine-grained permissions (>100 users)
- **Audit Logs:** Compliance requirements (SOC2, GDPR)
- **Support:** 24/7 SLA (mission-critical systems)

**Homelab Decision:** Stay on OSS
- You don't need enterprise features
- OAuth2 OIDC works fine for authentication
- Save $120-1200/year

### 6. Authentication & OIDC

**Current State:** Default admin password (insecure)
**Status:** ❌ NOT production-ready

**Production Recommendation:** Enable OIDC with Keycloak/Authelia

```yaml
# kubernetes/infrastructure/monitoring/grafana/grafana.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  namespace: grafana
spec:
  config:
    server:
      root_url: https://grafana.timourhomelab.org
    auth:
      disable_login_form: false  # Keep admin login for emergencies
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      client_id: grafana
      client_secret_file: /etc/secrets/oidc/client-secret
      scopes: openid profile email groups
      auth_url: https://keycloak.timourhomelab.org/auth/realms/homelab/protocol/openid-connect/auth
      token_url: https://keycloak.timourhomelab.org/auth/realms/homelab/protocol/openid-connect/token
      api_url: https://keycloak.timourhomelab.org/auth/realms/homelab/protocol/openid-connect/userinfo
      role_attribute_path: contains(groups[*], 'grafana-admins') && 'Admin' || contains(groups[*], 'grafana-editors') && 'Editor' || 'Viewer'
  deployment:
    spec:
      template:
        spec:
          volumes:
            - name: oidc-secret
              secret:
                secretName: grafana-oidc-credentials
          containers:
            - name: grafana
              volumeMounts:
                - name: oidc-secret
                  mountPath: /etc/secrets/oidc
                  readOnly: true
```

**OIDC Group Mapping:**
- `grafana-admins` → Grafana Admin role
- `grafana-editors` → Grafana Editor role
- Default → Grafana Viewer role

**Benefits:**
- Single Sign-On (SSO) with Keycloak/Authelia
- LDAP integration via Keycloak
- MFA support (2FA)
- Centralized user management

**Homelab Decision:**
- ⚠️ Currently disabled (easier initial setup)
- ✅ Enable if you have Keycloak deployed
- ✅ File exists: `kubernetes/infrastructure/monitoring/grafana/oidc-credentials.yaml`

### 7. Persistent Storage

**Current State:** No persistent storage (ephemeral)
**Impact:** Manual dashboard changes lost on pod restart

**Issue:** Dashboard annotations, user preferences, API keys lost

**Recommendation:** Enable persistent storage

```yaml
# kubernetes/infrastructure/monitoring/grafana/grafana.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  namespace: grafana
spec:
  persistentVolumeClaim:
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi  # SQLite database + user uploads
      storageClassName: rook-ceph-block-enterprise
```

**What gets persisted:**
- User preferences (theme, timezone, home dashboard)
- API keys and service accounts
- Dashboard annotations (manual comments)
- Alert notification channels (if not using CRDs)

**What does NOT need persistence (Operator-managed):**
- Dashboards (managed via GrafanaDashboard CRDs)
- Datasources (managed via GrafanaDatasource CRDs)
- Alert rules (managed via PrometheusRule CRDs)

**Homelab Decision:**
- ⚠️ Currently ephemeral (simpler, immutable)
- ✅ Enable if you make manual changes via UI
- ❌ Skip if you manage everything via GitOps

### 8. Performance Optimization

**Current Resources:**
- Request: 100m CPU / 128Mi RAM
- Limit: 500m CPU / 512Mi RAM

**Status:** Good for homelab (<100 users)

**Optimization Strategies:**

#### A. Dashboard Query Optimization

**Problem:** Slow dashboard loading (user complaint)

**Common Causes:**
1. Too many panels (>30 panels per dashboard)
2. Long time ranges (30d queries on every page load)
3. High-resolution queries (1s interval for 30d range)
4. Complex regex in queries

**Solutions:**

**1. Use recording rules for expensive queries:**
```yaml
# Create pre-aggregated metrics
- record: namespace:pod_cpu_usage:sum
  expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace, pod)
```

**2. Limit dashboard time range:**
```json
{
  "time": {
    "from": "now-6h",  // Not "now-30d"!
    "to": "now"
  },
  "refresh": "30s"  // Auto-refresh interval
}
```

**3. Use $__rate_interval instead of hardcoded intervals:**
```promql
# BAD: Hardcoded 5m
rate(http_requests_total[5m])

# GOOD: Dynamic based on scrape interval
rate(http_requests_total[$__rate_interval])
```

**4. Reduce panel resolution:**
```json
{
  "maxDataPoints": 1000,  // Not 10000!
  "interval": "30s"       // Match Prometheus scrape interval
}
```

#### B. Query Caching

**Enable datasource caching:**

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: prometheus
  namespace: grafana
spec:
  datasource:
    name: Prometheus
    type: prometheus
    url: http://prometheus-operated.monitoring.svc.cluster.local:9090
    jsonData:
      timeInterval: 30s
      queryTimeout: 60s
      cacheLevel: Medium  # Enable query caching
```

**Benefit:** Repeated queries cached for 1 minute

#### C. Dashboard Best Practices

**Panel Limits:**
- **Homelab:** <20 panels per dashboard
- **Production:** <30 panels per dashboard
- **Executive:** <10 panels (high-level only)

**Query Limits:**
- **Time Range:** Default 6h (not 30d!)
- **Refresh:** 30s minimum (not 5s)
- **Resolution:** maxDataPoints = 1000

**Row Collapse:**
- Group related panels in collapsible rows
- Load on-demand (not all at once)

### 9. Alerting (Unified Alerting vs Prometheus)

**Current State:** Using Prometheus Alertmanager
**Status:** Correct approach

**Grafana Unified Alerting vs Prometheus Alerting:**

| Feature | Grafana Unified Alerting | Prometheus Alertmanager |
|---------|-------------------------|------------------------|
| **Alert Source** | Any datasource (Loki, Influx, etc.) | Prometheus only |
| **Alert Storage** | Grafana DB | Prometheus TSDB |
| **Notification Channels** | Grafana UI | Alertmanager YAML |
| **Silences** | Grafana UI | Alertmanager UI |
| **Kubernetes Native** | ❌ CRDs not mature | ✅ PrometheusRule CRD |
| **GitOps Friendly** | ⚠️ DB-based | ✅ YAML-based |
| **Multi-datasource** | ✅ Yes | ❌ Prometheus only |

**Recommendation:** Keep using Prometheus Alertmanager
- You already have enterprise alert rules (Tier 0-3)
- PrometheusRule CRDs are GitOps-native
- Alertmanager config in values.yaml (IaC)
- Unified Alerting better for multi-datasource alerts

**When to use Grafana Unified Alerting:**
- Alert on Loki logs (log-based alerts)
- Alert on InfluxDB metrics
- Alert on SQL queries (PostgreSQL datasource)

---

## Enterprise Dashboard Design Patterns

### 1. Executive Dashboard (C-Level)

**Target Audience:** Non-technical management
**Refresh:** 5min (no real-time)
**Metrics:** 6-8 high-level KPIs only

**Example Panels:**
- Overall cluster health (% uptime)
- Cost per month (resource costs)
- Incident count (P1-P5 alerts)
- Service SLIs (99.9% availability)

**Design Principles:**
- ✅ Big numbers (stat panels)
- ✅ Red/green colors (health status)
- ✅ Trend arrows (↑ ↓)
- ❌ No complex graphs
- ❌ No technical jargon

### 2. Operational Dashboard (SRE/DevOps)

**Target Audience:** Operations engineers
**Refresh:** 10-30s
**Metrics:** 15-25 panels

**Example Panels:**
- Request rate (RED method)
- Error rate (P95 latency)
- Resource utilization (USE method)
- Alert status (firing/pending)

**Design Principles:**
- ✅ Time series graphs
- ✅ Multiple queries per panel
- ✅ Thresholds (yellow/red lines)
- ✅ Drill-down links

### 3. Debugging Dashboard (On-Call)

**Target Audience:** Incident responders
**Refresh:** 5s (real-time)
**Metrics:** 30-50 panels (collapsible rows)

**Example Panels:**
- Full request trace (Jaeger)
- Log correlation (Loki)
- Resource heatmaps
- Network flows (Hubble)

**Design Principles:**
- ✅ High-resolution data
- ✅ Log panels (Loki datasource)
- ✅ Trace links (Jaeger)
- ✅ Ad-hoc queries (explore mode)

---

## Troubleshooting Guide

### Issue: "Datasource not found" in dashboards

**Root Cause:** Dashboard references wrong datasource UID

**Solution:**

1. Get current datasource UIDs:
```bash
kubectl get grafanadatasources -n grafana -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.uid}{"\n"}{end}'
```

Output:
```
prometheus      bcc9d3ee-2926-4b20-b364-f067529673ff
loki            d2b40721-7276-43cf-afbc-d064116217e4
alertmanager    4a200eff-39ee-4f38-9608-28b9e8535176
```

2. Update dashboard JSON to use datasource name instead of UID:
```json
{
  "datasource": "Prometheus"  // Use name, not UID
}
```

3. Or update dashboard to use correct UID:
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "bcc9d3ee-2926-4b20-b364-f067529673ff"
  }
}
```

### Issue: Dashboard loading slow (>10 seconds)

**Solution:**

1. Check query performance in Explore mode
2. Create recording rules for expensive queries
3. Reduce time range (6h instead of 30d)
4. Reduce maxDataPoints (1000 instead of 10000)
5. Enable datasource caching

### Issue: Panels show "No data"

**Possible Causes:**

1. **ServiceMonitor not scraped:**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Open http://localhost:9090/targets
```

2. **Wrong namespace in query:**
```promql
# Make sure namespace matches
kube_pod_info{namespace="monitoring"}  # Correct namespace?
```

3. **Time range issue:**
- Check dashboard time range (top-right corner)
- Data might be outside selected range

4. **Metric name typo:**
```bash
# List available metrics
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -- \
  promtool query instant http://localhost:9090 '{__name__=~"kube.*"}'
```

---

## Quick Wins for Homelab

### 1. Fix Datasource UIDs in All Dashboards

**Problem:** User reports many dashboards showing "datasource not found"

**Action:**
```bash
# Find all dashboards
kubectl get grafanadashboard -A

# Check each dashboard's datasource references
# Update to use datasource names instead of UIDs
```

**Benefit:** All dashboards work immediately

### 2. Create Dashboard Folder Hierarchy

**Action:**
1. Create GrafanaFolder resources (Tier 0-3, Executive)
2. Assign existing dashboards to folders
3. Clean visual organization

**Benefit:** Easy navigation, professional appearance

### 3. Enable OIDC Authentication (If Keycloak Deployed)

**Action:**
1. Check if `grafana-oidc-credentials` secret exists
2. Update Grafana config to enable OIDC
3. Test SSO login

**Benefit:** Single Sign-On, centralized user management

### 4. Add Persistent Storage

**Action:**
1. Add PVC configuration to Grafana CR
2. Restart Grafana pod
3. User preferences persist across restarts

**Benefit:** Manual changes not lost

---

## Production Readiness Checklist

- [x] **Deployment Method:** Grafana Operator (Kubernetes-native)
- [x] **Resource Limits:** Configured (100m/128Mi → 500m/512Mi)
- [x] **Datasources:** All configured (Prometheus, Loki, Alertmanager)
- [ ] **Datasource UIDs:** Fix dashboard references (CRITICAL)
- [ ] **Dashboard Organization:** Create folder hierarchy
- [ ] **OIDC Authentication:** Enable for production
- [ ] **Persistent Storage:** Add PVC for user data
- [ ] **Dashboard Best Practices:** Optimize slow queries
- [ ] **Alerting:** Using Prometheus Alertmanager (correct)
- [ ] **Backup:** Export dashboards via CRDs (GitOps)

**Homelab Status:**
- ✅ Grafana Operator deployed successfully
- ✅ Datasources configured and synchronized
- ✅ Resource limits appropriate for homelab
- ⚠️ **CRITICAL:** Datasource UID mismatch causing broken dashboards
- ⚠️ No folder organization (flat structure)
- ❌ No OIDC authentication (using default admin)
- ❌ No persistent storage (ephemeral)

**Recommended Next Steps:**
1. **CRITICAL:** Fix datasource UIDs in all dashboards
2. Create dashboard folder hierarchy (Tier 0-3, Executive)
3. Optimize slow dashboard queries (recording rules)
4. Enable OIDC if Keycloak available

---

## References

- [Grafana Operator Documentation](https://grafana.github.io/grafana-operator/)
- [Grafana Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Dashboard Design Best Practices](https://grafana.com/docs/grafana/latest/best-practices/dashboard-design/)
- [OIDC Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/)
- [Prometheus Datasource](https://grafana.com/docs/grafana/latest/datasources/prometheus/)
