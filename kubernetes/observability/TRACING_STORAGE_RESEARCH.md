# 🔬 Tracing Storage Research - Jaeger vs Grafana Tempo

**Research Date**: 2025-10-23
**Question**: Warum kann Jaeger nicht mit S3 arbeiten? Was ist Best Practice für Trace Storage?

---

## Executive Summary

```yaml
TL;DR - Die Ergebnisse:
├─ Jaeger: KEIN offizieller S3 Support ❌
├─ Grafana Tempo: Native S3 Support ✅
├─ Best Practice 2024: Grafana Tempo + S3/Ceph
└─ Jaeger Best Practice: Elasticsearch > Cassandra
```

---

## 1. Jaeger Storage Backends (Offiziell)

**Quelle**: https://www.jaegertracing.io/docs/2.0/storage/

### ✅ Offiziell Unterstützte Backends

```yaml
Production Backends:
├─ Elasticsearch ⭐ (RECOMMENDED by Jaeger team)
├─ Cassandra
└─ OpenSearch (recommended over Cassandra at scale)

Development/Testing:
├─ Memory (ephemeral, data loss on restart)
├─ Badger (local disk, single node)
└─ Kafka (buffer only, not storage)

Custom via gRPC:
└─ Remote Storage API (PostgreSQL via community plugin)
```

### ❌ S3 NICHT Offiziell Unterstützt

```yaml
Warum kein S3?:
├─ johanneswuerbach/jaeger-s3: ARCHIVED Januar 2024
├─ Docker Image: ghcr.io/jaegertracing/jaeger-s3 existiert NICHT
├─ Jaeger Docs: Erwähnen S3 nirgendwo
└─ Remote Storage API: Theoretisch möglich, aber kein offizielles Plugin
```

**Fazit**: Jaeger wurde für NoSQL-Datenbanken (Cassandra/ES) designt, NICHT für Object Storage.

---

## 2. Jaeger: Elasticsearch vs Cassandra

**Quelle**: https://signoz.io/guides/what-database-does-jaeger-use/

### 🏆 Elasticsearch (Official Recommendation)

```yaml
Vorteile:
├─ Single Write: Span speichern = 1 Write (Indexing intern)
├─ Search Performance: Powerful full-text search
├─ Query Capabilities: Complex queries möglich
├─ Operational: Einfacher TTL via Index Rotation
└─ Integration: Reuse existing EFK Stack

Nachteile:
├─ RAM: 24GB+ (3 nodes x 8GB)
├─ Complexity: JVM tuning, shard management
└─ Maintenance: Index lifecycle management
```

### 🏗️ Cassandra (Alternative)

```yaml
Vorteile:
├─ Write Throughput: Excellent für write-heavy workloads
├─ TTL: Native data expiration support
├─ Multi-DC: Global replication built-in
└─ Key-Value: Fast trace ID lookups

Nachteile:
├─ Write Amplification: Span speichern = multiple writes (service index, operation index, tag index)
├─ Search: Limitiert auf trace ID (kein full-text search)
├─ RAM: 24GB+ (ähnlich wie Elasticsearch)
└─ Complexity: Cluster management, compaction tuning
```

### ⚖️ Official Jaeger Team Recommendation

> **"For large scale production deployment the Jaeger team recommends Elasticsearch backend over Cassandra."**

**Begründung**:
- Single write vs write amplification
- Better search capabilities
- Overall throughput comparable
- Easier operational management (trotz Index Rotation)

---

## 3. Grafana Tempo - The Modern Alternative

**Quelle**: https://grafana.com/docs/tempo/latest/

### ☁️ Object Storage Native

```yaml
Officially Supported Storage:
├─ Amazon S3 ✅
├─ Google Cloud Storage (GCS) ✅
├─ Azure Blob Storage ✅
├─ MinIO (S3-compatible) ✅
├─ Ceph RGW (S3-compatible) ✅
└─ Local Filesystem (monolithic mode only)

Authentication:
├─ AWS Environment Variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
├─ IAM Roles (IRSA, EC2 Instance Roles, EKS Pod Identity)
├─ Static Credentials
└─ MinIO/Ceph credentials
```

### 🎯 Design Philosophy

**Tempo wurde gebaut um**:
- ❌ **KEINE** Cassandra/Elasticsearch Maintenance
- ✅ **S3 Object Storage** (billig, skalierbar)
- ✅ **100% Trace Retention** ohne Sampling
- ✅ **Kein Indexing** (nur Trace ID lookups)

**Trade-off**:
- ❌ Keine full-text search (nur Trace ID)
- ✅ Massiv weniger Ressourcen
- ✅ Keine Datenbank-Cluster Maintenance

---

## 4. Tempo vs Jaeger - The Comparison

