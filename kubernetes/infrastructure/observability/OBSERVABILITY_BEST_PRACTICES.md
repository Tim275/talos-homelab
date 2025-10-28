# 📊 Observability Best Practices (Grafana Cloud Pattern)

> **Source:** [Grafana Labs Blog](https://grafana.com/blog/) - Making logs work smarter & CI/CD observability

---

## ⚠️ The Logs-First Anti-Pattern

### ❌ **Common Mistake: Logs for Everything**

**What happens:**
```
Developer adds log shipper → Logs to Elasticsearch/Loki
"Great, we're observable now!" 🎉

6 months later:
- Query costs explode 💸
- Dashboards timeout ⏱️
- Fair use limits exceeded 🚨
- Performance degrades 📉
```

**Why it fails:**
- **Cost:** Loki Fair Use = 100x ingestion limit (query 100GB if you ingest 1GB)
- **Performance:** Log queries scan massive data volumes (slow)
- **Scalability:** Over-labeling → index explosion → worse performance

---

## ✅ The Right Approach: Metrics-First

### **Lead with Metrics, Logs for Context**

```
┌─────────────────────────────────────────────────────────┐
│ TIER 1: METRICS (Primary - Fast, Cheap)               │
│ ────────────────────────────────────────────────────── │
│ Use: Dashboards, Alerts, Trend Analysis                │
│ Tool: Prometheus                                        │
│ Cost: Low (time-series, indexed)                       │
│ Query: Instant (<100ms)                                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ TIER 2: TRACES (Context - Medium Cost)                │
│ ────────────────────────────────────────────────────── │
│ Use: Request flow, Service dependencies                │
│ Tool: Jaeger, Tempo                                    │
│ Cost: Medium (sampled data)                            │
│ Query: Fast (structured)                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ TIER 3: LOGS (Deep Dive - Expensive)                  │
│ ────────────────────────────────────────────────────── │
│ Use: Root cause analysis, Debugging, Forensics         │
│ Tool: Loki, Elasticsearch                              │
│ Cost: High (full-text, unindexed)                      │
│ Query: Slow (scan large volumes)                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 When to Use What

### **Metrics (Prometheus) → For:**
- ✅ **Dashboards:** CPU, Memory, Request Rate, Latency
- ✅ **Alerts:** Threshold-based (CPU > 80%, Error Rate > 5%)
- ✅ **Trends:** Historical performance over weeks/months
- ✅ **Aggregations:** `sum()`, `avg()`, `rate()`, `histogram_quantile()`

**Example:**
```promql
# Request rate per service
sum(rate(http_requests_total[5m])) by (service)

# P95 latency
histogram_quantile(0.95, http_request_duration_seconds_bucket)
```

---

### **Traces (Jaeger) → For:**
- ✅ **Request Flow:** See full request path through microservices
- ✅ **Bottlenecks:** Which service is slow?
- ✅ **Dependencies:** How services interact
- ✅ **Error Propagation:** Where did error originate?

**Example:**
```
Request: GET /api/workflow/123
├─ Frontend (50ms)
├─ API Gateway (5ms)
├─ N8N Service (200ms)
│  ├─ PostgreSQL Query (180ms) ← BOTTLENECK!
│  └─ Redis Cache (20ms)
└─ Total: 255ms
```

---

### **Logs (Loki) → For:**
- ✅ **Debugging:** "Why did this specific request fail?"
- ✅ **Root Cause:** Stack traces, error messages, context
- ✅ **Forensics:** "What happened on 2025-10-27 at 14:32:15?"
- ✅ **Compliance:** Audit trails, DSGVO compliance

**Example:**
```logql
# Find errors in N8N service
{namespace="n8n-prod"}
  |= "ERROR"
  | json
  | workflow_id="abc123"
```

**⚠️ Anti-Pattern:**
```logql
# DON'T: Use logs for dashboards/metrics
count_over_time({namespace="n8n-prod"}[24h])  # ❌ EXPENSIVE!

# DO: Use Prometheus metrics instead
sum(rate(n8n_workflow_executions_total[24h]))  # ✅ CHEAP!
```

---

## 🚀 Loki Best Practices

### 1. **Optimize Labels (Critical!)**

**❌ Bad: Over-Labeling**
```yaml
# DON'T: Too many labels = index explosion
{
  namespace="n8n-prod",
  pod="n8n-main-7b5ddf6f9f-89ksv",
  container="n8n",
  workflow_id="abc123",     # ❌ High cardinality!
  user_id="user456",        # ❌ High cardinality!
  request_id="req789"       # ❌ High cardinality!
}
```

**✅ Good: Minimal Labels**
```yaml
# DO: Only index on low-cardinality labels
{
  namespace="n8n-prod",
  app="n8n",
  level="error"
}
# Extract high-cardinality fields via LogQL, not labels!
| json | workflow_id="abc123"
```

**Rule:** Labels = index keys → Keep cardinality LOW (<100 unique values)

---

### 2. **Use LogQL Recording Rules**

**Problem:** Dashboard queries logs 1000x/day → Fair Use exceeded

**Solution:** Precompute with Recording Rules

```yaml
# Vector Aggregator Config
# Compute metrics from logs, store in Prometheus
apiVersion: v1
kind: ConfigMap
metadata:
  name: vector-aggregator-config
data:
  vector.yaml: |
    sources:
      loki:
        type: loki
        address: http://loki:3100

    transforms:
      # Extract error rate from logs
      error_rate:
        type: log_to_metric
        inputs:
          - loki
        metrics:
          - type: counter
            field: message
            name: n8n_errors_total
            namespace: homelab
            tags:
              namespace: "{{ kubernetes.namespace }}"
              app: "{{ kubernetes.app }}"

    sinks:
      prometheus:
        type: prometheus_remote_write
        inputs:
          - error_rate
        endpoint: http://prometheus:9090/api/v1/write
```

**Result:**
- **Before:** Query logs 1000x/day → 100GB scanned
- **After:** Query Prometheus metrics → 10MB scanned (10,000x faster!)

---

### 3. **Filter Early, Filter Often**

**❌ Bad Query:**
```logql
# DON'T: Scan ALL logs first, then filter
{namespace="n8n-prod"}
  | json
  | workflow_id="abc123"
  | level="error"
```

**✅ Good Query:**
```logql
# DO: Filter on labels FIRST
{namespace="n8n-prod", level="error"}
  | json
  | workflow_id="abc123"
```

**Performance:**
- Bad: Scans 1TB logs → Filters → 1MB result
- Good: Filters to 10GB → Scans → 1MB result (100x faster!)

---

### 4. **Narrow Time Ranges**

**❌ Bad:**
```logql
# DON'T: Query 30 days (massive scan)
{namespace="n8n-prod"}[30d]
```

**✅ Good:**
```logql
# DO: Query only what you need
{namespace="n8n-prod"}[1h]  # Last hour
{namespace="n8n-prod"}[5m]  # Last 5 minutes
```

---

## 🔗 GitLab CI/CD → Loki Integration

### **Problem: Isolated CI/CD Visibility**

```
GitLab (CI/CD) → Pipelines, Deployments
Grafana (Observability) → Metrics, Logs, Traces

Challenge: How to correlate deployment events with system performance?
```

**Manual Process (Slow):**
1. Check GitLab for deployment timestamp
2. Switch to Grafana dashboard
3. Manually zoom to deployment time
4. Compare metrics before/after
5. Repeat for each deployment 🤦

---

### **Solution: GitLab Webhooks → Loki**

**Architecture:**
```
┌──────────────┐
│ GitLab       │
│ - Push       │
│ - MR Merge   │
│ - Pipeline   │
│ - Deploy     │
└──────┬───────┘
       │ Webhook
       ▼
┌──────────────────┐
│ AWS Lambda       │
│ (69 lines Python)│
│ - Parse webhook  │
│ - Transform JSON │
└──────┬───────────┘
       │ HTTP POST
       ▼
┌──────────────────┐
│ Loki (Grafana)   │
│ - CI/CD Events   │
│ - Searchable     │
└──────────────────┘
```

**Benefits:**
- **Real-time pipeline monitoring** in Grafana
- **Correlate deployments with metrics** (automatic!)
- **Alert on failed pipelines** via Grafana Alerting
- **Track deployment frequency** (DORA metrics)

---

### **Implementation (Serverless)**

**1. Lambda Function (Python):**
```python
import json
import requests
from datetime import datetime

LOKI_ENDPOINT = "https://logs-prod-us-central1.grafana.net/loki/api/v1/push"
LOKI_USER = "123456"  # From Grafana Cloud
LOKI_API_KEY = "glc_xxxxx"  # From Grafana Cloud

def lambda_handler(event, context):
    webhook = json.loads(event['body'])

    # Extract GitLab event data
    log_entry = {
        "streams": [{
            "stream": {
                "job": "gitlab-webhook",
                "project_name": webhook.get("project", {}).get("name"),
                "object_kind": webhook.get("object_kind"),  # pipeline, merge_request, push
                "ref": webhook.get("ref", "unknown")
            },
            "values": [[
                str(int(datetime.now().timestamp() * 1e9)),  # Nanosecond timestamp
                json.dumps(webhook)
            ]]
        }]
    }

    # Send to Loki
    response = requests.post(
        LOKI_ENDPOINT,
        auth=(LOKI_USER, LOKI_API_KEY),
        headers={"Content-Type": "application/json"},
        data=json.dumps(log_entry)
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Webhook processed')
    }
```

**2. GitLab Webhook Config:**
```
Project Settings → Webhooks
URL: https://your-lambda.execute-api.us-east-1.amazonaws.com/webhook
Trigger: Pipeline events, Merge request events, Push events
Secret Token: <random-token>
```

**3. Grafana Dashboard Query:**
```logql
# Deployment markers
{job="gitlab-webhook"}
  | json
  | object_kind="pipeline"
  | object_attributes_status="success"
  | ref="main"
```

**4. Grafana Alert:**
```logql
# Alert on failed pipelines
count_over_time(
  {job="gitlab-webhook"}
  | json
  | object_kind="pipeline"
  | object_attributes_status="failed"[5m]
) > 0
```

---

### **Grafana Dashboard with Deployment Annotations**

```json
{
  "annotations": {
    "list": [
      {
        "datasource": "Loki",
        "enable": true,
        "expr": "{job=\"gitlab-webhook\"} | json | object_kind=\"pipeline\" | object_attributes_status=\"success\" | ref=\"main\"",
        "iconColor": "green",
        "name": "Deployments",
        "textFormat": "{{project_name}} deployed"
      }
    ]
  }
}
```

**Result:**
- Deployment markers on all dashboards
- Click marker → See commit hash, author, pipeline URL
- Correlate performance changes with specific deployments

---

## 📊 DORA Metrics via LogQL

**4 Key Metrics:**

### 1. **Deployment Frequency**
```logql
# Deployments per day
sum(
  count_over_time(
    {job="gitlab-webhook"}
    | json
    | object_kind="pipeline"
    | object_attributes_status="success"[24h]
  )
)
```

### 2. **Lead Time for Changes**
```logql
# Time from commit to deploy
avg(
  {job="gitlab-webhook"}
  | json
  | object_kind="pipeline"
  | object_attributes_duration
)
```

### 3. **Change Failure Rate**
```logql
# Failed pipelines / Total pipelines
sum(
  count_over_time(
    {job="gitlab-webhook"}
    | json
    | object_kind="pipeline"
    | object_attributes_status="failed"[7d]
  )
)
/
sum(
  count_over_time(
    {job="gitlab-webhook"}
    | json
    | object_kind="pipeline"[7d]
  )
) * 100
```

### 4. **Mean Time to Recovery (MTTR)**
```logql
# Time between failed and fixed pipeline
# (Requires correlation of failed → success events)
```

---

## 🎯 Observability Stack Recommendations

### **Dein aktuelles Setup:**
```
✅ Prometheus → Metrics (kube-prometheus-stack)
✅ Loki → Logs (vector → loki)
✅ Jaeger → Traces (opentelemetry)
✅ Grafana → Dashboards, Alerts
```

### **Fehlende Integration:**
```
⏳ GitLab CI/CD Events → Loki
   └─ Deployment correlation
   └─ DORA metrics
   └─ Pipeline alerts
```

---

## 📚 Implementation Checklist

### **Phase 1: Optimize Existing Loki (Now)**
- [ ] Review Loki label cardinality (`kubectl exec -n monitoring loki-0 -- logcli labels`)
- [ ] Remove high-cardinality labels (user_id, request_id, etc.)
- [ ] Create LogQL recording rules for dashboard queries
- [ ] Add fair use dashboard (monitor query volume)

### **Phase 2: GitLab → Loki Integration (Optional)**
- [ ] Deploy AWS Lambda function (or Kubernetes Job)
- [ ] Configure GitLab webhooks (Pipeline, MR, Push events)
- [ ] Create Grafana dashboard with deployment annotations
- [ ] Set up alerts for failed pipelines
- [ ] Build DORA metrics dashboard

### **Phase 3: Metrics-First Migration**
- [ ] Identify dashboards querying logs (not metrics)
- [ ] Migrate to Prometheus queries where possible
- [ ] Use logs only for detail views (not overviews)
- [ ] Document when to use metrics vs. logs vs. traces

---

## 💡 Key Takeaways

1. **Lead with Metrics** → Logs for context, not primary monitoring
2. **Loki Labels** → Low cardinality (<100 unique values), filter in LogQL
3. **Recording Rules** → Precompute expensive log queries as metrics
4. **GitLab Integration** → Correlate deployments with system performance
5. **Fair Use Awareness** → 100x query limit, monitor usage

**Next Steps:**
1. Read: `infrastructure/observability/README.md` (Loki config)
2. Monitor: Fair use dashboard (avoid overages)
3. Optimize: Replace log queries with Prometheus metrics

---

**Sources:**
- [Making logs work smarter (Grafana Blog)](https://grafana.com/blog/2025/10/20/making-logs-work-smarter/)
- [GitLab CI/CD observability (Grafana Blog)](https://grafana.com/blog/2025/10/10/gitlab-loki-integration/)
- [Loki Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
