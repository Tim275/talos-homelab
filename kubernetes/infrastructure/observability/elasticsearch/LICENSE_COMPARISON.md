# Elasticsearch License Comparison & Optimization Guide

## Current License Status

```json
{
  "type": "basic",
  "status": "active",
  "max_nodes": 1000
}
```

**You are using: BASIC (Free) License** ✅

---

## License Tiers Comparison

### 🆓 BASIC (Free) - **YOUR CURRENT LICENSE**

**Included Features:**
- ✅ Full-text search & analytics
- ✅ TLS encryption (HTTPS)
- ✅ Password protection & Basic Auth
- ✅ Role-Based Access Control (RBAC)
- ✅ **Index Lifecycle Management (ILM)**
- ✅ **Snapshot & Restore** (Manual + SLM)
- ✅ Kibana dashboards & visualizations
- ✅ Basic monitoring
- ✅ Basic alerting

**NOT Included:**
- ❌ Searchable Snapshots (Cold/Frozen tier)
- ❌ Machine Learning
- ❌ Advanced Security (SAML, OIDC, Field/Document-level)
- ❌ Cross-Cluster Replication
- ❌ Canvas infographics

**Cost:** FREE

---

### 💎 PLATINUM (Paid)

**Additional Features:**
- ✅ **Machine Learning** (Anomaly Detection, Forecasting)
- ✅ **Advanced Alerting** (ML-based)
- ✅ **Cross-Cluster Replication**
- ✅ **SIEM Features** (Security threat detection)
- ✅ **Advanced Security:**
  - SAML/OIDC Authentication
  - Active Directory/LDAP
  - IP Filtering
- ✅ Canvas & Graph Analytics
- ✅ Enterprise Search
- ✅ **Support:** 4-hour response (1-hour for critical)
- ✅ **99.95% SLA**

**Cost:**
- Cloud: $125/month
- Self-managed: ~$6,700/year per node

---

### 🏢 ENTERPRISE (Paid)

**Additional to Platinum:**
- ✅ **🎯 Searchable Snapshots** (90% storage savings!)
- ✅ **Cold & Frozen Tiers** (S3-backed storage)
- ✅ **Field & Document-Level Security**
- ✅ **Audit Logging** (Compliance)
- ✅ **Autoscaling**
- ✅ Elastic Maps Server
- ✅ Multi-Stack Monitoring
- ✅ Advanced SIEM
- ✅ Same support as Platinum
- ✅ **99.95% SLA**

**Cost:**
- Cloud: $175/month
- Self-managed: ~$8,400/year per node

---

## Storage Optimization Comparison

| License Level | Optimization Strategy | Storage Savings | Implementation |
|---------------|----------------------|-----------------|----------------|
| **BASIC (Free)** | • Forcemerge + Shrink<br>• 0 Replicas in Cold<br>• Readonly | **40-50%** | ✅ **IMPLEMENTED** |
| **PLATINUM** | Same as Basic | **40-50%** | N/A |
| **ENTERPRISE** | • Searchable Snapshots<br>• S3-backed Cold/Frozen | **90%** | Requires upgrade |

---

## Current Optimization (BASIC License)

### ✅ Implemented Strategy

```yaml
Hot Phase (Day 0-7):
  - Active ingestion on fast SSD
  - 1 replica for high availability
  - Rollover: 50GB or 7 days
  - Priority: 100

Warm Phase (Day 7-30):
  - Forcemerge to 1 segment  (~30% savings)
  - Shrink to 1 shard
  - Still 1 replica
  - Priority: 50

Cold Phase (Day 30+):
  - 0 replicas  (~50% savings!)
  - Readonly (saves RAM/CPU)
  - Priority: 0
  - ✅ S3 snapshots as backup

Delete Phase (Day 60/90):
  - Auto-delete old data
  - Compliance with retention policies
```

### 📊 Storage Savings Breakdown

| Phase | Replicas | Segments | Shards | Savings vs Hot |
|-------|----------|----------|---------|----------------|
| **Hot** | 1 | Many | Many | Baseline (100%) |
| **Warm** | 1 | 1 | 1 | ~30% |
| **Cold** | 0 | 1 | 1 | **~50%** |