**Quellen**:
- https://signoz.io/blog/jaeger-vs-tempo/
- https://last9.io/blog/grafana-tempo-vs-jaeger/

### 📊 Head-to-Head

```yaml
┌─────────────────────────────────────────────────────────────────┐
│ Feature            │ Jaeger            │ Grafana Tempo        │
├────────────────────┼───────────────────┼──────────────────────┤
│ Storage Backend    │ Cassandra/ES      │ S3/GCS/Azure Blob   │
│ Indexing           │ Full indexing     │ Trace ID only       │
│ Search             │ Full-text search  │ Trace ID lookup     │
│ Resource Usage     │ High (24GB+ RAM)  │ Low (2-4GB RAM)     │
│ Operational        │ DB management     │ Object storage      │
│ Sampling           │ Required at scale │ 100% retention      │
│ Maturity           │ 2015 (Uber)       │ 2020 (Grafana)      │
│ Community          │ Large, mature     │ Smaller, growing    │
│ Visualization      │ Jaeger UI         │ Grafana (better!)   │
└─────────────────────────────────────────────────────────────────┘
```

### 🏆 Winner by Use Case

```yaml
Use Grafana Tempo wenn:
├─ ✅ Already using Grafana (Metrics + Logs)
├─ ✅ Want S3/Object Storage (Ceph RGW)
├─ ✅ Need 100% trace retention
├─ ✅ Want minimal operational overhead
└─ ✅ Budget-conscious (storage costs)

Use Jaeger wenn:
├─ ✅ Need full-text search (find traces by tags, service names)
├─ ✅ Already have Cassandra/Elasticsearch
├─ ✅ Want mature ecosystem (plugins, integrations)
└─ ✅ Need Jaeger UI specifically
```

### 💡 Industry Trend 2024

```yaml
Legacy (2015-2020):
├─ Uber: Jaeger + Cassandra (sie haben es gebaut!)
├─ Netflix: Jaeger + Cassandra
└─ Reason: Tempo existierte noch nicht

Modern (2021-2025):
├─ New Deployments: Grafana Tempo + S3 ⭐
├─ Cloud-Native: Tempo (CNCF Incubating)
├─ Cost-Conscious: Tempo (S3 billiger als ES/Cassandra)
└─ Grafana Users: Tempo (native integration)

Jaeger bleibt relevant:
├─ Existing deployments mit ES/Cassandra
├─ Need for full-text search
└─ Legacy integrations
```

---

## 5. Resource Comparison - Real Numbers

```yaml
┌─────────────────────────────────────────────────────────────────┐
│ Setup                    │ RAM     │ CPU    │ Storage          │
├──────────────────────────┼─────────┼────────┼──────────────────┤
│ Jaeger + Elasticsearch   │ 24GB+   │ 6c+    │ ES Cluster       │
│ Jaeger + Cassandra       │ 24GB+   │ 6c+    │ Cassandra Ring   │
│ Grafana Tempo + S3       │ 2-4GB   │ 1-2c   │ S3 Bucket        │
└─────────────────────────────────────────────────────────────────┘

Cost Example (AWS):
├─ Elasticsearch 3-node: ~$500/month (r6g.xlarge x3)
├─ Cassandra 3-node: ~$500/month (r6g.xlarge x3)
└─ S3 Storage: ~$23/month (1TB @ $0.023/GB)

Winner: Tempo mit S3 = 95% Kosteneinsparung! 💰
```

---

## 6. Homelab Decision Matrix

```yaml
Current Stack:
├─ Metrics: Prometheus + Grafana ✅
├─ Logs: Elasticsearch + Kibana + Vector ✅
├─ Storage: Ceph RGW (S3-compatible) ✅
└─ Traces: ??? (To be decided)

Option 1: Jaeger + Elasticsearch
├─ Pro: Reuse existing Elasticsearch cluster
├─ Pro: Full-text search capabilities
├─ Pro: Learn Jaeger (industry standard knowledge)
├─ Con: Elasticsearch already at 30% cluster RAM (27.5GB)
├─ Con: More operational overhead
└─ Con: Kein S3 support

Option 2: Grafana Tempo + Ceph S3 ⭐ RECOMMENDED
├─ Pro: Native S3/Ceph support ✅
├─ Pro: Reuse existing Ceph RGW (Velero, ES Snapshots)
├─ Pro: Perfect Grafana integration (already using!)
├─ Pro: 2-4GB RAM (vs 24GB+ for Jaeger+ES)
├─ Pro: Modern best practice (2024)
├─ Pro: 100% trace retention
├─ Con: Only Trace ID search (kein full-text)
└─ Con: Smaller community (aber CNCF Incubating)

Option 3: Jaeger + Cassandra
├─ Pro: Learn Cassandra (industry knowledge)
├─ Pro: Better write throughput than ES
├─ Con: 24GB+ RAM (NEW cluster needed!)
├─ Con: Cassandra complexity (compaction, repair)
└─ Con: Kein S3 support
```

