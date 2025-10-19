# Elasticsearch Complete Guide - Talos Homelab

## 📚 Table of Contents

1. [Was ist Elasticsearch?](#was-ist-elasticsearch)
2. [Kernkonzepte](#kernkonzepte)
3. [Data Streams vs. Regular Indices](#data-streams-vs-regular-indices)
4. [Warum wir Data Streams verwenden](#warum-wir-data-streams-verwenden)
5. [Architektur Diagramme](#architektur-diagramme)
6. [Best Practices Check](#best-practices-check)
7. [Cluster Pflege](#cluster-pflege)
8. [Technologie-Integration](#technologie-integration)

---

## Was ist Elasticsearch?

### Definition

**Elasticsearch** ist eine **verteilte, RESTful Suchmaschine** basierend auf Apache Lucene. Es ist spezialisiert auf:

- **Full-text search** (Volltextsuche)
- **Log-Analyse** (ELK/Elastic Stack)
- **Real-time analytics** (Echtzeit-Analysen)
- **Time-series data** (Zeitreihen-Daten)

### Probleme die Elasticsearch löst

| Problem | Lösung |
|---------|--------|
| **Millionen Logs durchsuchen** | Indiziert alle Felder → Suche in Millisekunden |
| **Log-Retention** | Automatische Rollover + ILM (Index Lifecycle Management) |
| **Zeitreihen-Analysen** | Optimiert für Logs mit `@timestamp` |
| **Horizontal skalieren** | Shards verteilen Daten auf mehrere Nodes |
| **Aggregationen** | Dashboard-Visualisierungen (Kibana, Grafana) |

### Use Cases

```
┌─────────────────────────────────────────────────────────┐
│ Elasticsearch Use Cases                                 │
├─────────────────────────────────────────────────────────┤
│ ✅ Application Logs (Vector → Elasticsearch)           │
│ ✅ Infrastructure Metrics (Prometheus → Elasticsearch)  │
│ ✅ APM Traces (OpenTelemetry → Elasticsearch)          │
│ ✅ Security Events (SIEM - Elastic Security)           │
│ ✅ Business Analytics (Product search, recommendations) │
└─────────────────────────────────────────────────────────┘
```

---

## Kernkonzepte

### 1. **Index** (Plural: Indices)

Ein **Index** ist eine Sammlung von Dokumenten mit ähnlicher Struktur.

**Analogie:**
- **Relationale DB** → Tabelle
- **Elasticsearch** → Index

**Beispiel:**
```
Index: logs-nginx-production
Document 1: { "@timestamp": "2025-10-19T12:00:00Z", "status": 200, "path": "/api/users" }
Document 2: { "@timestamp": "2025-10-19T12:01:00Z", "status": 404, "path": "/notfound" }
```

### 2. **Document**

Ein **Document** ist ein JSON-Objekt (vergleichbar mit einer Zeile in SQL).

```json
{
  "@timestamp": "2025-10-19T21:13:36Z",
  "service.name": "kube-system",
  "log.level": "info",
  "message": "Pod started successfully",
  "kubernetes.namespace": "kube-system",
  "kubernetes.pod": "coredns-abc123"
}
```

### 3. **Shard**

Ein **Shard** ist eine Lucene-Instanz (ein Teil des Index).

**Warum Shards?**
- **Horizontal scaling**: 1 Index kann über mehrere Nodes verteilt werden
- **Parallelisierung**: Queries laufen parallel auf allen Shards

**Beispiel:**
```
Index: logs-nginx-production (10 GB Daten)
├─ Shard 0: 2 GB (auf Node 1)
├─ Shard 1: 2 GB (auf Node 2)
├─ Shard 2: 2 GB (auf Node 3)
├─ Shard 3: 2 GB (auf Node 1)
└─ Shard 4: 2 GB (auf Node 2)
```

### 4. **Replica**

Eine **Replica** ist eine Kopie eines Shards (High Availability).

**Beispiel:**
```
Primary Shard 0 (Node 1) → Replica Shard 0 (Node 2)
```

**Benefit:**
- Wenn Node 1 ausfällt → Replica wird zum Primary
- Queries können von Replicas gelesen werden (Load Balancing)

### 5. **Mapping**

**Mapping** definiert das Schema (Feldtypen).

**Beispiel:**
```json
{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "log.level": { "type": "keyword" },
      "message": { "type": "text" },
      "kubernetes.namespace": { "type": "keyword" }
    }
  }
}
```

**Feldtypen:**
- `keyword`: Exakte Suche (Tags, IDs, Enums)
- `text`: Full-text search (Logs, Beschreibungen)
- `date`: Timestamps
- `long`, `double`: Numerische Werte

---

## Data Streams vs. Regular Indices

### Was sind Data Streams?

**Data Streams** sind eine Elasticsearch-Abstraktion für **append-only time-series data** (Logs, Metrics, Events).

### Architektur-Vergleich

#### **Regular Indices (Old Way)**

```
Index: vector-logs-2025.10.19
Index: vector-logs-2025.10.20
Index: vector-logs-2025.10.21
...

❌ Problem: Manually create/delete indices
❌ Problem: No automatic rollover
❌ Problem: Hard to query across dates
```

#### **Data Streams (Modern Way)**

```
Data Stream: logs-nginx-production
├─ Backing Index: .ds-logs-nginx-production-2025.10.19-000001
├─ Backing Index: .ds-logs-nginx-production-2025.10.20-000002
└─ Backing Index: .ds-logs-nginx-production-2025.10.21-000003

✅ Automatic rollover (based on size/age)
✅ Query ONE data stream name → Elasticsearch searches all backing indices
✅ ILM auto-deletes old indices
```

### Naming Convention

**Elastic Best Practice:**
```
{type}-{dataset}-{namespace}

Beispiele:
- logs-nginx.access-production
- logs-kube-system.critical-default
- logs-proxmox.warn-nipogi
- metrics-kubernetes.pod-default
- traces-frontend.http-staging
```

**Komponenten:**
- `type`: `logs`, `metrics`, `traces`
- `dataset`: `nginx.access`, `kube-system.critical`, `proxmox.warn`
- `namespace`: `production`, `default`, `nipogi`, `staging`

### Warum Data Streams verwenden?

| Feature | Regular Index | Data Stream |
|---------|---------------|-------------|
| **Automatic rollover** | ❌ Manual | ✅ Automatic (ILM) |
| **Time-series optimized** | ⚠️ Requires config | ✅ Built-in |
| **Query across time** | ⚠️ Wildcard `logs-*` | ✅ Single name `logs-nginx-production` |
| **Immutable data** | ⚠️ Update/Delete allowed | ✅ Append-only (safe for logs) |
| **ILM integration** | ⚠️ Manual setup | ✅ Automatic |
| **ECS compliance** | ⚠️ Manual | ✅ Built-in |

### Unser Setup

**Vector Configuration:**
```toml
[sinks.elasticsearch]
type = "elasticsearch"
mode = "data_stream"  # ← DATA STREAMS!
data_stream.type = "logs"
data_stream.dataset = "{{ service_name }}.{{ severity }}"
data_stream.namespace = "{{ namespace_suffix }}"
```

**Resultierende Data Streams:**
```
logs-kube-system.info-default
logs-rook-ceph.warn-default
logs-proxmox.critical-nipogi
logs-n8n-prod.error-default
logs-kafka.info-default
```

**Vorteile:**
1. **Auto-Rollover**: Wenn Index 50GB erreicht → neuer Backing Index
2. **Auto-Retention**: Alte Indices werden nach 30 Tagen gelöscht (ILM)
3. **Query Simplicity**: `GET logs-kube-system.info-default/_search` findet ALLE Backing Indices
4. **ECS Compliance**: Elastic Common Schema ist automatisch kompatibel

---

## Architektur Diagramme

### 1. Elasticsearch Cluster Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│ ELASTICSEARCH CLUSTER (3 Nodes)                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Node 1          │  │ Node 2          │  │ Node 3          │ │
│  │ (Master + Data) │  │ (Data)          │  │ (Data)          │ │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤ │
│  │ Shard 0 (P)     │  │ Shard 0 (R)     │  │ Shard 1 (R)     │ │
│  │ Shard 1 (P)     │  │ Shard 2 (P)     │  │ Shard 2 (R)     │ │
│  │ Shard 3 (P)     │  │ Shard 3 (R)     │  │ Shard 0 (R)     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                   │
│  P = Primary Shard   R = Replica Shard                          │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Log Flow: Vector → Elasticsearch Data Streams

```
┌───────────────────────────────────────────────────────────────────────┐
│ LOG INGESTION PIPELINE                                                │
└───────────────────────────────────────────────────────────────────────┘

   ┌─────────────┐
   │ Kubernetes  │
   │ Pods        │
   └──────┬──────┘
          │ Container logs (/var/log/pods/*)
          ▼
   ┌─────────────┐
   │ Vector Agent│ (DaemonSet on each node)
   │ (Collector) │
   └──────┬──────┘
          │ gRPC Protocol (port 6000)
          ▼
   ┌─────────────┐
   │ Vector      │ (Deployment - 2 replicas)
   │ Aggregator  │
   └──────┬──────┘
          │ Transform + Enrich (VRL)
          │ - Add ECS fields
          │ - Extract namespace_suffix
          │ - Route by service_name + severity
          ▼
   ┌──────────────────────────────────────────────┐
   │ Elasticsearch Data Streams                   │
   ├──────────────────────────────────────────────┤
   │ logs-kube-system.info-default               │
   │ ├─ .ds-logs-kube-system.info-default-000001 │
   │ └─ .ds-logs-kube-system.info-default-000002 │
   │                                              │
   │ logs-proxmox.warn-nipogi                     │
   │ ├─ .ds-logs-proxmox.warn-nipogi-000001      │
   │ └─ .ds-logs-proxmox.warn-nipogi-000002      │
   │                                              │
   │ logs-n8n-prod.critical-default               │
   │ └─ .ds-logs-n8n-prod.critical-default-000001│
   └──────────────────────────────────────────────┘
          │
          ▼
   ┌─────────────┐
   │ Kibana      │ (Query & Visualize)
   │ Discover    │
   └─────────────┘
```

### 3. Data Stream Lifecycle (ILM)

```
┌─────────────────────────────────────────────────────────────────┐
│ INDEX LIFECYCLE MANAGEMENT (ILM)                                │
└─────────────────────────────────────────────────────────────────┘

  Day 0-7: HOT Phase
  ┌──────────────────────────────────────┐
  │ .ds-logs-nginx-prod-2025.10.19-000001│
  │ - Fast SSD storage                   │
  │ - High IOPS                          │
  │ - Actively written                   │
  └──────────────────────────────────────┘
           │ Rollover (50GB or 7 days)
           ▼
  Day 7-30: WARM Phase
  ┌──────────────────────────────────────┐
  │ .ds-logs-nginx-prod-2025.10.12-000002│
  │ - Slower storage                     │
  │ - Read-only                          │
  │ - Replicas reduced (1 → 0)           │
  └──────────────────────────────────────┘
           │ Age > 30 days
           ▼
  Day 30+: DELETE Phase
  ┌──────────────────────────────────────┐
  │ ❌ Index deleted                      │
  └──────────────────────────────────────┘
```

### 4. ECS Field Mapping

```
┌─────────────────────────────────────────────────────────────────┐
│ ELASTIC COMMON SCHEMA (ECS) 8.17                                │
└─────────────────────────────────────────────────────────────────┘

Raw Log:
{
  "message": "User login successful",
  "level": "info",
  "user": "tim275",
  "ip": "192.168.68.10"
}

         ▼ Vector Transform (VRL) ▼

ECS-Compliant Log:
{
  "@timestamp": "2025-10-19T21:13:36.195024083Z",
  "ecs.version": "8.17",
  "log.level": "info",                    ← ECS standard
  "message": "User login successful",
  "user.id": "tim275",                    ← ECS standard
  "source.ip": "192.168.68.10",           ← ECS standard
  "service.name": "authelia",             ← ECS standard
  "service.environment": "production",    ← ECS standard
  "event.dataset": "authelia.auth",
  "event.severity": "info"
}
```

---

## Best Practices Check

### ✅ Unser Cluster Status

| Best Practice | Status | Implementation |
|---------------|--------|----------------|
| **Data Streams statt Indices** | ✅ YES | `mode = "data_stream"` in Vector |
| **ECS 8.17 Compliance** | ✅ YES | All fields mapped to ECS schema |
| **Service-based routing** | ✅ YES | `dataset = "{{ service_name }}.{{ severity }}"` |
| **Namespace differentiation** | ✅ YES | `namespace = "{{ namespace_suffix }}"` (nipogi, msa2proxmox) |
| **ILM Lifecycle Policies** | ⚠️ PARTIAL | Need to configure retention (currently default) |
| **Shard allocation** | ✅ YES | Auto-managed by Elasticsearch |
| **Replica count** | ✅ YES | 1 replica for HA |
| **Buffering** | ✅ YES | Vector disk buffer (256MB) |
| **Batch size optimization** | ✅ YES | 10MB batches |

### ⚠️ Empfehlungen

1. **ILM Policy konfigurieren** (siehe unten)
2. **Index Templates** für Custom Mappings
3. **Snapshot Backup** (Velero bereits vorhanden)

---

## Cluster Pflege

### 1. Monitoring

#### **Cluster Health**
```bash
# Cluster Status
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k https://localhost:9200/_cluster/health?pretty

# Expected Output:
{
  "status": "green",       # ✅ green = all shards allocated
  "number_of_nodes": 3,
  "active_primary_shards": 150,
  "active_shards": 300     # 150 primary + 150 replicas
}
```

#### **Index Stats**
```bash
# Data Stream Übersicht
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k https://localhost:9200/_cat/indices/.ds-logs-*?v

# Output:
health status index                                     pri rep docs.count store.size
green  open   .ds-logs-kube-system.info-default-000001  1   1     150000    250mb
green  open   .ds-logs-proxmox.warn-nipogi-000001       1   1       5000     10mb
```

#### **ILM Status**
```bash
# ILM Policies
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k https://localhost:9200/_ilm/policy?pretty
```

### 2. ILM Policy (Empfehlung)

**Erstelle eine Retention Policy:**

```bash
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -X PUT -k "https://localhost:9200/_ilm/policy/logs-30day-retention" \
  -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "7d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "set_priority": {
            "priority": 50
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
}'
```

**Erklärung:**
- **HOT**: Neue Logs bleiben 7 Tage oder bis 50GB
- **WARM**: Nach 7 Tagen → niedrigere Priorität (langsamer Storage)
- **DELETE**: Nach 30 Tagen → automatisch gelöscht

### 3. Disk Usage überwachen

```bash
# Disk Watermark Check
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -s -k https://localhost:9200/_nodes/stats/fs?pretty | \
  jq '.nodes | .[] | .fs.total'

# Expected:
{
  "total_in_bytes": 107374182400,  # 100GB
  "free_in_bytes": 53687091200,    # 50GB free (50% used - OK)
  "available_in_bytes": 53687091200
}
```

**Warnschwellen:**
- **85% used**: Elasticsearch stoppt neue Shard-Allocations
- **90% used**: Elasticsearch setzt Indices auf read-only
- **95% used**: KRITISCH! Sofort aufräumen

### 4. Backup (Velero)

**Wir haben bereits Velero installiert!**

```bash
# Elasticsearch Snapshot via Velero
velero backup create elasticsearch-backup \
  --include-namespaces elastic-system \
  --include-resources persistentvolumeclaims,persistentvolumes

# Restore
velero restore create --from-backup elasticsearch-backup
```

### 5. Index Cleanup (Manual)

```bash
# Alte Indices manuell löschen (falls ILM nicht aktiv)
kubectl exec -n elastic-system production-cluster-es-master-data-0 -- \
  curl -X DELETE -k "https://localhost:9200/.ds-logs-old-index-2025.09.*"
```

### 6. Performance Tuning

#### **Heap Size**
```yaml
# In elasticsearch.yaml
spec:
  nodeSets:
  - name: master-data
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms2g -Xmx2g"  # 50% of pod memory
```

**Regel:**
- Heap Size = 50% des Pod-Memory
- Max Heap = 31GB (Compressed OOPs)

#### **Refresh Interval**
```bash
# Für High-Throughput Logs: Refresh seltener
curl -X PUT "https://localhost:9200/logs-*/_settings" -d'
{
  "index": {
    "refresh_interval": "30s"  # Default: 1s
  }
}'
```

### 7. Troubleshooting

#### **Yellow Cluster (Unassigned Shards)**
```bash
# Diagnose
curl "https://localhost:9200/_cluster/allocation/explain?pretty"

# Fix: Reallocate
curl -X POST "https://localhost:9200/_cluster/reroute?retry_failed=true"
```

#### **Red Cluster (Primary Shards fehlen)**
```bash
# Checke fehlende Shards
curl "https://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason"

# Letzter Ausweg: Force allocate (DATENVERLUST möglich!)
curl -X POST "https://localhost:9200/_cluster/reroute" -d'
{
  "commands": [{
    "allocate_empty_primary": {
      "index": "logs-xyz",
      "shard": 0,
      "node": "node-1",
      "accept_data_loss": true
    }
  }]
}'
```

---

## Technologie-Integration

### Mit was arbeitet Elasticsearch zusammen?

```
┌─────────────────────────────────────────────────────────────────┐
│ ELASTIC STACK (ELK)                                             │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  LOGSTASH    │──────│ ELASTICSEARCH│──────│   KIBANA     │
│  (Ingest)    │      │  (Storage)   │      │ (Visualize)  │
└──────────────┘      └──────────────┘      └──────────────┘
      ▲                       │                     │
      │                       ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ BEATS        │      │  APM SERVER  │      │  GRAFANA     │
│ (Filebeat,   │      │ (Traces)     │      │ (Dashboards) │
│  Metricbeat) │      └──────────────┘      └──────────────┘
└──────────────┘
```

### Unser Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ TALOS HOMELAB OBSERVABILITY STACK                               │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  VECTOR      │──────│ ELASTICSEARCH│──────│   KIBANA     │
│  (Replace    │      │  (ECK 2.16)  │      │  (Discover)  │
│   Logstash)  │      │              │      │              │
└──────────────┘      └──────────────┘      └──────────────┘
      ▲                       │                     │
      │                       ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ KUBERNETES   │      │ OPENTELEMETRY│      │  GRAFANA     │
│ Pods         │      │ (Traces)     │      │ (Dashboards) │
└──────────────┘      └──────────────┘      └──────────────┘
      ▲
      │
┌──────────────┐
│ PROXMOX      │
│ (Syslog)     │
└──────────────┘
```

### Alternativen zu Elasticsearch

| Tool | Use Case | Vergleich |
|------|----------|-----------|
| **Loki** | Logs (low resource) | ✅ Weniger RAM, ❌ Keine Full-text search |
| **ClickHouse** | Time-series analytics | ✅ Schneller für Aggregationen, ❌ Kein Full-text |
| **OpenSearch** | Fork von Elasticsearch | ✅ Open Source, ⚠️ Weniger Features |
| **Splunk** | Enterprise logging | ✅ Mehr Features, ❌ Teuer |
| **Datadog** | SaaS Observability | ✅ Managed, ❌ Teuer + Cloud-only |

---

## Zusammenfassung

### Was wir haben

✅ **Elasticsearch 8.17** mit ECK Operator
✅ **Data Streams** statt Regular Indices
✅ **ECS 8.17 Compliance** für alle Logs
✅ **Vector Aggregator** mit service-based routing
✅ **Namespace Differentiation** (nipogi, msa2proxmox, default)
✅ **Kibana Data Views** (23 Views nach Best Practices)
✅ **Velero Backup** für Disaster Recovery

### Was fehlt (optional)

⚠️ **ILM Retention Policy** (30 Tage Auto-Delete)
⚠️ **Index Templates** für Custom Mappings
⚠️ **Alerting** via Elasticsearch Watcher oder Keep
⚠️ **Snapshot Repository** (S3 oder Ceph RGW)

### Next Steps

1. **Kibana öffnen**: http://localhost:5601
2. **Data Views checken**: "Proxmox - Nipogi Host"
3. **ILM Policy anlegen**: 30-Tage Retention
4. **Monitoring Dashboard** in Grafana

---

**Erstellt für:** Talos Homelab
**Datum:** 2025-10-19
**Elasticsearch Version:** 8.17.0
**ECK Operator:** 2.16.0