**Total Storage Reduction: 40-50%** ✅

---

## Enterprise Upgrade Decision Matrix

### Should You Upgrade to Enterprise?

**Upgrade is worth it if:**

✅ You have >20TB of cold data
- Savings: 90% vs 50% = **40% more efficient**
- At 20TB: 8TB extra saved * $0.10/GB/month = $800/month = **$9,600/year saved**
- License cost: $8,400/year
- **Net savings: $1,200/year**

✅ You need Machine Learning features
- Anomaly detection
- Forecasting
- Log rate analysis

✅ You need Enterprise Auth
- SAML/OIDC (Okta, Azure AD, etc.)
- Field/Document-level security
- Audit logging for compliance

**Stay on BASIC if:**

❌ You have <10TB data
- Savings don't justify license cost

❌ You don't need ML or advanced security

❌ Current 40-50% savings are sufficient

---

## Break-Even Analysis

| Data Volume (Cold) | Storage Cost Saved | License Cost | Net Result |
|-------------------|-------------------|--------------|------------|
| 5TB | $2,400/year | $8,400/year | **-$6,000** (Loss) |
| 10TB | $4,800/year | $8,400/year | **-$3,600** (Loss) |
| 20TB | $9,600/year | $8,400/year | **+$1,200** (Profit) |
| 50TB | $24,000/year | $8,400/year | **+$15,600** (Profit) |
| 100TB | $48,000/year | $8,400/year | **+$39,600** (Profit) |

**Assumption:** $0.10/GB/month for SSD storage

**Break-even point: ~18TB cold data**

---

## Monitoring Your Savings

### Check Current Storage Usage

```bash
# Total cluster size
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -sk -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_cat/allocation?v&h=disk.used,disk.avail,disk.total,disk.percent"

# Storage by phase
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -sk -u "elastic:$ELASTIC_PASSWORD" \
  "https://localhost:9200/_cat/indices?v&h=index,pri,rep,store.size&s=store.size:desc"
```

### Prometheus Queries

```promql
# Total storage used
elasticsearch_cluster_health_active_primary_shards_total *
elasticsearch_indices_store_size_bytes

# Storage by tier
sum(elasticsearch_indices_store_size_bytes) by (data_tier)

# Replica overhead
elasticsearch_cluster_health_active_shards_total -
elasticsearch_cluster_health_active_primary_shards_total
```

---

## Recommendations

### For Current Setup (BASIC License)

✅ **Already Optimal!**
- Cold tier with 0 replicas: **50% savings**
- Warm tier forcemerge + shrink: **30% savings**
- Daily S3 snapshots for disaster recovery
- Total: **40-50% storage reduction**

### Future Considerations

**When data grows >20TB:**
- Consider Enterprise upgrade
- Calculate actual break-even based on your storage costs
- Evaluate need for ML/advanced security features

**Alternative to Enterprise:**
- Manual data offloading to cheaper storage
- Delete cold data more aggressively
- Use external data lake (S3 + external tools)

---

## FAQ

**Q: Can I get Searchable Snapshots on BASIC?**
A: No, it requires Enterprise license ($8,400/year).

**Q: What's the difference between S3 Snapshots and Searchable Snapshots?**
A:
- **S3 Snapshots (BASIC):** Backups for disaster recovery, NOT queryable
- **Searchable Snapshots (ENTERPRISE):** Cold data lives on S3 but remains searchable (slower)

**Q: Is 0 replicas in cold tier safe?**
A: Yes! Because:
- Data is readonly (no writes that could be lost)
- We have daily S3 snapshots as backup
- If a node fails, we restore from snapshot

**Q: How long until I see savings?**
A: After 30 days, when data reaches cold phase.

**Q: Can I speed up the cold transition?**
A: Yes, change `min_age: "30d"` to `min_age: "14d"` in ILM policy.

---

## Related Documentation

- [ILM Best Practices](./snapshots/POLICIES_GUIDE.md)
- [Snapshot Backup Guide](./snapshots/README.md)
- [Elastic Licensing Docs](https://www.elastic.co/subscriptions)