---

## 7. Final Recommendation

### 🎯 For This Homelab: **Grafana Tempo + Ceph RGW**

**Begründung**:

```yaml
1. Storage Synergy:
   ├─ Ceph RGW already deployed ✅
   ├─ Velero: s3://velero-backups
   ├─ Elasticsearch: s3://elasticsearch-snapshots
   └─ Tempo: s3://tempo-traces (NEW!)

2. Grafana Stack:
   ├─ Metrics: Grafana dashboards ✅
   ├─ Logs: Elasticsearch → Grafana datasource ✅
   └─ Traces: Tempo → Grafana datasource ✅
   → Single Pane of Glass! 🎯

3. Resource Efficiency:
   ├─ Elasticsearch: 27.5GB RAM (Logs only)
   ├─ Tempo: 2-4GB RAM (Traces)
   └─ Total: 30GB (vs 50GB+ mit Jaeger+ES)

4. Career Learning:
   ├─ Elasticsearch: Already learning via Logs ✅
   ├─ Grafana Tempo: Modern tracing (2024 best practice) ✅
   ├─ S3 Object Storage: Industry standard ✅
   └─ OpenTelemetry: Works with both Jaeger/Tempo ✅
```

### 🏭 If Choosing Jaeger (Alternative)

**Use Elasticsearch backend**:
- Official recommendation from Jaeger team
- Better search performance than Cassandra
- Reuse existing cluster knowledge
- Already have Elasticsearch deployed

**Configuration** (already implemented):
```yaml
storage:
  type: elasticsearch
  options:
    es:
      server-urls: https://production-cluster-es-http.elastic-system.svc:9200
      index-prefix: jaeger
```

---

## 8. References

### Official Documentation
- Jaeger Storage Backends: https://www.jaegertracing.io/docs/2.0/storage/
- Grafana Tempo S3: https://grafana.com/docs/tempo/latest/configuration/hosted-storage/s3/
- Grafana Tempo Config: https://grafana.com/docs/tempo/latest/configuration/

### Comparisons & Best Practices
- SigNoz - Jaeger vs Tempo: https://signoz.io/blog/jaeger-vs-tempo/
- SigNoz - Jaeger Database: https://signoz.io/guides/what-database-does-jaeger-use/
- Last9 - Tempo vs Jaeger: https://last9.io/blog/grafana-tempo-vs-jaeger/
- OpsVerse - Comprehensive Comparison: https://opsverse.io/2024/08/09/jaeger-vs-grafana-tempo-a-comprehensive-comparison-for-distributed-tracing/

### Industry Articles
- Logz.io - Jaeger Persistence: https://logz.io/blog/jaeger-persistence/
- CNCF Blog - Jaeger Storage: https://www.cncf.io/blog/2021/03/12/jaeger-persistent-storage-with-elasticsearch-cassandra-kafka/

---

## 9. Decision Tree - Which Solution?

```yaml
┌────────────────────────────────────────────────────────────────┐
│ Do you have Elasticsearch OR Cassandra expertise?              │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ✅ YES (Elasticsearch) → Jaeger + Elasticsearch ⭐ PRODUCTION  │
│    ├─ Official Jaeger Recommendation                           │
│    ├─ Full-Text Search                                         │
│    ├─ Reuse EFK/ELK Stack                                      │
│    └─ Production-Ready                                         │
│                                                                 │
│ ✅ YES (Cassandra) → Jaeger + Cassandra                        │
│    ├─ Better write throughput                                  │
│    ├─ Native TTL support                                       │
│    └─ Multi-DC replication                                     │
│                                                                 │
│ ❌ NO (Neither Elasticsearch NOR Cassandra)                    │
│    → Grafana Tempo + S3 ⭐ LIGHTWEIGHT ALTERNATIVE             │
│    ├─ Kein Database Cluster needed!                            │
│    ├─ S3/Ceph Object Storage only                              │
│    ├─ 2-4GB RAM (vs 24GB+ für ES/Cassandra)                   │
│    ├─ Works with Loki (statt Elasticsearch)                    │
│    └─ Modern Best Practice 2024                                │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 🏭 Production Stack Comparison

```yaml
┌─────────────────────────────────────────────────────────────────┐
│ Enterprise Stack (Big Teams)                                    │
├─────────────────────────────────────────────────────────────────┤
│ Metrics: Prometheus + Grafana                                  │
│ Logs:    Elasticsearch + Kibana + Fluentd                      │
│ Traces:  Jaeger + Elasticsearch                                │
│ Storage: Elasticsearch Cluster (24GB+ RAM)                     │
│                                                                 │
│ ✅ Full-Text Search everywhere                                  │
│ ✅ Mature ecosystem                                             │
│ ❌ High resource usage (50GB+ RAM)                             │
│ ❌ Complex operations (ES cluster management)                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Lightweight Stack (Small Teams / Budget-Conscious)             │
├─────────────────────────────────────────────────────────────────┤
│ Metrics: Prometheus + Grafana                                  │
│ Logs:    Loki + Promtail (S3 backend)                         │
│ Traces:  Grafana Tempo (S3 backend)                           │
│ Storage: S3/Ceph Object Storage                                │
│                                                                 │
│ ✅ Low resource usage (6GB RAM total)                           │
│ ✅ No database clusters                                         │
│ ✅ Grafana Single Pane of Glass                                │
│ ❌ Limited search (Trace ID / LogQL only)                      │
│ ❌ Smaller community                                            │
└─────────────────────────────────────────────────────────────────┘
```

### 🎓 Skill vs Solution Matrix

```yaml
Your Team Skills:
├─ Elasticsearch Expert? → Jaeger + Elasticsearch
├─ Cassandra Expert? → Jaeger + Cassandra
├─ MongoDB Expert (keine NoSQL außer Mongo)? → Grafana Tempo + S3
├─ Keine DB Skills? → Grafana Tempo + S3
└─ Budget <$100/month? → Grafana Tempo + S3

