# 🏢 ENTERPRISE TIER-0 LOGGING ARCHITECTURE

## 📋 **TABLE OF CONTENTS**

1. [Current State Analysis](#current-state-analysis)
2. [Enterprise Logging Principles](#enterprise-logging-principles)
3. [What Should Be Logged](#what-should-be-logged)
4. [Elasticsearch Index Strategy](#elasticsearch-index-strategy)
5. [Kibana Data Views Setup](#kibana-data-views-setup)
6. [Log Retention & ILM Policies](#log-retention--ilm-policies)
7. [Dashboards & Visualizations](#dashboards--visualizations)
8. [Troubleshooting & Operations](#troubleshooting--operations)

---

## 🔍 **CURRENT STATE ANALYSIS**

### **✅ What You Have (Already Production-Grade!):**

```
┌──────────────────────────────────────────────────────────────┐
│ TIER 0: LOG COLLECTION (Vector)                             │
├──────────────────────────────────────────────────────────────┤
│ ✅ Vector Agent (DaemonSet - 7 pods, 1 per node)            │
│    └─ Collects: /var/log/pods, /var/log/containers          │
│ ✅ Vector Aggregator (Deployment - 2 replicas HA)           │
│    └─ Enriches: ECS fields, trace IDs, severity mapping     │
├──────────────────────────────────────────────────────────────┤
│ TIER 1: LOG STORAGE (Elasticsearch)                         │
├──────────────────────────────────────────────────────────────┤
│ ✅ Elasticsearch 8.x (3-node cluster)                        │
│ ✅ Data Streams (automatic rollover)                         │
│ ✅ ECS 8.17 compliant fields                                 │
├──────────────────────────────────────────────────────────────┤
│ TIER 2: LOG VISUALIZATION (Kibana)                          │
├──────────────────────────────────────────────────────────────┤
│ ✅ Kibana 8.x (production-ready)                             │
│ ⚠️  Data Views: NEEDS SETUP                                  │
│ ⚠️  Dashboards: NEEDS CREATION                               │
└──────────────────────────────────────────────────────────────┘
```

### **Current Data Streams (Service-Based Routing):**

Your logs are already being routed to **service-specific data streams**:

```
logs-{service}.{severity}-default

Examples:
  logs-argocd.info-default
  logs-argocd.critical-default
  logs-rook-ceph.info-default
  logs-n8n-prod.info-default
  logs-kafka.warn-default
```

**✅ This is EXCELLENT!** Service-based routing is an enterprise best practice.

---

## 🎯 **ENTERPRISE LOGGING PRINCIPLES**

### **1. Separation of Concerns (Tier-based Architecture)**

```
TIER 0: INFRASTRUCTURE
  └─ kube-system, rook-ceph, cilium, cert-manager

TIER 1: PLATFORM SERVICES
  └─ argocd, istio, elastic-system, monitoring

TIER 2: DATA SERVICES
  └─ kafka, postgresql (cnpg), redis

TIER 3: APPLICATION SERVICES
  └─ n8n, audiobookshelf, boutique

TIER 4: SECURITY & IDENTITY
  └─ authelia, keycloak, lldap, sealed-secrets
```

### **2. Severity-Based Routing**

```
CRITICAL: Errors, Failures, Crashes
  └─ Retention: 90 days
  └─ Alerting: YES

WARN: Warnings, Deprecations
  └─ Retention: 30 days
  └─ Alerting: Optional

INFO: Normal operations
  └─ Retention: 7 days
  └─ Alerting: NO

DEBUG: Troubleshooting
  └─ Retention: 1 day
  └─ Alerting: NO
```

### **3. ECS (Elastic Common Schema) Compliance**

All logs follow **ECS 8.17** standard fields:

```json
{
  "@timestamp": "2025-10-19T20:00:00Z",
  "ecs.version": "8.17",
  "log.level": "error",
  "service.name": "n8n-prod",
  "service.environment": "production",
  "message": "Database connection failed",
  "trace.id": "abc123...",  // OpenTelemetry correlation
  "error.message": "Connection timeout"
}
```

---

## 📦 **WHAT SHOULD BE LOGGED?**

### **TIER 0: Infrastructure (CRITICAL - Always Log)**

| Service | Why Log? | Critical Fields |
|---------|----------|-----------------|
| **kube-system** | Cluster health, API server, scheduler, controller-manager | `pod`, `node`, `component` |
| **rook-ceph** | Storage health, OSD status, PG health | `osd_id`, `pg_id`, `pool` |
| **cilium** | Network policies, connectivity, L3/L4 | `src_ip`, `dst_ip`, `policy` |
| **cert-manager** | Certificate renewals, Let's Encrypt errors | `cert_name`, `issuer` |
| **cnpg (PostgreSQL)** | Database backups, failovers, replication lag | `cluster`, `replica`, `lag_bytes` |

### **TIER 1: Platform Services (HIGH PRIORITY)**

| Service | Why Log? | Critical Fields |
|---------|----------|-----------------|
| **ArgoCD** | Deployment failures, sync errors, app health | `app`, `sync_status`, `health` |
| **Istio** | Service mesh errors, mTLS failures, traffic | `src_service`, `dst_service`, `http_code` |
| **Elastic-System** | Vector pipeline errors, Elasticsearch indexing | `index`, `bulk_errors` |
| **Monitoring** | Prometheus scrape errors, Alertmanager firing | `scrape_target`, `alert_name` |

### **TIER 2: Data Services (MEDIUM PRIORITY)**

| Service | Why Log? | Critical Fields |
|---------|----------|-----------------|
| **Kafka** | Partition lag, consumer errors, broker health | `topic`, `partition`, `consumer_group` |
| **Redis** | Connection pool exhaustion, eviction | `db`, `evicted_keys` |

### **TIER 3: Application Services (APPLICATION-SPECIFIC)**

| Service | Why Log? | Critical Fields |
|---------|----------|-----------------|
| **N8N** | Workflow executions, webhook errors | `workflow_id`, `execution_id`, `user_id` |
| **Audiobookshelf** | User auth, media streaming errors | `user_id`, `media_id` |
| **Boutique** | Cart operations, checkout failures | `transaction_id`, `user_id`, `cart_id` |

### **TIER 4: Security & Identity (AUDIT - Always Log)**

| Service | Why Log? | Critical Fields |
|---------|----------|-----------------|
| **Authelia** | Login attempts, failed auth, 2FA | `user`, `ip_address`, `auth_method` |
| **Keycloak** | SSO logins, token generation, client errors | `client_id`, `user`, `realm` |
| **LLDAP** | LDAP binds, group changes | `dn`, `operation` |

---

## 🗂️ **ELASTICSEARCH INDEX STRATEGY**

### **Current Strategy: Service + Severity (GOOD!)**

```
Pattern: logs-{service}.{severity}-default

Examples:
  logs-argocd.critical-default
  logs-argocd.info-default
  logs-rook-ceph.critical-default
  logs-n8n-prod.info-default
```

### **Recommended Improvement: Add Environment**

```
Pattern: logs-{environment}.{tier}.{service}.{severity}-default

Examples:
  logs-prod.platform.argocd.critical-default
  logs-prod.infra.rook-ceph.critical-default
  logs-prod.app.n8n-prod.critical-default
  logs-prod.security.authelia.critical-default
```

**Benefits:**
- ✅ Multi-environment support (dev/staging/prod)
- ✅ Tier-based dashboards
- ✅ Better access control (dev team can't see security logs)

### **Data Stream Naming Convention:**

```toml
# Vector Aggregator Config Enhancement
data_stream.type = "logs"
data_stream.dataset = "{{ environment }}.{{ tier }}.{{ service }}.{{ severity }}"
data_stream.namespace = "default"
```

---

## 🔍 **KIBANA DATA VIEWS SETUP**

### **Step 1: Login to Kibana**

```bash
# Port-forward Kibana
kubectl port-forward -n elastic-system svc/production-kibana-kb-http 5601:5601

# Open browser
https://localhost:5601

# Login credentials
Username: elastic
Password: 9ry0V5G4h72NUi02rjIP50yI
```

### **Step 2: Create Data Views**

Go to **Stack Management** → **Data Views** → **Create Data View**

#### **🎯 TIER 0: Infrastructure Data View**

```
Name: [TIER-0] Infrastructure Logs
Index pattern: logs-*kube-system*,logs-*rook-ceph*,logs-*cilium*,logs-*cert-manager*
Time field: @timestamp
```

**Fields to Index:**
- `@timestamp` (time)
- `log.level` (keyword)
- `service.name` (keyword)
- `kubernetes.namespace` (keyword)
- `kubernetes.pod_name` (keyword)
- `kubernetes.node_name` (keyword)
- `message` (text)
- `error.message` (text)

#### **🎯 TIER 1: Platform Services Data View**

```
Name: [TIER-1] Platform Services
Index pattern: logs-*argocd*,logs-*istio*,logs-*elastic-system*,logs-*monitoring*
Time field: @timestamp
```

#### **🎯 TIER 2: Data Services Data View**

```
Name: [TIER-2] Data Services
Index pattern: logs-*kafka*,logs-*cloudnative-pg*,logs-*redis*
Time field: @timestamp
```

#### **🎯 TIER 3: Applications Data View**

```
Name: [TIER-3] Applications
Index pattern: logs-*n8n*,logs-*audiobookshelf*,logs-*boutique*
Time field: @timestamp
```

#### **🎯 TIER 4: Security & Identity Data View**

```
Name: [TIER-4] Security & Identity
Index pattern: logs-*authelia*,logs-*keycloak*,logs-*lldap*
Time field: @timestamp
```

#### **🔥 CRITICAL ERRORS (ALL TIERS)**

```
Name: [CRITICAL] All Cluster Errors
Index pattern: logs-*.critical-*
Time field: @timestamp
```

#### **⚠️ WARNINGS (ALL TIERS)**

```
Name: [WARN] All Cluster Warnings
Index pattern: logs-*.warn-*
Time field: @timestamp
```

#### **🔍 FULL CLUSTER VIEW (ALL LOGS)**

```
Name: [ALL] Full Cluster Logs
Index pattern: logs-*-default
Time field: @timestamp
```

---

## ⏰ **LOG RETENTION & ILM POLICIES**

### **Index Lifecycle Management (ILM) Strategy**

```
CRITICAL Logs: 90 days retention
  └─ Days 0-7:   Hot tier (SSD)
  └─ Days 7-30:  Warm tier (SSD)
  └─ Days 30-90: Cold tier (HDD or S3)
  └─ Day 90:     DELETE

WARN Logs: 30 days retention
  └─ Days 0-7:  Hot tier
  └─ Days 7-30: Warm tier
  └─ Day 30:    DELETE

INFO Logs: 7 days retention
  └─ Days 0-7: Hot tier
  └─ Day 7:    DELETE

DEBUG Logs: 1 day retention
  └─ Day 0-1: Hot tier
  └─ Day 1:   DELETE
```

### **Create ILM Policy in Kibana**

Go to **Stack Management** → **Index Lifecycle Policies** → **Create Policy**

#### **Policy: logs-critical-policy**

```json
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_size": "50gb",
            "max_age": "7d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "searchable_snapshot": {
            "snapshot_repository": "found-snapshots"
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

#### **Policy: logs-warn-policy**

```json
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_size": "50gb",
            "max_age": "7d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

#### **Policy: logs-info-policy**

```json
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_size": "50gb",
            "max_age": "1d"
          }
        }
      },
      "delete": {
        "min_age": "7d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

### **Apply ILM Policy to Data Streams**

```bash
# Via Elasticsearch API
curl -X PUT "https://localhost:9200/_data_stream/logs-*.critical-*/_settings" \
  -H 'Content-Type: application/json' \
  -u elastic:PASSWORD \
  -k \
  -d '{
    "index.lifecycle.name": "logs-critical-policy"
  }'

curl -X PUT "https://localhost:9200/_data_stream/logs-*.warn-*/_settings" \
  -H 'Content-Type: application/json' \
  -u elastic:PASSWORD \
  -k \
  -d '{
    "index.lifecycle.name": "logs-warn-policy"
  }'

curl -X PUT "https://localhost:9200/_data_stream/logs-*.info-*/_settings" \
  -H 'Content-Type: application/json' \
  -u elastic:PASSWORD \
  -k \
  -d '{
    "index.lifecycle.name": "logs-info-policy"
  }'
```

---

## 📊 **DASHBOARDS & VISUALIZATIONS**

### **Dashboard 1: Cluster Overview (Tier 0)**

**Panels:**

1. **Total Errors (Last 24h)** - Metric
   - Query: `log.level:error OR log.level:critical`
   - Aggregation: Count
   - Time Range: Last 24h

2. **Errors by Service (Top 10)** - Bar Chart
   - Query: `log.level:error`
   - X-axis: `service.name` (Terms, Top 10)
   - Y-axis: Count

3. **Infrastructure Health Heatmap** - Heat Map
   - Rows: `kubernetes.namespace`
   - Columns: `log.level`
   - Values: Count

4. **Recent Critical Errors** - Data Table
   - Columns: `@timestamp`, `service.name`, `kubernetes.pod_name`, `message`
   - Query: `log.level:critical`
   - Sort: `@timestamp` desc

5. **Error Timeline** - Area Chart
   - X-axis: `@timestamp` (Date Histogram, 5m interval)
   - Y-axis: Count
   - Split Series: `log.level`

### **Dashboard 2: Application Logs (Tier 3)**

**Panels:**

1. **N8N Workflow Executions** - Metric
   - Query: `service.name:"n8n-prod" AND message:"workflow execution"`
   - Aggregation: Count

2. **N8N Errors by Workflow** - Pie Chart
   - Query: `service.name:"n8n-prod" AND log.level:error`
   - Slice: `workflow.id` (Terms, Top 10)

3. **Boutique Cart Operations** - Line Chart
   - Query: `service.name:"boutique-*" AND message:"cart"`
   - X-axis: `@timestamp`
   - Y-axis: Count
   - Split Series: `kubernetes.namespace`

4. **Application Response Times** - Gauge
   - Query: `service.name:"n8n-prod"`
   - Aggregation: Avg of `duration`

### **Dashboard 3: Security Audit (Tier 4)**

**Panels:**

1. **Failed Login Attempts** - Metric
   - Query: `service.name:"authelia" AND message:"failed login"`
   - Aggregation: Count
   - Alert Threshold: > 10

2. **Authentication Methods** - Pie Chart
   - Query: `service.name:"authelia" OR service.name:"keycloak"`
   - Slice: `auth_method`

3. **Security Events Timeline** - Timeline
   - Query: `service.name:("authelia" OR "keycloak" OR "lldap")`
   - Group by: `log.level`

4. **Failed Logins by IP** - Data Table
   - Query: `message:"failed" AND (service.name:"authelia" OR service.name:"keycloak")`
   - Columns: `@timestamp`, `user`, `ip_address`, `message`

---

## 🛠️ **TROUBLESHOOTING & OPERATIONS**

### **Common Queries**

#### **Find All Errors in N8N:**
```
service.name:"n8n-prod" AND log.level:error
```

#### **Find Pod Crashes:**
```
message:"CrashLoopBackOff" OR message:"Error" OR message:"OOMKilled"
```

#### **Find Rook-Ceph OSD Errors:**
```
service.name:"rook-ceph" AND message:"osd" AND log.level:error
```

#### **Find Certificate Renewal Failures:**
```
service.name:"cert-manager" AND message:"renewal" AND log.level:error
```

#### **Find ArgoCD Sync Failures:**
```
service.name:"argocd" AND message:"sync" AND log.level:error
```

### **Correlation with Traces (OpenTelemetry)**

If your apps emit `trace.id`, you can correlate logs with traces:

```
trace.id:"abc123def456"
```

This shows all logs related to a specific distributed trace!

---

## ✅ **QUICK START CHECKLIST**

### **Phase 1: Kibana Setup (30 minutes)**
- [ ] Login to Kibana (https://localhost:5601)
- [ ] Create 8 Data Views (Tier 0-4 + Critical + Warn + All)
- [ ] Verify data is flowing (Discover tab)

### **Phase 2: ILM Policies (20 minutes)**
- [ ] Create ILM policies (critical, warn, info, debug)
- [ ] Apply ILM to data streams
- [ ] Verify rollover settings

### **Phase 3: Dashboards (1 hour)**
- [ ] Create "Cluster Overview" dashboard
- [ ] Create "Application Logs" dashboard
- [ ] Create "Security Audit" dashboard

### **Phase 4: Alerts (30 minutes)**
- [ ] Create alert for critical errors > 10/min
- [ ] Create alert for failed logins > 5/min
- [ ] Create alert for pod restarts > 3/5min

---

## 📚 **NEXT STEPS**

1. **Vector Enhancement**: Add more enrichment (GeoIP, user-agent parsing)
2. **Alerting**: Integrate with Prometheus Alertmanager
3. **Log Sampling**: Reduce INFO log volume by 90% (sample_logs transform)
4. **Machine Learning**: Use Kibana ML for anomaly detection
5. **Backup**: Configure Elasticsearch snapshots to Ceph RGW

---

## 📖 **REFERENCES**

- **ECS Schema**: https://www.elastic.co/guide/en/ecs/current/index.html
- **Data Streams**: https://www.elastic.co/guide/en/elasticsearch/reference/current/data-streams.html
- **ILM**: https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html
- **Vector Docs**: https://vector.dev/docs/

---

**🎯 VERDICT: Your logging setup is already 80% production-ready! Just needs proper Kibana Data Views and Dashboards.**
