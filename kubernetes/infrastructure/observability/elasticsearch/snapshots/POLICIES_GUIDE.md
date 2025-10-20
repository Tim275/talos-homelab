# Elasticsearch Policies: Complete Guide & Best Practices

## Overview

This document covers all Elasticsearch policy types and best practices for production environments, including Index Lifecycle Management (ILM) and Snapshot Lifecycle Management (SLM).

---

## Table of Contents

1. [Index Lifecycle Management (ILM)](#index-lifecycle-management-ilm)
2. [Snapshot Lifecycle Management (SLM)](#snapshot-lifecycle-management-slm)
3. [Current Deployed Policies](#current-deployed-policies)
4. [Enterprise Best Practices](#enterprise-best-practices)
5. [Recommended Improvements](#recommended-improvements)
6. [Monitoring & Alerting](#monitoring--alerting)

---

## Index Lifecycle Management (ILM)

### What is ILM?

ILM automates the lifecycle of indices from creation to deletion, moving them through different phases based on age, size, or document count. This optimizes performance and reduces storage costs.

### ILM Phases

```
HOT → WARM → COLD → FROZEN → DELETE
```

#### 1. **Hot Phase** (Active Writing & Searching)
- **Purpose**: Highest performance for active data ingestion and recent queries
- **Hardware**: Fast SSD storage, high CPU/RAM
- **Actions**:
  - `rollover`: Create new index when conditions met (age, size, doc count)
  - `set_priority`: Set index priority (typically 100)
  - `readonly`: Make index read-only after rollover

**Example**:
```json
{
  "hot": {
    "min_age": "0ms",
    "actions": {
      "rollover": {
        "max_age": "7d",
        "max_primary_shard_size": "50gb",
        "max_docs": 200000000
      },
      "set_priority": {
        "priority": 100
      }
    }
  }
}
```

#### 2. **Warm Phase** (Read-Heavy Workloads)
- **Purpose**: Older data queried less frequently
- **Hardware**: Standard SSD or HDD
- **Actions**:
  - `forcemerge`: Merge segments to reduce overhead (typically to 1 segment)
  - `shrink`: Reduce shard count to save resources
  - `allocate`: Move to cheaper hardware
  - `set_priority`: Lower priority (typically 50)

**Example**:
```json
{
  "warm": {
    "min_age": "7d",
    "actions": {
      "forcemerge": {
        "max_num_segments": 1
      },
      "shrink": {
        "number_of_shards": 1,
        "allow_write_after_shrink": false
      },
      "set_priority": {
        "priority": 50
      },
      "allocate": {
        "number_of_replicas": 1,
        "require": {
          "data": "warm"
        }
      }
    }
  }
}
```

#### 3. **Cold Phase** (Archive/Compliance)
- **Purpose**: Rarely accessed historical data
- **Hardware**: Slow HDD, object storage
- **Actions**:
  - `searchable_snapshot`: Mount as read-only searchable snapshot
  - `readonly`: Make index read-only
  - `set_priority`: Lowest priority (typically 0)
  - `allocate`: Move to cold data nodes

**Example**:
```json
{
  "cold": {
    "min_age": "30d",
    "actions": {
      "readonly": {},
      "searchable_snapshot": {
        "snapshot_repository": "ceph-s3-snapshots"
      },
      "set_priority": {
        "priority": 0
      }
    }
  }
}
```

#### 4. **Frozen Phase** (Long-Term Archive)
- **Purpose**: Very rarely accessed, cheapest storage
- **Hardware**: Object storage (S3, Ceph RGW)
- **Actions**:
  - `searchable_snapshot`: Fully cached searchable snapshot
  - Queries may be slower but storage is minimal

**Example**:
```json
{
  "frozen": {
    "min_age": "90d",
    "actions": {
      "searchable_snapshot": {
        "snapshot_repository": "ceph-s3-snapshots",
        "force_merge_index": true
      }
    }
  }
}
```

#### 5. **Delete Phase** (Retention Enforcement)
- **Purpose**: Delete old data to comply with retention policies
- **Actions**:
  - `delete`: Permanently remove indices and snapshots

**Example**:
```json
{
  "delete": {
    "min_age": "365d",
    "actions": {
      "delete": {
        "delete_searchable_snapshot": true
      }
    }
  }
}
```

---

## Snapshot Lifecycle Management (SLM)

### What is SLM?

SLM automates snapshot creation, retention, and deletion for disaster recovery and compliance.

### Key Components

1. **Schedule**: Cron expression (Quartz format with seconds)
2. **Snapshot Name Template**: Dynamic naming with date/time
3. **Repository**: S3, NFS, or other snapshot storage
4. **Retention Policy**: How long to keep snapshots

### SLM Configuration

```json
{
  "schedule": "0 0 2 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "ceph-s3-snapshots",
  "config": {
    "indices": ["logs-*", "metrics-*"],
    "ignore_unavailable": true,
    "include_global_state": false,
    "metadata": {
      "taken_by": "slm-policy",
      "taken_because": "automated backup"
    }
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 5,
    "max_count": 50
  }
}
```

### Retention Best Practices

| Policy Type | expire_after | min_count | max_count | Use Case |
|-------------|--------------|-----------|-----------|----------|
| **Hourly** | 48h | 24 | 100 | High-frequency changes |
| **Daily** | 30d | 7 | 50 | Standard backup |
| **Weekly** | 90d | 4 | 20 | Long-term archive |
| **Monthly** | 365d | 12 | 24 | Compliance/Audit |

---

## Current Deployed Policies

### ILM Policies (48 Total)

#### Severity-Based Log Policies
| Policy Name | Retention | Phases | Hot Rollover |
|-------------|-----------|--------|--------------|
| `logs-critical-policy` | 90d | Hot → Warm (7d) → Cold (30d) → Delete (90d) | 7d / 50GB |
| `logs-warn-policy` | 60d | Hot → Warm (7d) → Delete (60d) | 7d / 50GB |
| `logs-info-policy` | 30d | Hot → Warm (7d) → Delete (30d) | 7d / 50GB |
| `logs-debug-policy` | 7d | Hot → Delete (7d) | 3d / 30GB |

#### Time-Based Retention Policies
| Policy Name | Retention | Description |
|-------------|-----------|-------------|
| `7-days-default` | 7d | Short-term logs (debug, troubleshooting) |
| `30-days-default` | 30d | Standard logs (info level) |
| `90-days-default` | 90d | Important logs (warnings, errors) |
| `180-days-default` | 180d | Compliance logs |
| `365-days-default` | 365d | Audit logs |

#### Specialized Policies
| Policy Name | Purpose | Retention |
|-------------|---------|-----------|
| `vector-logs-30d` | Vector agent logs | 30d (Hot → Warm → Delete) |
| `metrics-logs-14d` | Metrics data | 14d |
| `audit-logs-365d` | Audit trail | 365d |
| `debug-logs-7d` | Debug/troubleshooting | 7d |

#### System Policies
- `.monitoring-8-ilm-policy`: Elasticsearch monitoring data (30d)
- `.alerts-ilm-policy`: Alerting indices
- `slm-history-ilm-policy`: SLM execution history
- `ilm-history-ilm-policy`: ILM execution history
- `watch-history-ilm-policy`: Watcher execution history

### SLM Policies (1 Active)

| Policy Name | Schedule | Indices | Retention | Repository |
|-------------|----------|---------|-----------|------------|
| `daily-snapshots` | Daily 2 AM UTC | `logs-*` | 30d (min 5, max 50) | `ceph-s3-snapshots` |

---

## Enterprise Best Practices

### 1. **Hot-Warm-Cold Architecture**

```
┌─────────────────────────────────────────────────────┐
│ HOT TIER (SSD)                                      │
│ • Active ingestion (0-7 days)                       │
│ • High IOPS, low latency                            │
│ • Rollover: 50GB or 7 days                          │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ WARM TIER (Standard SSD/HDD)                        │
│ • Read-heavy workloads (7-30 days)                  │
│ • Forcemerge to 1 segment                           │
│ • Shrink to 1 shard                                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ COLD TIER (Object Storage)                          │
│ • Archive/compliance (30-365 days)                  │
│ • Searchable snapshots                              │
│ • Read-only, minimal cost                           │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ DELETE                                               │
│ • Automated retention enforcement                    │
│ • Compliance with data retention laws                │
└─────────────────────────────────────────────────────┘
```

### 2. **Rollover Strategy**

**Recommended Rollover Triggers**:
- **Time-based**: 1 day (for high-volume logs) or 7 days (for moderate logs)
- **Size-based**: 30-50GB primary shard size (optimal for search performance)
- **Document-based**: 200M documents (prevents oversized shards)

**Anti-Pattern**: ❌ Fixed daily indices (`logs-2025.10.20`)
**Best Practice**: ✅ Rollover-based indices (`logs-000001`, `logs-000002`)

### 3. **Shard Sizing**

| Shard Size | Performance | Use Case |
|------------|-------------|----------|
| < 10GB | ⚠️ Too small (overhead) | Microservices with low traffic |
| 10-30GB | ✅ Good | Standard logs |
| 30-50GB | ✅ Optimal | High-volume logs |
| > 50GB | ⚠️ Too large (slow recovery) | Anti-pattern, use rollover |

### 4. **Retention by Log Level**

```yaml
Critical/Error:  90-365 days  # Long retention for incident investigation
Warning:         30-90 days   # Medium retention for troubleshooting
Info:            7-30 days    # Short retention, high volume
Debug:           1-7 days     # Minimal retention, highest volume
```

### 5. **Snapshot Strategy**

**Multi-Frequency Backup**:
```
Hourly   →  48h retention   (Recent changes, quick recovery)
Daily    →  30d retention   (Standard backup)
Weekly   →  90d retention   (Long-term archive)
Monthly  →  365d retention  (Compliance)
```

**Implementation**:
```bash
# Multiple SLM policies for different frequencies
kubectl apply -f snapshots/slm-hourly-policy.yaml
kubectl apply -f snapshots/slm-daily-policy.yaml
kubectl apply -f snapshots/slm-weekly-policy.yaml
kubectl apply -f snapshots/slm-monthly-policy.yaml
```

### 6. **Security & Compliance**

**GDPR/CCPA Compliance**:
- Automated deletion after retention period
- Encrypted snapshots (Elasticsearch encryption + Ceph encryption at rest)
- Audit trail via ILM/SLM history indices

**Example Delete Policy**:
```json
{
  "delete": {
    "min_age": "30d",
    "actions": {
      "delete": {
        "delete_searchable_snapshot": true
      }
    }
  }
}
```

---

## Recommended Improvements

### 1. Add Searchable Snapshots for Cold Tier

**Current**: Cold tier uses readonly indices on disk
**Recommended**: Use searchable snapshots to reduce storage costs

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: elasticsearch-enable-searchable-snapshots
  namespace: elastic-system
spec:
  template:
    spec:
      containers:
      - name: update-policy
        image: curlimages/curl:8.11.1
        command:
        - /bin/sh
        - -c
        - |
          # Update logs-critical-policy to use searchable snapshots
          curl -sk -X PUT -u "elastic:$ELASTIC_PASSWORD" \
            "https://production-cluster-es-http.elastic-system.svc.cluster.local:9200/_ilm/policy/logs-critical-policy" \
            -H "Content-Type: application/json" \
            -d '{
              "policy": {
                "phases": {
                  "hot": {
                    "actions": {
                      "rollover": {
                        "max_age": "7d",
                        "max_primary_shard_size": "50gb"
                      },
                      "set_priority": {"priority": 100}
                    }
                  },
                  "warm": {
                    "min_age": "7d",
                    "actions": {
                      "forcemerge": {"max_num_segments": 1},
                      "shrink": {"number_of_shards": 1},
                      "set_priority": {"priority": 50}
                    }
                  },
                  "cold": {
                    "min_age": "30d",
                    "actions": {
                      "searchable_snapshot": {
                        "snapshot_repository": "ceph-s3-snapshots"
                      },
                      "set_priority": {"priority": 0}
                    }
                  },
                  "delete": {
                    "min_age": "90d",
                    "actions": {
                      "delete": {"delete_searchable_snapshot": true}
                    }
                  }
                }
              }
            }'
```

**Benefits**:
- 90% storage reduction (cold data on S3 instead of local disk)
- Lower infrastructure costs
- Same search functionality (slightly slower queries)

### 2. Add Multi-Frequency SLM Policies

**Current**: Only daily snapshots
**Recommended**: Add hourly, weekly, and monthly snapshots

See `snapshots/slm-multi-frequency-policies.yaml` (to be created).

### 3. Add Frozen Tier for Long-Term Audit Logs

**Use Case**: Compliance logs retained for 7+ years
**Implementation**: Frozen searchable snapshots with minimal memory footprint

```yaml
frozen:
  min_age: "365d"
  actions:
    searchable_snapshot:
      snapshot_repository: "ceph-s3-snapshots"
      force_merge_index: true
```

### 4. Add Data Stream Lifecycle Management

**Current**: Using index templates + ILM
**Recommended**: Migrate to built-in data stream lifecycle (simpler configuration)

```json
PUT _data_stream/logs-critical-production
{
  "lifecycle": {
    "data_retention": "90d"
  }
}
```

---

## Monitoring & Alerting

### Key Metrics to Monitor

#### ILM Metrics
```promql
# Indices stuck in a phase
elasticsearch_ilm_indices_behind_policy

# Phase execution errors
rate(elasticsearch_ilm_phase_execution_errors_total[5m])

# Rollover success rate
rate(elasticsearch_ilm_rollover_success_total[5m]) /
rate(elasticsearch_ilm_rollover_total[5m])
```

#### SLM Metrics
```promql
# Snapshot failures
elasticsearch_slm_stats_snapshots_failed_total > 0

# Last successful snapshot age
time() - elasticsearch_slm_last_success_timestamp > 86400*2

# Snapshot retention violations
elasticsearch_slm_stats_retention_deletion_time_millis
```

### Recommended Alerts

```yaml
groups:
  - name: elasticsearch_policies
    rules:
      # ILM stuck indices
      - alert: ElasticsearchILMStuck
        expr: elasticsearch_ilm_indices_behind_policy > 5
        for: 1h
        annotations:
          summary: "{{ $value }} indices stuck in ILM phase"

      # Snapshot failures
      - alert: ElasticsearchSnapshotFailed
        expr: increase(elasticsearch_slm_stats_snapshots_failed_total[1h]) > 0
        annotations:
          summary: "Elasticsearch snapshot failed"

      # No recent snapshot
      - alert: ElasticsearchSnapshotStale
        expr: time() - elasticsearch_slm_last_success_timestamp > 172800
        annotations:
          summary: "No successful snapshot in 48 hours"

      # Storage growth rate
      - alert: ElasticsearchStorageGrowthHigh
        expr: |
          predict_linear(
            elasticsearch_cluster_health_active_primary_shards_total[7d],
            604800
          ) > 1000
        annotations:
          summary: "Storage will exceed 1000 shards in 7 days"
```

---

## Implementation Checklist

### Phase 1: Current State (✅ Complete)
- [x] Daily SLM snapshots to S3
- [x] Severity-based ILM policies (critical, warn, info, debug)
- [x] Time-based retention (7d, 30d, 90d, 180d, 365d)
- [x] Hot-Warm architecture with forcemerge and shrink

### Phase 2: Quick Wins (Recommended Next Steps)
- [ ] Add hourly SLM policy for high-frequency backups
- [ ] Enable searchable snapshots for cold tier
- [ ] Add Prometheus alerts for ILM/SLM health
- [ ] Document restore procedures (DR runbook)

### Phase 3: Advanced Optimization
- [ ] Implement frozen tier for 7-year audit log retention
- [ ] Add weekly/monthly SLM policies
- [ ] Migrate to data stream lifecycle (simpler config)
- [ ] Configure cross-cluster replication (disaster recovery)

### Phase 4: Enterprise Features (Future)
- [ ] Elasticsearch encryption at rest
- [ ] Snapshot encryption with KMS integration
- [ ] Multi-region snapshot replication
- [ ] Automated snapshot testing/validation

---

## References

- [Elasticsearch ILM Official Docs](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html)
- [SLM Best Practices](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-lifecycle-management.html)
- [Searchable Snapshots](https://www.elastic.co/guide/en/elasticsearch/reference/current/searchable-snapshots.html)
- [Data Stream Lifecycle](https://www.elastic.co/guide/en/elasticsearch/reference/current/data-stream-lifecycle.html)
- [Hot-Warm-Cold Architecture](https://www.elastic.co/blog/hot-warm-architecture-in-elasticsearch-5-x)

---

## Elasticsearch License Comparison & Feature Overview

### 📊 License Tiers & Pricing

| Feature | BASIC (Free) | PLATINUM (~$6,700/year) | ENTERPRISE (~$8,400/year) |
|---------|--------------|------------------------|---------------------------|
| **Core Features** |
| Full-text search & analytics | ✅ | ✅ | ✅ |
| TLS encryption (HTTPS) | ✅ | ✅ | ✅ |
| Role-Based Access Control (RBAC) | ✅ | ✅ | ✅ |
| Index Lifecycle Management (ILM) | ✅ | ✅ | ✅ |
| Snapshot & Restore (S3) | ✅ | ✅ | ✅ |
| Kibana dashboards | ✅ | ✅ | ✅ |
| **Advanced Security** |
| SAML/OIDC Authentication | ❌ | ✅ | ✅ |
| Active Directory/LDAP | ❌ | ✅ | ✅ |
| Field/Document-Level Security | ❌ | ❌ | ✅ |
| Audit Logging (Compliance) | ❌ | ❌ | ✅ |
| IP Filtering | ❌ | ✅ | ✅ |
| **Machine Learning** |
| Anomaly Detection | ❌ | ✅ | ✅ |
| Forecasting | ❌ | ✅ | ✅ |
| Log Rate Analysis | ❌ | ✅ | ✅ |
| **Storage Optimization** |
| Hot-Warm Architecture | ✅ | ✅ | ✅ |
| Forcemerge + Shrink | ✅ | ✅ | ✅ |
| **Searchable Snapshots** | ❌ | ❌ | ✅ |
| **Cold/Frozen Tiers (S3-backed)** | ❌ | ❌ | ✅ |
| Storage Savings | **40-50%** | **40-50%** | **90%** |
| **Enterprise Features** |
| Cross-Cluster Replication | ❌ | ✅ | ✅ |
| SIEM Features | ❌ | ✅ | ✅ |
| Canvas & Graph Analytics | ❌ | ✅ | ✅ |
| Autoscaling | ❌ | ❌ | ✅ |
| Multi-Stack Monitoring | ❌ | ❌ | ✅ |
| **Support** |
| Community Support | ✅ | ❌ | ❌ |
| 4h Response SLA | ❌ | ✅ | ✅ |
| 1h Critical Response SLA | ❌ | ✅ | ✅ |
| 99.95% Uptime SLA | ❌ | ✅ | ✅ |

### 💰 License Break-Even Analysis

**When does Enterprise license pay for itself?**

| Cold Data Volume | Basic Savings | Enterprise Savings | Extra Saved | License Cost | Net Result |
|-----------------|---------------|-------------------|-------------|--------------|------------|
| 5TB | 2.5TB | 4.5TB | +2TB | $8,400/year | **-$6,000 Loss** |
| 10TB | 5TB | 9TB | +4TB | $8,400/year | **-$3,600 Loss** |
| **18TB (Break-Even)** | 9TB | 16.2TB | +7.2TB | $8,400/year | **$0 (Break-Even)** |
| **20TB** | 10TB | 18TB | +8TB | $8,400/year | **+$1,200 Profit** |
| 50TB | 25TB | 45TB | +20TB | $8,400/year | **+$15,600 Profit** |
| 100TB | 50TB | 90TB | +40TB | $8,400/year | **+$39,600 Profit** |

**Assumptions:**
- SSD storage: $0.10/GB/month ($1.20/GB/year)
- Basic License: 40-50% savings (forcemerge + shrink + 0 replicas)
- Enterprise License: 90% savings (searchable snapshots on S3)

### 🎯 License Recommendation Decision Tree

```
Do you have >20TB cold data?
├─ YES → Consider Enterprise (storage savings pay for license)
└─ NO
   ├─ Need SAML/OIDC (Keycloak, Authelia)?
   │  ├─ YES → Consider Platinum
   │  └─ NO
   │     ├─ Need Machine Learning (Anomaly Detection)?
   │     │  ├─ YES → Consider Platinum
   │     │  └─ NO
   │     │     ├─ Need Compliance (Audit Logs)?
   │     │     │  ├─ YES → Consider Enterprise
   │     │     │  └─ NO → Stay on BASIC (already optimal!)
```

### 📈 Your Current Setup (BASIC License)

**Current Optimization Strategy:**
```yaml
Hot Phase (0-7 days):     1 replica, fast SSD  →  Baseline (100%)
Warm Phase (7-30 days):   forcemerge + shrink  →  30% savings
Cold Phase (30+ days):    0 replicas + readonly  →  50% savings
Delete Phase (60/90 days): Auto-deletion  →  Compliance
```

**Total Storage Reduction: 40-50%** ✅

**What you're getting for FREE:**
- ✅ Enterprise-grade ILM with 48 policies
- ✅ Automated S3 snapshots (daily backups)
- ✅ Hot-Warm-Cold architecture
- ✅ Severity-based retention (critical: 90d, warn: 60d, info: 30d, debug: 7d)
- ✅ RBAC + TLS encryption

### 🚀 Upgrade Scenarios

**Upgrade to PLATINUM if:**
- You need **SAML/OIDC** for Keycloak/Authelia integration
- You want **Anomaly Detection** in logs (ML-powered alerts)
- You need **Cross-Cluster Replication** for multi-datacenter setup
- You want **Enterprise Support** with 4h/1h SLA

**Upgrade to ENTERPRISE if:**
- You have **>18TB cold data** (license pays for itself via storage savings)
- You need **Compliance** features (audit logging, field-level security)
- You want **90% storage savings** (searchable snapshots on S3)
- You need **Autoscaling** for dynamic workloads

**Stay on BASIC if:**
- You have **<10TB data** (savings don't justify cost)
- You don't need ML or advanced security
- Current 40-50% savings are sufficient for your homelab

---

## Summary

Your current setup is **excellent** with 48 ILM policies and comprehensive retention strategies. Key recommendations:

1. ✅ **Already Great**: Severity-based retention, hot-warm architecture, automated snapshots
2. ✅ **Already Optimized**: 40-50% storage savings with Basic license
3. 🎯 **Future Option**: Upgrade to Enterprise when cold data exceeds 18-20TB
4. 🔐 **Security Note**: SAML/OIDC (Keycloak) requires Platinum license

**Current Storage Efficiency**: ~40-50% savings (Optimal for Basic License)
**With Enterprise License**: ~90% savings (Requires $8,400/year)

**Break-even point**: ~18TB cold data

Your Elasticsearch cluster is **production-ready** with enterprise-grade data lifecycle management optimized for Basic license! 🎉

For detailed license comparison and upgrade decision matrix, see: `LICENSE_COMPARISON.md`