Learning Goals:
├─ Want to learn Elasticsearch? → EFK + Jaeger Stack
├─ Want to learn Cassandra? → Jaeger + Cassandra
├─ Want modern lightweight? → Loki + Tempo Stack
└─ Want both options? → Deploy BOTH! (compare & learn)
```

## 10. Next Steps

```yaml
⚙️  THIS HOMELAB: Jaeger + Elasticsearch ⭐ PRODUCTION
├─ 1. Verify Jaeger pods running (already deployed)
├─ 2. Check Elasticsearch indices created
├─ 3. Add Jaeger datasource to Grafana
├─ 4. Verify: OpenTelemetry → Jaeger → Elasticsearch
├─ 5. Test: Grafana can query traces
└─ 6. Document: Full-text search examples

REASON:
├─ ✅ Already have Elasticsearch (learning!)
├─ ✅ Official Jaeger Recommendation
├─ ✅ Production-Ready with full-text search
└─ ✅ Career skill: Elasticsearch + Jaeger

─────────────────────────────────────────────────────────────────

⚙️  ALTERNATIVE (For teams without ES/Cassandra):
    Grafana Tempo + Ceph S3 (Lightweight)
├─ 1. Deploy Grafana Tempo Operator
├─ 2. Create ObjectBucketClaim: tempo-traces
├─ 3. Configure Tempo with S3 backend
├─ 4. Add Tempo datasource to Grafana
├─ 5. Configure OpenTelemetry Collector → Tempo
└─ 6. Verify: Grafana can query traces

REASON:
├─ ✅ Works with Loki (statt Elasticsearch)
├─ ✅ S3/Ceph Object Storage (no DB cluster!)
├─ ✅ 2-4GB RAM (vs 24GB+ ES/Cassandra)
└─ ✅ Modern 2024 Best Practice

─────────────────────────────────────────────────────────────────

🚫 NOT RECOMMENDED: Jaeger + Cassandra
└─ Reason: Need Cassandra expertise + 24GB+ RAM cluster
```

---

## 11. Status & Decision

```yaml
✅ DECISION MADE: Jaeger + Elasticsearch (PRODUCTION)

Current State:
├─ ✅ Jaeger: Deployed with Elasticsearch backend
├─ ✅ OpenTelemetry Collector: Fixed endpoint (jaeger-collector.jaeger:4317)
├─ ✅ Elasticsearch: Production cluster running (3 nodes, 27.5GB RAM)
├─ ✅ Elasticsearch Secret: Copied to jaeger namespace
└─ ⏳ Apps: NOT instrumented yet (infrastructure only)

Reasoning:
├─ ✅ Already learning Elasticsearch (EFK Stack)
├─ ✅ Official Jaeger Team Recommendation
├─ ✅ Production-Ready with Full-Text Search
├─ ✅ Career Skill: Elasticsearch mastery
└─ ✅ No need to learn Cassandra (focus on MongoDB)

Alternative Documented:
└─ Grafana Tempo + S3 (für Teams ohne ES/Cassandra skills)

Next:
├─ 1. Verify Jaeger pods running
├─ 2. Check Elasticsearch indices created
├─ 3. Configure Grafana datasource
└─ 4. Test trace ingestion (NO app instrumentation yet)
```
