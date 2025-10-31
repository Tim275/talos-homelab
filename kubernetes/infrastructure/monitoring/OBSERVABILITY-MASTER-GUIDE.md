# Observability Master Guide - Talos Homelab Production Setup

## 📖 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Was ist Grafana?](#was-ist-grafana)
3. [Grafana Operator vs Helm Chart](#grafana-operator-vs-helm-chart)
4. [Was ist Prometheus?](#was-ist-prometheus)
5. [Prometheus Operator Magie](#prometheus-operator-magie)
6. [Was ist Loki?](#was-ist-loki)
7. [Was ist Tempo?](#was-ist-tempo)
8. [Was ist Thanos?](#was-ist-thanos)
9. [Unser Production Setup](#unser-production-setup)
10. [Complete Architecture](#complete-architecture)
11. [ServiceMonitor → Dashboard (No Data Fix!)](#servicemonitor--dashboard-no-data-fix)
12. [Grafana Dashboards Deep Dive](#grafana-dashboards-deep-dive)
13. [Prometheus Metrics Pipeline](#prometheus-metrics-pipeline)
14. [Loki Log Pipeline](#loki-log-pipeline)
15. [Tempo Trace Pipeline](#tempo-trace-pipeline)
16. [Thanos Long-term Storage](#thanos-long-term-storage)
17. [Best Practices](#best-practices)
18. [Daily Operations](#daily-operations)
19. [Troubleshooting](#troubleshooting)
20. [Performance Optimization](#performance-optimization)
21. [Backup & Disaster Recovery](#backup--disaster-recovery)
22. [Quick Reference](#quick-reference)

---

## Executive Summary

### TL;DR - Was haben wir gebaut?

```
┌─────────────────────────────────────────────────────────────────┐
│ ENTERPRISE OBSERVABILITY STACK (100% IaC)                       │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Grafana Operator - 68 Enterprise Dashboards (CRDs!)         │
│ ✅ Prometheus Operator - Auto-Discovery via ServiceMonitors    │
│ ✅ Loki - Log Aggregation (LogQL queries)                      │
│ ✅ Tempo - Distributed Tracing (OTLP + Jaeger)                 │
│ ✅ Jaeger - Trace Frontend (Tempo Backend)                     │
│ ✅ Thanos - Unlimited Metrics Storage (Ceph S3)                │
│ ✅ Alertmanager + Robusta AI - Dual Alerting                   │
│ ✅ 100% GitOps (ArgoCD synced)                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 Was macht das Stack so gut?

**IKEA-Analogie:** Du kaufst ein Regal (Grafana Operator), alle Schrauben sind dabei (CRDs), und es baut sich selbst zusammen (GitOps)! 🛠️

```
┌────────────────────────────────────────────────┐
│ Alte Methode (Helm Chart):                    │
│ 1. helm install grafana                       │
│ 2. Dashboard manuell via UI importieren       │
│ 3. Bei Cluster-Neustart: Weg! 💥              │
│ 4. Backup? Manuell! 😰                        │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ Neue Methode (Grafana Operator + CRDs):       │
│ 1. kubectl apply -f dashboard.yaml            │
│ 2. Fertig! ✅                                 │
│ 3. Bei Cluster-Neustart: Auto-restored! 🎉    │
│ 4. Backup? Git commit! 🚀                     │
└────────────────────────────────────────────────┘
```

### Key Metrics

| Metric | Value |
|--------|-------|
| **Grafana Dashboards** | 68 (als CRDs) |
| **Prometheus Targets** | 150+ |
| **Metrics Collected** | 500,000+ time-series |
| **Loki Log Streams** | 50+ |
| **Tempo Traces** | Production-ready (OTLP + Jaeger) |
| **Tempo Retention** | 30 days (Ceph S3) |
| **Prometheus Retention** | 30 days (local) |
| **Thanos Retention** | Unlimited (Ceph S3) |
| **Alert Rules** | 100+ (Tier 0-5) |
| **Query Performance** | <100ms avg |
| **Total Storage** | 500 GB (Prometheus + Loki + Tempo) |

### Tech Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ COMPLETE OBSERVABILITY STACK - THE THREE PILLARS               │
└─────────────────────────────────────────────────────────────────┘

App Pods (N8N, Kafka, PostgreSQL, etc.)
    ↓
    ├─ STDOUT/STDERR Logs ──────────> Promtail ──> Loki (Logs)
    ├─ /metrics Endpoint ───────────> Prometheus (Metrics)
    └─ OTLP Traces ─────────────────> Tempo (Traces)
                                           ↓
                                       Thanos (S3 Storage)
                                           ↓
                                       Grafana (68 Dashboards)
                                           ├─ Explore Logs (Loki)
                                           ├─ Explore Metrics (Prometheus)
                                           └─ Explore Traces (Tempo)
                                                   ↓
                                           Jaeger UI (Traces Frontend)
                                                   ↓
                                               Browser (User)
```

---

## Was ist Grafana?

### Definition (IKEA-Style)

**Grafana** = Dein **Fernseher** für Kubernetes 📺

- Zeigt **Metriken** (Prometheus) = Live TV 📊
- Zeigt **Logs** (Loki) = Untertitel 📝
- Zeigt **Traces** (Jaeger) = Behind-the-Scenes 🎬
- Macht **Alerts** (Alertmanager) = Notfall-SMS 🚨

### Use Cases

```
┌─────────────────────────────────────────────────────────────────┐
│ WAS KANN GRAFANA?                                               │
├─────────────────────────────────────────────────────────────────┤
│ 1. Dashboards  → Charts, Graphs, Tables                        │
│ 2. Alerts      → Slack, Email, PagerDuty                       │
│ 3. Datasources → Prometheus, Loki, Elasticsearch               │
│ 4. Folders     → Dashboard Organization                        │
│ 5. Teams       → Multi-Tenancy (wenn du viele User hast)       │
└─────────────────────────────────────────────────────────────────┘
```

### Core Concepts

#### 1. **Dashboard** - Deine Monitoring-Seite

Ein Dashboard = Eine Webseite mit Charts

**Beispiel:**
```
Dashboard: "Kubernetes Cluster Overview"
├─ Panel 1: CPU Usage (Graph)
├─ Panel 2: Memory Usage (Graph)
├─ Panel 3: Pod Count (Stat)
└─ Panel 4: Disk Usage (Gauge)
```

#### 2. **Datasource** - Woher kommen die Daten?

Datasource = Datenquelle (Prometheus, Loki, etc.)

**Unsere Datasources:**
```
├─ Prometheus (metrics)        → http://prometheus:9090
├─ Loki (logs)                 → http://loki:3100
├─ Alertmanager (alerts)       → http://alertmanager:9093
└─ Jaeger (traces)             → http://jaeger:16686
```

#### 3. **Panel** - Ein einzelner Chart

Panel = Ein Graph/Table/Stat auf dem Dashboard

**Panel Types:**
```
├─ Graph      → Line chart (CPU over time)
├─ Stat       → Single number (Pod count: 42)
├─ Table      → Tabelle (Pod list)
├─ Gauge      → Speedometer (Disk 75%)
├─ Heatmap    → Latency distribution
└─ Logs       → Log viewer (Loki)
```

#### 4. **Folder** - Dashboard Organization

Folder = Ordner (wie in Windows Explorer)

**Unsere Folder:**
```
Grafana UI
├─ ArgoCD
├─ Ceph Storage
├─ Cert-Manager
├─ Cilium
├─ Elasticsearch
├─ GPU & ML
├─ Istio
├─ Kafka
├─ Kubernetes
├─ Loki
├─ OpenTelemetry
├─ PostgreSQL
├─ Prometheus
├─ Redis
├─ Security
├─ SLO & Reliability
├─ Tier 0 Executive
└─ Velero
```

---

## Grafana Operator vs Helm Chart

### ⚔️ Der große Vergleich

```
┌─────────────────────────────────────────────────────────────────┐
│ HELM CHART (Old Way)                                            │
└─────────────────────────────────────────────────────────────────┘

Step 1: Install Helm chart
  helm install grafana grafana/grafana

Step 2: Port-forward to UI
  kubectl port-forward svc/grafana 3000:3000

Step 3: Login to UI (manual)
  http://localhost:3000
  Username: admin
  Password: (from secret)

Step 4: Import dashboard (manual!)
  - Click "Dashboards" → "Import"
  - Paste JSON
  - Click "Import"
  - Repeat 68 times... 😱

Step 5: Configure datasource (manual!)
  - Click "Configuration" → "Data Sources"
  - Add Prometheus
  - Set URL: http://prometheus:9090
  - Click "Save & Test"

❌ Problems:
  - Manual UI work
  - Not in Git
  - Lost on cluster restart
  - No GitOps
  - No validation
  - No versioning
```

```
┌─────────────────────────────────────────────────────────────────┐
│ GRAFANA OPERATOR (New Way) ✨                                   │
└─────────────────────────────────────────────────────────────────┘

Step 1: Install Grafana Operator
  kubectl apply -k kubernetes/infrastructure/monitoring/grafana-operator/

Step 2: Create Grafana CRD
  kubectl apply -f grafana.yaml

Step 3: Create Dashboard CRD
  kubectl apply -f dashboard.yaml

Step 4: Fertig! ✅

✅ Benefits:
  - Everything in Git
  - Auto-applied on push
  - Validated by Kubernetes
  - Versioned via Git
  - Type-safe (CRD schema)
  - GitOps-ready
```

### 🎯 Warum Grafana Operator besser ist

**IKEA-Analogie:**

```
┌────────────────────────────────────────────────────────────────┐
│ Helm Chart = IKEA-Regal ohne Anleitung 📦                     │
│ - Du musst jede Schraube selbst einsetzen                     │
│ - Wenn du vergisst wo, ist es kaputt                          │
│ - Bei Umzug: Alles neu aufbauen                               │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Grafana Operator = IKEA-Regal mit Auto-Aufbau 🤖              │
│ - Du gibst Plan (YAML), Operator baut auf                     │
│ - Wenn kaputt: Operator repariert automatisch                 │
│ - Bei Umzug: Operator baut automatisch neu auf                │
└────────────────────────────────────────────────────────────────┘
```

### Konkrete Vorteile

#### 1. **Declarative Configuration (YAML = Plan)**

**Helm (Imperative):**
```bash
# Du musst sagen WIE
helm install grafana grafana/grafana --set admin.password=secret
# → Operator weiß nicht was du willst, führt nur Befehl aus
```

**Operator (Declarative):**
```yaml
# Du sagst WAS du willst
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
spec:
  config:
    security:
      admin_password: secret
# → Operator versteht dein Ziel, baut es selbst
```

#### 2. **Self-Healing (Auto-Reparatur)**

**Helm:**
```
Wenn Dashboard gelöscht wird:
  → Weg, für immer 💥
  → Du musst manuell re-importieren
```

**Operator:**
```
Wenn Dashboard gelöscht wird:
  → Operator sieht: "Hey, dashboard.yaml sagt Dashboard soll da sein!"
  → Operator erstellt Dashboard neu ✅
  → Auto-Healing! 🎉
```

#### 3. **Type Safety (Kubernetes Validation)**

**Helm:**
```yaml
# values.yaml
dashbord: "my-dash"  # Typo! Aber Helm sagt nichts 😱
```

**Operator:**
```yaml
# dashboard.yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: my-dash
spec:
  folder: "ArgoCD"
  foldr: "Oops"  # ❌ Kubernetes sagt: "Field 'foldr' unknown!" ✅
```

#### 4. **GitOps (ArgoCD Auto-Sync)**

**Helm:**
```
git commit → git push → kubectl apply manuell
```

**Operator:**
```
git commit → git push → ArgoCD sieht Änderung → Auto-Apply! 🚀
```

#### 5. **Backup = Git Commit!**

**Helm:**
```bash
# Backup? Manuell...
kubectl get configmap grafana-dashboards -o yaml > backup.yaml
# Restore? Auch manuell...
kubectl apply -f backup.yaml
```

**Operator:**
```bash
# Backup = Git!
git commit -m "Add dashboard"
git push

# Restore = Git!
git checkout old-commit
kubectl apply -f dashboard.yaml
```

### 📊 Vergleichstabelle

| Feature | Helm Chart | Grafana Operator |
|---------|------------|------------------|
| **Dashboard Import** | Manual UI | `kubectl apply -f` |
| **Configuration** | values.yaml | GrafanaDashboard CRD |
| **GitOps** | ⚠️ Schwer | ✅ Native |
| **Type Safety** | ❌ Nein | ✅ Ja (CRD Schema) |
| **Self-Healing** | ❌ Nein | ✅ Ja |
| **Backup** | Manual export | Git commit |
| **Validation** | ⚠️ Helm lint | ✅ Kubernetes API |
| **Versioning** | Helm release | Git history |
| **Multi-Dashboard** | 68x manual | 68x `kubectl apply` |

**Winner:** Grafana Operator 🏆

---

## Was ist Prometheus?

### Definition (IKEA-Style)

**Prometheus** = Dein **Stromzähler** für Kubernetes ⚡

- Sammelt **Metrics** (CPU, RAM, Requests)
- Speichert in **Time-Series Database** (TSDB)
- Macht **Alerts** (wenn CPU > 80%)
- Hat **PromQL** (Abfragesprache wie SQL)

### Use Cases

```
┌─────────────────────────────────────────────────────────────────┐
│ WAS ÜBERWACHT PROMETHEUS?                                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. System Metrics    → CPU, RAM, Disk (Node Exporter)          │
│ 2. Kubernetes Metrics→ Pods, Deployments (kube-state-metrics)  │
│ 3. App Metrics       → Requests, Latency (deine App)           │
│ 4. Custom Metrics    → Business KPIs (z.B. Sales/hour)         │
└─────────────────────────────────────────────────────────────────┘
```

### Core Concepts

#### 1. **Metric** - Eine Zahl die sich ändert

```
Metric: node_cpu_seconds_total
├─ Type: Counter (immer steigend)
├─ Value: 123456 (CPU seconds)
└─ Labels: {cpu="0", mode="idle"}
```

**Metric Types:**
```
Counter   → Immer steigend (Requests total: 1000, 1001, 1002...)
Gauge     → Rauf und runter (CPU: 50%, 80%, 30%...)
Histogram → Verteilung (Latency: 50ms, 100ms, 200ms...)
Summary   → Quantile (p50, p95, p99)
```

#### 2. **Label** - Kategorien

Labels = Tags/Filter für Metrics

**Beispiel:**
```
http_requests_total{method="GET", status="200"} = 1000
http_requests_total{method="POST", status="500"} = 5

→ Mit Labels kannst du filtern:
  - Alle GET requests
  - Alle 500 errors
  - POST requests mit 200 OK
```

#### 3. **Scrape** - Daten sammeln

Prometheus **scraped** (sammelt) Metrics von Apps

```
Step 1: App hat /metrics endpoint
  curl http://my-app:8080/metrics
  # HELP http_requests_total Total HTTP requests
  # TYPE http_requests_total counter
  http_requests_total{method="GET"} 1000

Step 2: Prometheus scraped alle 15 Sekunden
  Prometheus → http://my-app:8080/metrics → Speichert in TSDB

Step 3: Du queried mit PromQL
  rate(http_requests_total[5m])
  → Zeigt Requests/sec über letzte 5 Minuten
```

#### 4. **PromQL** - Query Language

PromQL = SQL für Time-Series

**Beispiele:**
```promql
# CPU Usage (%)
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage (GB)
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# HTTP Error Rate (%)
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# Top 5 Pods by CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))
```

---

## Prometheus Operator Magie

### 🪄 Warum Prometheus Operator so geil ist

**Vanilla Prometheus (Old Way):**
```yaml
# prometheus.yml (Manual config)
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:8080']
```

**Problem:** Du musst **JEDE App manuell** eintragen! 😱

**Prometheus Operator (New Way):**
```yaml
# ServiceMonitor CRD (Auto-Discovery!)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
```

**Magie:** Prometheus **findet automatisch** alle Services mit Label `app: my-app`! 🎉

### ServiceMonitor = Auto-Discovery

**IKEA-Analogie:**

```
┌────────────────────────────────────────────────────────────────┐
│ Vanilla Prometheus = Du musst jede Schraube einzeln zählen    │
│ - Neue App? → Manuell in prometheus.yml eintragen             │
│ - App deleted? → Manuell aus prometheus.yml entfernen         │
│ - Neue Replica? → Manuell alle IPs eintragen                  │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Prometheus Operator = IKEA zählt automatisch                  │
│ - Neue App? → ServiceMonitor sagt "Scrape alles mit Label X"  │
│ - App deleted? → Prometheus sieht das selbst                  │
│ - Neue Replica? → Prometheus findet sie automatisch via K8s   │
└────────────────────────────────────────────────────────────────┘
```

### Konkrete Beispiele

#### Beispiel 1: N8N Metrics scrapen

**Ohne Operator:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'n8n-prod'
    static_configs:
      - targets:
        - n8n-prod-0.n8n-prod.n8n-prod.svc.cluster.local:5678
        - n8n-prod-1.n8n-prod.n8n-prod.svc.cluster.local:5678
        # Oh nein, neue Replica? Manuell hinzufügen... 😰
```

**Mit Operator:**
```yaml
# servicemonitor-n8n.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: n8n-prod
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - n8n-prod
  selector:
    matchLabels:
      app: n8n
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

**Fertig!** Prometheus scraped **ALLE** N8N Pods automatisch! 🚀

#### Beispiel 2: Kafka Metrics scrapen

**ServiceMonitor:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - kafka-demo-dev
  selector:
    matchLabels:
      strimzi.io/kind: Kafka
  endpoints:
  - port: tcp-prometheus
    interval: 30s
```

**Prometheus findet automatisch:**
- Alle Kafka Brokers
- Alle Kafka Producers
- Alle Kafka Consumers
- Alle Zookeeper Nodes (falls verwendet)

### ServiceMonitor CRD Struktur

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app                      # Name des ServiceMonitors
  namespace: monitoring              # Namespace (meist 'monitoring')
  labels:
    app: my-app                      # Optional: Labels für Organization
spec:
  # WELCHE Services scrapen?
  namespaceSelector:
    matchNames:
    - my-app-namespace               # Nur Services in diesem Namespace

  # WELCHE Labels haben die Services?
  selector:
    matchLabels:
      app: my-app                    # Service muss Label "app: my-app" haben

  # WO ist der /metrics endpoint?
  endpoints:
  - port: metrics                    # Port name (aus Service)
    path: /metrics                   # URL path
    interval: 30s                    # Scrape interval
    scheme: http                     # http oder https

    # Optional: Relabeling
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod
```

### PodMonitor (Alternative)

Manchmal haben Pods **keinen Service** (z.B. DaemonSets)

**PodMonitor = Scrape direkt von Pods**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app: node-exporter
  podMetricsEndpoints:
  - port: metrics
    interval: 30s
```

---

## Was ist Loki?

### Definition (IKEA-Style)

**Loki** = **Grep** für Kubernetes Logs 🔍

- Sammelt **Logs** (STDOUT/STDERR von Pods)
- Speichert **komprimiert** (10x weniger als Elasticsearch!)
- Queried mit **LogQL** (wie PromQL für Logs)
- Integration mit **Grafana** (Logs + Metrics zusammen!)

### Loki vs Elasticsearch

**Frage:** Warum haben wir BEIDE (Loki + Elasticsearch)?

**Antwort:**

```
┌─────────────────────────────────────────────────────────────────┐
│ LOKI = Schnelle Suche für Entwickler 🏎️                        │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Schnell (komprimiert)                                        │
│ ✅ Günstig (wenig RAM/Disk)                                     │
│ ✅ Grafana-Integration (Logs + Metrics in einem Dashboard!)    │
│ ❌ Keine Full-Text Search (nur Label-basiert)                  │
│ ❌ Keine komplexen Queries                                     │
│                                                                 │
│ Use Case: "Zeig mir N8N Errors der letzten 5 Minuten"          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ELASTICSEARCH = Deep Search für Compliance/Audit 🕵️            │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Full-Text Search (Google-like)                              │
│ ✅ Komplexe Aggregationen (z.B. "Top 10 Error Messages")       │
│ ✅ Compliance (30-day retention mit ILM)                        │
│ ✅ Kibana UI (professionelle Data Views)                       │
│ ❌ Teuer (viel RAM/Disk)                                       │
│ ❌ Langsamer als Loki                                          │
│                                                                 │
│ Use Case: "Zeig mir alle GDPR-relevanten User-Logins 2024"     │
└─────────────────────────────────────────────────────────────────┘
```

**Fazit:** Beide nutzen! Loki für **schnelles Debugging**, Elasticsearch für **Compliance/Audit**! 🎯

### Core Concepts

#### 1. **Stream** - Log-Kategorie

Stream = Logs mit gleichen Labels

**Beispiel:**
```
Stream: {namespace="n8n-prod", app="n8n", level="error"}
├─ Log 1: "Database connection failed"
├─ Log 2: "API timeout after 30s"
└─ Log 3: "Workflow execution failed"
```

#### 2. **Label** - Filter

Labels = Tags für Streams (wie in Prometheus!)

**Best Practice:** Wenige Labels (Low Cardinality)

```
✅ GOOD (Low Cardinality):
{namespace="n8n-prod", level="error"}
→ Nur wenige Streams (n8n-prod + error = 1 Stream)

❌ BAD (High Cardinality):
{namespace="n8n-prod", user_id="123", request_id="abc", trace_id="xyz"}
→ Millionen Streams (jeder Request = 1 Stream) → OOM! 💥
```

#### 3. **LogQL** - Query Language

LogQL = PromQL für Logs

**Beispiele:**
```logql
# Alle N8N Error Logs
{namespace="n8n-prod", level="error"}

# N8N Logs mit "database" im Text
{namespace="n8n-prod"} |= "database"

# N8N Errors grouped by pod
count_over_time({namespace="n8n-prod", level="error"}[5m]) by (pod)

# Top 5 Error Messages
topk(5, count_over_time({level="error"}[1h]))
```

---

## Was ist Tempo?

### Definition (IKEA-Style)

**Tempo** = **GPS-Tracker** für deine Requests 🛰️

- Tracet **Request-Flows** (von Frontend bis Database)
- Speichert in **S3** (Ceph Object Storage)
- Queried mit **TraceQL** (Filter für Traces)
- Integration mit **Loki & Prometheus** (Trace → Logs → Metrics!)

### Warum Distributed Tracing?

**Problem ohne Tracing:**
```
User meldet: "N8N Workflow ist langsam!" 🐢

Du schaust in:
├─ Grafana Metrics → CPU normal, RAM normal
├─ Loki Logs → "Workflow executed" ... aber wo ist das Problem?
└─ Keine Ahnung wo die Zeit verloren geht! 😰
```

**Lösung mit Tempo:**
```
User meldet: "N8N Workflow ist langsam!" 🐢

Du schaust in Tempo Trace:
├─ Span 1: HTTP Request → N8N API (10ms) ✅
├─ Span 2: Workflow Start → N8N Engine (5ms) ✅
├─ Span 3: Database Query → PostgreSQL (8500ms) ❌ PROBLEM HIER!
└─ Span 4: External API Call → Webhook (50ms) ✅

Problem gefunden: Database Query dauert 8.5 Sekunden! 🎯
```

### The Three Pillars of Observability

```
┌─────────────────────────────────────────────────────────────────┐
│ THE THREE PILLARS (Together = Full Visibility!)                │
└─────────────────────────────────────────────────────────────────┘

📊 METRICS (Prometheus)
├─ Was: CPU 80%, Requests/sec 100, Latency 500ms
├─ Frage: "WAS passiert?"
└─ Beispiel: CPU ist hoch! Aber warum?

📝 LOGS (Loki)
├─ Was: "Database connection timeout after 30s"
├─ Frage: "WELCHER Error?"
└─ Beispiel: Timeout Error! Aber wo im Request?

🔍 TRACES (Tempo)
├─ Was: Request Flow von Frontend → Backend → DB
├─ Frage: "WO ist das Problem?"
└─ Beispiel: DB Query dauert 8.5s! Problem gefunden! 🎉
```

**Zusammen:**
```
1. Metrics sagen: "Request Latency ist hoch!" (500ms avg)
2. Logs sagen: "Database timeout errors!"
3. Traces sagen: "Diese spezifische DB Query braucht 8.5s" → FIX IT!
```

### Core Concepts

#### 1. **Trace** - Ein kompletter Request-Flow

Trace = Die gesamte Reise eines Requests

**Beispiel: N8N Workflow Execution**
```
Trace ID: abc-123-def
├─ Span 1: HTTP POST /workflow/execute (10ms)
├─ Span 2: Load Workflow from DB (100ms)
├─ Span 3: Execute Node 1 (API Call) (200ms)
├─ Span 4: Execute Node 2 (Transform) (5ms)
└─ Span 5: Save Result to DB (50ms)

Total Duration: 365ms
```

#### 2. **Span** - Ein einzelner Schritt

Span = Ein Teil des Requests (z.B. eine Function, ein API Call)

**Span Attributes:**
```yaml
Span ID: span-1
Parent ID: null  # Root span (kein Parent)
Service: n8n-prod
Operation: POST /workflow/execute
Duration: 10ms
Status: OK
Tags:
  - http.method: POST
  - http.status_code: 200
  - workflow.id: workflow-123
```

#### 3. **Service Graph** - Wer spricht mit wem?

Service Graph = Visualisierung der Microservice-Kommunikation

**Beispiel:**
```
┌─────────────────────────────────────────────────────────────────┐
│ SERVICE GRAPH (Auto-Generated from Traces!)                    │
└─────────────────────────────────────────────────────────────────┘

User Browser
    ↓ (100 req/sec)
N8N Frontend
    ↓ (100 req/sec)
N8N Backend
    ├─ → PostgreSQL (80 req/sec, 50ms avg latency)
    └─ → Redis (20 req/sec, 2ms avg latency)
```

#### 4. **Trace-to-Logs Correlation** - Das Killer-Feature!

**Workflow:**
```
Step 1: User sieht Error in N8N
Step 2: Öffnet Grafana → Tempo → Search for N8N traces
Step 3: Findet Trace mit Error (rot markiert!)
Step 4: Klickt auf Trace → "View Logs for this Span"
Step 5: Grafana springt automatisch zu Loki Logs! 🎉
Step 6: Sieht exakten Error-Log für diesen Request!
```

**Wie funktioniert das?**
- Tempo injiziert **Trace ID** in Logs
- Loki speichert Logs mit **Trace ID**
- Grafana verlinkt beide! → Click = Jump to Logs! 🚀

### Tempo vs Jaeger

**Frage:** Warum haben wir BEIDE (Tempo + Jaeger)?

**Antwort:**

```
┌─────────────────────────────────────────────────────────────────┐
│ TEMPO = Storage Backend 📦                                      │
├─────────────────────────────────────────────────────────────────┤
│ ✅ S3 backend (Ceph RGW) = Unlimited storage                   │
│ ✅ 30-day retention                                            │
│ ✅ Multi-protocol (OTLP, Jaeger, Zipkin)                       │
│ ✅ Trace-to-logs correlation                                   │
│ ❌ Basic UI (Grafana Explore)                                  │
│                                                                 │
│ Use Case: "Datenbank für Traces"                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ JAEGER = Frontend UI 🖥️                                        │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Professional Trace UI                                       │
│ ✅ Service Dependency Graph                                    │
│ ✅ Trace Comparison                                            │
│ ✅ Advanced Search                                             │
│ ✅ Uses Tempo as Backend! (grpc-plugin)                        │
│ ❌ Kein eigener Storage                                        │
│                                                                 │
│ Use Case: "Professionelle UI für Trace-Analyse"                │
└─────────────────────────────────────────────────────────────────┘
```

**Fazit:** Tempo = Storage, Jaeger = UI! Beide nutzen! 🎯

**Architecture:**
```
Apps (N8N, etc.)
    ↓ OTLP Traces
Tempo Distributor (Port 4317/4318)
    ↓
Tempo Ingester
    ↓
Ceph S3 (Storage)
    ↑
    ├─ Grafana Explore (Basic UI)
    └─ Jaeger UI (Professional UI)
```

### Welche Apps sollte ich tracen?

#### ✅ **PRODUCTION CRITICAL (100% Sampling):**

**1. N8N Production** (`n8n-prod`)
```yaml
Why:
  - Business-critical workflows
  - Complex multi-step operations
  - External API integrations
  - Database queries

What to trace:
  - Workflow execution time
  - Webhook reception
  - API calls to external services
  - Database queries
  - Node execution duration
```

**2. Kubernetes Infrastructure**
```yaml
What:
  - API Server requests (kube-apiserver)
  - etcd operations
  - kubelet operations

Why:
  - Find control plane bottlenecks
  - Debug slow kubectl commands
  - Monitor API request latency
```

#### 🔄 **OPTIONAL (10% Sampling):**

**1. Audiobookshelf-dev**
```yaml
Why:
  - Development environment (low traffic)
  - Media streaming debugging

Sampling: 10% (every 10th request)
```

**2. N8N Dev**
```yaml
Why:
  - Workflow development
  - Test complex workflows

Sampling: 100% (dev environment, low traffic)
```

#### ❌ **NOT RECOMMENDED:**

```
❌ Grafana - Monitoring the monitoring = too meta
❌ Prometheus - Already has metrics, doesn't need traces
❌ Loki - Log aggregator, no user traffic
❌ Cert-Manager - Async certificate operations
❌ ArgoCD - GitOps sync, not request-based
```

---

## Was ist Thanos?

### Definition (IKEA-Style)

**Thanos** = **Unbegrenzter Speicher** für Prometheus Metrics ♾️

- Speichert Metrics in **S3** (Ceph Object Storage)
- **Unlimited Retention** (für immer!)
- **Deduplication** (Duplikate entfernen)
- **Downsampling** (Alte Metrics komprimieren)
- **Query Frontend** (Schnelle Queries über S3)

### Warum Thanos?

**Problem ohne Thanos:**
```
Prometheus speichert lokal (PVC):
├─ 30 Tage Retention
├─ 100 GB Disk
└─ Nach 30 Tagen: Metrics gelöscht 💥

Frage: "Wie war die CPU Usage vor 3 Monaten?"
Antwort: "Keine Ahnung, Daten weg!" 😰
```

**Lösung mit Thanos:**
```
Prometheus → Thanos Sidecar → Thanos Store → Ceph S3
├─ 30 Tage lokal (schnell)
└─ ∞ Tage in S3 (langsam aber unbegrenzt!)

Frage: "Wie war die CPU Usage vor 3 Monaten?"
Antwort: "Hier, aus S3!" 🎉
```

### Thanos Components

```
┌─────────────────────────────────────────────────────────────────┐
│ THANOS ARCHITECTURE (IKEA-Style)                                │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Prometheus Pod                                                 │
│ ├─ Prometheus (main container)                                │
│ │  └─ TSDB: /data (PVC, 30 days)                              │
│ └─ Thanos Sidecar (sidecar container)                         │
│    └─ Uploads TSDB blocks to S3 every 2 hours                 │
└────────────────────────────────────────────────────────────────┘
                        ↓ Upload
┌────────────────────────────────────────────────────────────────┐
│ Ceph S3 (Object Storage)                                       │
│ └─ Bucket: thanos                                              │
│    ├─ 2025-01/ (January metrics, compressed)                  │
│    ├─ 2025-02/ (February metrics, compressed)                 │
│    └─ 2025-03/ (March metrics, compressed)                    │
└────────────────────────────────────────────────────────────────┘
                        ↑ Read
┌────────────────────────────────────────────────────────────────┐
│ Thanos Query (Deployment)                                      │
│ └─ Queries both:                                               │
│    ├─ Prometheus (last 30 days, fast)                         │
│    └─ S3 (older data, slow but available!)                    │
└────────────────────────────────────────────────────────────────┘
                        ↑ Query
┌────────────────────────────────────────────────────────────────┐
│ Grafana                                                         │
│ └─ Datasource: Thanos Query (not Prometheus!)                 │
│    → Can query data from 3 months ago! 🎉                     │
└────────────────────────────────────────────────────────────────┘
```

### Thanos Benefits

| Feature | Without Thanos | With Thanos |
|---------|----------------|-------------|
| **Retention** | 30 days | ∞ (Unlimited) |
| **Storage** | 100 GB (PVC) | Unlimited (S3) |
| **Cost** | Expensive (SSD) | Cheap (Object Storage) |
| **Query Speed** | Fast | Fast (30d) + Slow (older) |
| **HA** | ❌ Single Prometheus | ✅ Multiple Prometheus (deduplicated) |
| **Backup** | Manual | Auto (S3 versioning) |

---

## Unser Production Setup

### Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ KUBERNETES CLUSTER (Talos 1.10.6)                              │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ ctrl-0           │  │ worker-1         │  │ worker-2         │
│ (Control Plane)  │  │ (Worker)         │  │ (Worker)         │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ Prometheus       │  │ App Pods         │  │ App Pods         │
│ Grafana          │  │ Promtail         │  │ Promtail         │
│ Loki             │  │ Node Exporter    │  │ Node Exporter    │
│ Alertmanager     │  │                  │  │                  │
│ Thanos Query     │  │                  │  │                  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

### Deployed Components

**Namespace: `monitoring`**

```yaml
Prometheus (StatefulSet):
  - Replicas: 1
  - Storage: 100 GB (Ceph RBD)
  - Retention: 30 days
  - Scrape Interval: 15s

Grafana (Deployment):
  - Replicas: 1
  - Dashboards: 68 (as CRDs)
  - Datasources: 4 (Prometheus, Loki, Alertmanager, Jaeger)

Loki (StatefulSet):
  - Replicas: 1
  - Storage: 50 GB (Ceph RBD)
  - Retention: 7 days

Tempo (Distributed Architecture):
  - Distributor (Deployment): Replicas 1, receives traces (OTLP/Jaeger)
  - Ingester (StatefulSet): Replicas 1, buffers spans, 10 GB storage
  - Compactor (Deployment): Replicas 1, uploads to S3
  - Querier (Deployment): Replicas 1, queries Ingester + S3
  - Query Frontend (Deployment): Replicas 1, caching + optimization
  - Metrics Generator: Generates span metrics for Prometheus
  - S3 Backend: Ceph RGW (tempo-traces bucket)
  - Retention: 30 days
  - Protocols: OTLP gRPC (4317), OTLP HTTP (4318), Jaeger gRPC (14250)

Jaeger (Deployment):
  - Replicas: 1
  - Backend: Tempo (via grpc-plugin)
  - UI: http://jaeger:16686
  - Use Case: Professional trace visualization

Alertmanager (StatefulSet):
  - Replicas: 1
  - Routes: Tier 0-5

Thanos Sidecar (in Prometheus Pod):
  - S3 Bucket: thanos
  - Upload Interval: 2h

Thanos Query (Deployment):
  - Replicas: 1
  - Queries: Prometheus + S3

Node Exporter (DaemonSet):
  - Pods: 6 (one per node)
  - Metrics: System (CPU, RAM, Disk)

Kube State Metrics (Deployment):
  - Replicas: 1
  - Metrics: Kubernetes Objects

Promtail (DaemonSet):
  - Pods: 6 (one per node)
  - Logs: All pod logs → Loki
```

### Resource Allocation

```
┌─────────────────────────────────────────────────────────────────┐
│ RESOURCE USAGE (Monitoring Stack)                              │
└─────────────────────────────────────────────────────────────────┘

Prometheus:
  Requests: 2 CPU, 4Gi RAM
  Limits:   4 CPU, 8Gi RAM
  Disk:     100 GB (PVC)

Grafana:
  Requests: 500m CPU, 1Gi RAM
  Limits:   1 CPU, 2Gi RAM

Loki:
  Requests: 1 CPU, 2Gi RAM
  Limits:   2 CPU, 4Gi RAM
  Disk:     50 GB (PVC)

Node Exporter (per node):
  Requests: 100m CPU, 100Mi RAM
  Limits:   200m CPU, 200Mi RAM

Promtail (per node):
  Requests: 100m CPU, 128Mi RAM
  Limits:   200m CPU, 256Mi RAM

TOTAL CLUSTER:
  CPU:    ~10 cores
  Memory: ~20 GB
  Disk:   150 GB (Prometheus + Loki)
```

---

## Complete Architecture

### Full Stack Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ COMPLETE OBSERVABILITY ARCHITECTURE (IKEA-Style)                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: APPLICATIONS                                                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│    N8N      │  │   Kafka     │  │ PostgreSQL  │  │   Redis     │
│    Pods     │  │   Brokers   │  │  Clusters   │  │   Caches    │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │                │
       │ /metrics       │ /metrics       │ /metrics       │ /metrics
       │ STDOUT/STDERR  │ STDOUT/STDERR  │ STDOUT/STDERR  │ STDOUT/STDERR
       │                │                │                │
       ▼                ▼                ▼                ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: COLLECTION                                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│ Prometheus (ServiceMonitor)      │  │ Promtail (DaemonSet)             │
│ - Scrapes /metrics every 15s     │  │ - Reads /var/log/pods/*.log      │
│ - Stores in TSDB (30 days)       │  │ - Parses JSON logs               │
│ - ServiceMonitor auto-discovery  │  │ - Adds Kubernetes labels         │
└────────────┬─────────────────────┘  └────────────┬─────────────────────┘
             │                                     │
             │ TSDB Blocks (2h)                    │ gRPC Push
             ▼                                     ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: STORAGE                                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│ Thanos Sidecar                   │  │ Loki (StatefulSet)               │
│ - Uploads blocks to S3 (2h)      │  │ - Stores logs (7 days)           │
│ - Bucket: thanos                 │  │ - Chunks on disk (PVC 50GB)      │
│ - Ceph Object Storage            │  │ - Label-based indexing           │
└────────────┬─────────────────────┘  └────────────┬─────────────────────┘
             │                                     │
             │ S3 Upload                           │ LogQL Query
             ▼                                     ▼

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│ Ceph S3 (Object Storage)         │  │ Grafana (Deployment)             │
│ └─ thanos/                       │  │ - Datasource: Thanos Query       │
│    ├─ 2025-01/ (Jan metrics)     │  │ - Datasource: Loki               │
│    ├─ 2025-02/ (Feb metrics)     │  │ - 68 Dashboards (CRDs)           │
│    └─ 2025-03/ (Mar metrics)     │  │ - Unlimited retention via S3!    │
└──────────────────────────────────┘  └──────────────────────────────────┘
             ▲
             │ Read from S3
             │
┌──────────────────────────────────┐
│ Thanos Query (Deployment)        │
│ - Queries Prometheus (30d)       │
│ - Queries S3 (older data)        │
│ - Deduplicates metrics           │
│ - Downsamples old data           │
└──────────────────────────────────┘
             ▲
             │ PromQL Query
             │
┌──────────────────────────────────┐
│ Grafana Dashboard                │
│ - Panel: CPU Usage (last 90d)   │
│ - Data: 30d from Prometheus      │
│         60d from S3 (Thanos)     │
└──────────────────────────────────┘
```

### Data Flow Sequence

**METRICS FLOW (Prometheus → Thanos → Grafana):**

```
Step 1: App exposes /metrics
  ├─ App: N8N Pod
  ├─ Endpoint: http://n8n-prod:5678/metrics
  └─ Format: Prometheus text format

Step 2: ServiceMonitor tells Prometheus to scrape
  ├─ ServiceMonitor: servicemonitor-n8n.yaml
  ├─ Selector: app=n8n
  └─ Prometheus auto-discovers all N8N pods

Step 3: Prometheus scrapes every 15 seconds
  ├─ Prometheus → http://n8n-prod:5678/metrics
  ├─ Stores in TSDB (local PVC)
  └─ Retention: 30 days

Step 4: Thanos Sidecar uploads to S3
  ├─ Every 2 hours
  ├─ TSDB blocks → Ceph S3 bucket "thanos"
  └─ Infinite retention!

Step 5: User opens Grafana Dashboard
  ├─ Dashboard: "N8N Production Metrics"
  ├─ Query: rate(http_requests_total[5m])
  └─ Datasource: Thanos Query (not Prometheus!)

Step 6: Thanos Query fetches data
  ├─ Last 30 days: From Prometheus (fast)
  ├─ Older data: From S3 (slow but works!)
  └─ Returns combined result to Grafana

Step 7: Grafana renders chart
  └─ User sees data from last 90 days! 🎉
```

**LOGS FLOW (Promtail → Loki → Grafana):**

```
Step 1: App writes logs to STDOUT
  ├─ App: N8N Pod
  └─ Log: "Workflow execution started"

Step 2: Kubernetes captures logs
  ├─ Container Runtime: containerd
  └─ File: /var/log/pods/n8n-prod_n8n-0_abc123/n8n/0.log

Step 3: Promtail tails log file
  ├─ Promtail (DaemonSet) on worker node
  ├─ Reads: /var/log/pods/**/*.log
  └─ Parses JSON format

Step 4: Promtail adds labels
  ├─ namespace: n8n-prod
  ├─ pod: n8n-0
  ├─ container: n8n
  └─ app: n8n

Step 5: Promtail pushes to Loki
  ├─ Protocol: gRPC
  ├─ Endpoint: http://loki:3100/loki/api/v1/push
  └─ Batch: Every 10 seconds

Step 6: Loki stores logs
  ├─ Index: Labels (namespace, pod, app)
  ├─ Chunks: Log content (compressed)
  └─ Retention: 7 days

Step 7: User opens Grafana Explore
  ├─ Datasource: Loki
  ├─ Query: {namespace="n8n-prod"} |= "error"
  └─ Grafana shows logs! 🎉
```

---

## Tempo Trace Pipeline

### 🔍 Wie funktioniert Distributed Tracing?

**IKEA-Analogie:**

```
┌────────────────────────────────────────────────────────────────┐
│ Metrics (Prometheus) = Geschwindigkeitsmesser 🏎️              │
│ → Sagt dir: "Du fährst 80 km/h"                               │
│ → Aber NICHT: Wo genau bist du auf der Strecke?               │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ Traces (Tempo) = GPS-Navigation 🛰️                            │
│ → Sagt dir: "Du bist bei Kilometer 42"                        │
│ → UND: "Stau auf der Strecke zwischen KM 50-55!"              │
│ → GPS für jeden einzelnen Request! 🎯                          │
└────────────────────────────────────────────────────────────────┘
```

### Complete Trace Flow (OTLP → Tempo → Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│ TRACES FLOW (App → Tempo → Grafana/Jaeger)                     │
└─────────────────────────────────────────────────────────────────┘

Step 1: App instruments code with OTLP SDK
  ├─ App: N8N Production
  ├─ Library: @opentelemetry/sdk-node
  └─ Code: SDK auto-instruments HTTP, Database, Redis calls

Step 2: App sends traces to Tempo Distributor
  ├─ Protocol: OTLP gRPC (port 4317)
  ├─ Endpoint: http://tempo-distributor.monitoring.svc:4317
  ├─ Format: Protobuf (binary, efficient)
  └─ Batch: Every 5 seconds (configurable)

Step 3: Tempo Distributor validates and forwards
  ├─ Distributor receives trace
  ├─ Validates trace format
  ├─ Adds metadata (cluster, namespace)
  └─ Forwards to Tempo Ingester

Step 4: Tempo Ingester buffers traces
  ├─ Ingester receives spans
  ├─ Buffers in memory (10-15 minutes)
  ├─ Groups spans into blocks
  └─ Writes blocks to local disk (PVC)

Step 5: Tempo Compactor uploads to S3
  ├─ Every 2 hours: Compactor reads blocks from Ingester
  ├─ Compresses blocks (parquet format)
  ├─ Uploads to Ceph S3: s3://tempo-traces/blocks/
  └─ Retention: 30 days (same as Loki)

Step 6: Metrics Generator creates metrics FROM traces
  ├─ Reads spans from Ingester
  ├─ Generates metrics:
  │  ├─ request_duration_seconds{service="n8n-prod"}
  │  ├─ span_duration_seconds{span="database-query"}
  │  └─ service_graph_request_total{client="n8n",server="postgres"}
  └─ Remote-writes to Prometheus!

Step 7: User searches traces in Grafana
  ├─ Grafana → Explore → Tempo Datasource
  ├─ Query: {service.name="n8n-prod" && duration>1s}
  └─ Tempo Query Frontend searches:
     ├─ Recent data (last 15 min): From Ingester (fast!)
     └─ Older data: From S3 (slower, but works!)

Step 8: Grafana renders trace
  ├─ Shows Trace ID, Duration, Spans
  ├─ Waterfall view of spans (Timeline)
  ├─ Click "Logs for this span" → Jumps to Loki! 🎉
  └─ Click "Metrics for this service" → Jumps to Prometheus! 🚀
```

### Tempo Architecture (Distributed Components)

```
┌─────────────────────────────────────────────────────────────────┐
│ TEMPO DISTRIBUTED ARCHITECTURE (Production)                     │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐
│ Apps (N8N, etc.)                 │
│ - OTLP SDK instrumented          │
└────────────┬─────────────────────┘
             │ OTLP gRPC (4317)
             │ OTLP HTTP (4318)
             │ Jaeger gRPC (14250)
             ▼
┌──────────────────────────────────┐
│ Tempo Distributor (Deployment)   │
│ - Validates traces               │
│ - Load balancing                 │
│ - Forwards to Ingesters          │
└────────────┬─────────────────────┘
             │ gRPC
             ▼
┌──────────────────────────────────┐
│ Tempo Ingester (StatefulSet)     │
│ - Buffers spans (10-15 min)     │
│ - Writes blocks to PVC           │
│ - Replication factor: 1          │
│ - Storage: 10 GB (rook-ceph-rbd) │
└─────┬──────────────┬─────────────┘
      │              │
      │              └──────────────────────────────┐
      │ Blocks                                      │ Spans (live)
      ▼                                             ▼
┌──────────────────────────────────┐  ┌───────────────────────────┐
│ Tempo Compactor (Deployment)     │  │ Metrics Generator         │
│ - Reads blocks from Ingester     │  │ - Generates span metrics  │
│ - Compresses to Parquet          │  │ - Service graphs          │
│ - Uploads to S3 (every 2h)       │  │ - Remote-write to Prom    │
│ - Deletes old data (30d)         │  └───────────┬───────────────┘
└────────────┬─────────────────────┘              │
             │ S3 Upload                          │ Remote Write
             ▼                                     ▼
┌──────────────────────────────────┐  ┌───────────────────────────┐
│ Ceph S3 (Object Storage)         │  │ Prometheus                │
│ Bucket: tempo-traces             │  │ - Span duration metrics   │
│ Format: Parquet (columnar)       │  │ - Service graph metrics   │
│ Retention: 30 days               │  │ - Queryable via PromQL!   │
└────────────▲─────────────────────┘  └───────────────────────────┘
             │ Read
             │
┌──────────────────────────────────┐
│ Tempo Querier (Deployment)       │
│ - Queries Ingester (recent)      │
│ - Queries S3 (historical)        │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│ Tempo Query Frontend (Deploy)    │
│ - Caches queries                 │
│ - Optimizes searches             │
│ - API: http://tempo:3200         │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│ Grafana Explore                  │
│ - Tempo Datasource               │
│ - TraceQL queries                │
│ - Trace-to-logs correlation      │
└──────────────────────────────────┘
```

### Tempo vs Prometheus Data Flow (Vergleich)

```
┌─────────────────────────────────────────────────────────────────┐
│ PROMETHEUS (Metrics) - PULL-based                               │
└─────────────────────────────────────────────────────────────────┘

Prometheus ─── scrapes every 15s ──→ App /metrics endpoint
    ↓
Stores in TSDB (local PVC)
    ↓
Thanos uploads to S3 (every 2h)
    ↓
Grafana queries via PromQL

Advantage: Simple (no client libraries needed)
Disadvantage: High-cardinality data = OOM! 💥


┌─────────────────────────────────────────────────────────────────┐
│ TEMPO (Traces) - PUSH-based                                     │
└─────────────────────────────────────────────────────────────────┘

App (OTLP SDK) ─── pushes ──→ Tempo Distributor (4317)
    ↓
Tempo Ingester buffers (10-15 min)
    ↓
Compactor uploads to S3 (every 2h)
    ↓
Grafana queries via TraceQL

Advantage: High-cardinality OK (millions of trace IDs!)
Disadvantage: Requires OTLP SDK in app
```

### How to Instrument N8N for Tracing

#### Step 1: Add OpenTelemetry to N8N (Custom Image)

**Dockerfile:**
```dockerfile
FROM n8nio/n8n:latest

# Install OpenTelemetry SDK
USER root
RUN npm install -g \
    @opentelemetry/sdk-node@^0.52.0 \
    @opentelemetry/auto-instrumentations-node@^0.47.0 \
    @opentelemetry/exporter-trace-otlp-grpc@^0.52.0

# Tracing config
COPY tracing.js /app/tracing.js

USER node
ENV NODE_OPTIONS="--require /app/tracing.js"
```

**tracing.js:**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  serviceName: 'n8n-prod',
  traceExporter: new OTLPTraceExporter({
    url: 'http://tempo-distributor.monitoring.svc:4317',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('🔍 OpenTelemetry Tracing started for n8n-prod');
```

#### Step 2: Update N8N Deployment

```yaml
# kubernetes/applications/n8n/prod/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: n8n-prod
spec:
  template:
    spec:
      containers:
      - name: n8n
        image: your-registry/n8n:tracing  # Custom image!
        env:
        # OTLP Environment Variables
        - name: OTEL_SERVICE_NAME
          value: "n8n-prod"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://tempo-distributor.monitoring.svc:4317"
        - name: OTEL_TRACES_SAMPLER
          value: "parentbased_traceidratio"
        - name: OTEL_TRACES_SAMPLER_ARG
          value: "1.0"  # 100% sampling (production critical!)

        # Existing N8N env vars
        - name: N8N_HOST
          value: "n8n.homelab.local"
        # ... other vars
```

#### Step 3: Deploy and Verify

```bash
# Build custom N8N image with OTLP
docker build -t your-registry/n8n:tracing .
docker push your-registry/n8n:tracing

# Deploy updated N8N
kubectl apply -f kubernetes/applications/n8n/prod/

# Wait for N8N to be ready
kubectl rollout status deployment/n8n -n n8n-prod

# Check if traces are being sent (look for OTLP logs)
kubectl logs -n n8n-prod deployment/n8n | grep -i "telemetry\|tracing"

# Verify in Tempo
kubectl exec -n grafana deployment/grafana-deployment -- \
  curl -s "http://tempo-query-frontend.monitoring.svc:3200/api/search?tags=service.name%3Dn8n-prod&limit=10"
```

**Expected Output:** JSON with Trace IDs! 🎉

#### Step 4: Query Traces in Grafana

```
1. Open Grafana: http://grafana.homelab.local:3000

2. Go to Explore → Select "Tempo" datasource

3. Query Types:

   A. Search by Service:
      {service.name="n8n-prod"}

   B. Find slow traces (> 1 second):
      {service.name="n8n-prod" && duration>1s}

   C. Find error traces:
      {service.name="n8n-prod" && status=error}

   D. Find specific workflow:
      {service.name="n8n-prod" && workflow.id="workflow-123"}

4. Click on a trace → Waterfall view shows:
   ├─ All spans (HTTP, DB, Redis, etc.)
   ├─ Duration of each span
   └─ Click "Logs for this span" → Jumps to Loki! 🚀
```

### Sampling Strategies (Production Best Practices)

#### Strategy 1: 100% Sampling (Production Critical Apps)

**Use for:** N8N Production, Payment APIs, Critical Workflows

```yaml
env:
- name: OTEL_TRACES_SAMPLER
  value: "parentbased_traceidratio"
- name: OTEL_TRACES_SAMPLER_ARG
  value: "1.0"  # 100% = Every request is traced
```

**Why:**
- Business-critical → Need to see EVERY request
- Low traffic (< 1000 req/sec) → Storage OK
- Compliance/Audit → Need complete traces

#### Strategy 2: 10% Sampling (High-Traffic Apps)

**Use for:** Audiobookshelf-dev, High-traffic APIs

```yaml
env:
- name: OTEL_TRACES_SAMPLER
  value: "parentbased_traceidratio"
- name: OTEL_TRACES_SAMPLER_ARG
  value: "0.1"  # 10% = Every 10th request
```

**Why:**
- High traffic → 100% = Too much data
- Representative sample sufficient
- Saves storage costs

#### Strategy 3: Tail-based Sampling (Advanced)

**Only trace ERRORS or SLOW requests:**

```yaml
# tempo/values.yaml
tempo:
  overrides:
    defaults:
      metrics_generator:
        processors:
          - service-graphs
          - span-metrics
        filter_policies:
          - name: error-and-slow-traces
            spans_per_second: 100
            policies:
              - name: error-traces
                type: string_attribute
                key: error
                value: "true"
              - name: slow-traces
                type: numeric_attribute
                key: duration_ms
                min_value: 1000  # > 1 second
```

**Why:**
- Best of both worlds: Full coverage for problems
- Low storage: Only errors + slow traces saved
- Production-ready: Used by Uber, Netflix

---

## ServiceMonitor → Dashboard (No Data Fix!)

### 🎯 Das wichtigste Kapitel!

**Problem:** Du hast ein Dashboard, aber es zeigt **"No Data"** 😱

**Lösung:** Schritt-für-Schritt Fix! (IKEA-Style)

### IKEA-Anleitung: Von Service zu Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 1: Service muss /metrics Endpoint haben                │
└─────────────────────────────────────────────────────────────────┘

Deine App muss Metrics exposen!

Beispiel: N8N
├─ URL: http://n8n-prod:5678/metrics
└─ Test: curl http://n8n-prod:5678/metrics

Output:
  # HELP http_requests_total Total HTTP requests
  # TYPE http_requests_total counter
  http_requests_total{method="GET",status="200"} 1000

✅ Wenn du Metrics siehst → Weiter zu Schritt 2
❌ Wenn "404 Not Found" → Deine App muss erst Metrics exposen!
```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 2: Service muss Port mit Name "metrics" haben          │
└─────────────────────────────────────────────────────────────────┘

Dein Kubernetes Service braucht einen Port mit Name "metrics"!

❌ FALSCH (kein Port-Name):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-prod
spec:
  selector:
    app: n8n
  ports:
  - port: 5678        # ❌ Kein Name!
    targetPort: 5678
```

✅ RICHTIG (mit Port-Name):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-prod
  labels:             # ✅ Labels für ServiceMonitor!
    app: n8n
spec:
  selector:
    app: n8n
  ports:
  - name: http        # ✅ Name!
    port: 5678
    targetPort: 5678
```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 3: ServiceMonitor erstellen                            │
└─────────────────────────────────────────────────────────────────┘

Jetzt sagst du Prometheus: "Scrape alle Services mit Label app=n8n"

Datei: servicemonitor-n8n.yaml
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: n8n-prod
  namespace: monitoring        # ✅ ServiceMonitor IMMER in "monitoring"!
  labels:
    app: n8n
spec:
  # WELCHE Namespaces?
  namespaceSelector:
    matchNames:
    - n8n-prod                 # ✅ Nur n8n-prod namespace

  # WELCHE Services (via Labels)?
  selector:
    matchLabels:
      app: n8n                 # ✅ Service muss Label "app: n8n" haben!

  # WO ist /metrics?
  endpoints:
  - port: http                 # ✅ Port name aus Service!
    path: /metrics             # ✅ URL path (Standard: /metrics)
    interval: 30s              # ✅ Scrape alle 30 Sekunden
```

Apply it:
```bash
kubectl apply -f servicemonitor-n8n.yaml
```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 4: Check ob Prometheus target findet                   │
└─────────────────────────────────────────────────────────────────┘

Gehe zu Prometheus UI:
  kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
  http://localhost:9090/targets

Suche nach "n8n":
  ✅ State: UP → Prometheus scraped erfolgreich!
  ❌ State: DOWN → Siehe "Troubleshooting" unten

```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 5: Check ob Metrics in Prometheus sind                 │
└─────────────────────────────────────────────────────────────────┘

Gehe zu Prometheus → Graph Tab

Query:
  http_requests_total{namespace="n8n-prod"}

Result:
  ✅ Metrics shown → Prometheus hat Daten!
  ❌ "No data" → ServiceMonitor stimmt nicht

```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 6: Dashboard mit richtiger Query                       │
└─────────────────────────────────────────────────────────────────┘

Jetzt erstelle Dashboard Panel mit korrekter PromQL Query

❌ FALSCH (kein Namespace Filter):
```promql
rate(http_requests_total[5m])
# → Zeigt ALLE Apps (N8N + Kafka + Redis + ...)
```

✅ RICHTIG (mit Namespace Filter):
```promql
rate(http_requests_total{namespace="n8n-prod"}[5m])
# → Zeigt nur N8N!
```

Panel Config in Grafana Dashboard:
```yaml
panels:
- title: "N8N Request Rate"
  targets:
  - expr: 'rate(http_requests_total{namespace="n8n-prod"}[5m])'
    datasource: Prometheus
```

```
┌─────────────────────────────────────────────────────────────────┐
│ SCHRITT 7: Refresh Grafana Dashboard                           │
└─────────────────────────────────────────────────────────────────┘

Open Dashboard → Refresh → Data appears! 🎉

```

### Häufige "No Data" Probleme

#### Problem 1: ServiceMonitor im falschen Namespace

❌ **FALSCH:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: n8n-prod
  namespace: n8n-prod  # ❌ FALSCH! ServiceMonitor sollte in "monitoring" sein!
```

✅ **RICHTIG:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: n8n-prod
  namespace: monitoring  # ✅ RICHTIG!
spec:
  namespaceSelector:
    matchNames:
    - n8n-prod  # ← Hier sagst du welche Namespaces gescraped werden
```

#### Problem 2: Falsche Labels

Service hat:
```yaml
labels:
  app.kubernetes.io/name: n8n  # ← Dieses Label
```

ServiceMonitor sucht:
```yaml
selector:
  matchLabels:
    app: n8n  # ← Aber sucht nach diesem Label! ❌ MISMATCH!
```

**Fix:**
```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: n8n  # ✅ Muss übereinstimmen!
```

#### Problem 3: Port Name stimmt nicht

Service:
```yaml
ports:
- name: web  # ← Port heißt "web"
  port: 5678
```

ServiceMonitor:
```yaml
endpoints:
- port: metrics  # ← Aber sucht nach "metrics"! ❌ MISMATCH!
```

**Fix:**
```yaml
endpoints:
- port: web  # ✅ Muss übereinstimmen!
  path: /metrics
```

#### Problem 4: Falsche PromQL Query

```promql
# ❌ FALSCH: Sucht nach Metric die es nicht gibt
my_custom_metric_that_doesnt_exist

# ✅ RICHTIG: Check erst ob Metric existiert
# Gehe zu Prometheus → Graph → Type "n8n" → Auto-complete zeigt verfügbare Metrics
```

### ServiceMonitor Troubleshooting Checklist

**IKEA-Checklist** (Von oben nach unten abarbeiten):

```
☐ Step 1: App exposes /metrics?
  → Test: curl http://service:port/metrics

☐ Step 2: Service has port name?
  → kubectl get svc n8n-prod -o yaml | grep "name:"

☐ Step 3: Service has correct labels?
  → kubectl get svc n8n-prod -o yaml | grep "labels:" -A 5

☐ Step 4: ServiceMonitor in "monitoring" namespace?
  → kubectl get servicemonitor -n monitoring

☐ Step 5: ServiceMonitor labels match Service labels?
  → Compare spec.selector.matchLabels

☐ Step 6: Prometheus Target UP?
  → http://localhost:9090/targets

☐ Step 7: Metrics in Prometheus?
  → Query: {namespace="n8n-prod"}

☐ Step 8: Dashboard PromQL correct?
  → Test query in Prometheus first
```

---

## Grafana Dashboards Deep Dive

### GrafanaDashboard CRD Structure

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: n8n-production-metrics
  namespace: grafana
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/component: dashboard
spec:
  # WICHTIG: allowCrossNamespaceImport = true
  # → Dashboard kann von Grafana in anderem Namespace geladen werden
  allowCrossNamespaceImport: true

  # Folder in Grafana UI
  folder: "Applications"

  # Grafana Instance Selector
  instanceSelector:
    matchLabels:
      app: grafana

  # Dashboard JSON (compressed)
  json: |
    {"title":"N8N Production","panels":[...]}
```

### Dashboard Organization Strategy

**Unsere 68 Dashboards:**

```
Grafana UI
├─ Tier 0 Executive (2 dashboards)
│  ├─ Kubernetes Global View
│  └─ Node System Overview
│
├─ ArgoCD (5 dashboards)
│  ├─ ArgoCD GitOps
│  ├─ ArgoCD Operational
│  ├─ ArgoCD Application
│  ├─ ArgoCD Notifications
│  └─ ArgoCD Overview v3
│
├─ Ceph Storage (4 dashboards)
│  ├─ Rook Ceph Storage
│  ├─ Ceph Cluster
│  ├─ Ceph Pools
│  └─ Ceph OSD
│
├─ Kubernetes (11 dashboards)
│  ├─ API Server
│  ├─ CoreDNS
│  ├─ Scheduler
│  ├─ Controller Manager
│  ├─ etcd
│  ├─ Global View
│  ├─ Namespaces View
│  ├─ Nodes View
│  ├─ Pods View
│  ├─ Persistent Volumes
│  └─ State Metrics v2
│
└─ ... (53 more dashboards)
```

### Dashboard Import vs CRD

**Warum CRD besser ist:**

| Feature | Dashboard Import (UI) | GrafanaDashboard CRD |
|---------|----------------------|---------------------|
| **Method** | Click "Import" in UI | `kubectl apply -f` |
| **Storage** | Grafana Database | Git Repository |
| **Versioning** | ❌ Nur in Grafana DB | ✅ Git History |
| **Backup** | Manual DB Export | Git Commit |
| **Restore** | Manual Re-Import | `kubectl apply -f` |
| **GitOps** | ❌ Nein | ✅ ArgoCD Auto-Sync |
| **Validation** | ❌ Nein | ✅ Kubernetes API |
| **Team Sharing** | Export JSON, Email | Git Push |
| **CI/CD** | ❌ Schwer | ✅ Easy |

**Winner:** GrafanaDashboard CRD 🏆

---

## Backup & Disaster Recovery

### 🎯 Velero Backup - Backup ALLES!

**Was kann Velero backupen?**

```
┌─────────────────────────────────────────────────────────────────┐
│ VELERO KANN BACKUPEN:                                           │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Grafana Dashboards (als GrafanaDashboard CRDs!)             │
│ ✅ Prometheus TSDB (PersistentVolumeClaim + Data)              │
│ ✅ Loki Chunks (PersistentVolumeClaim + Data)                  │
│ ✅ ServiceMonitors (alle ServiceMonitor CRDs)                  │
│ ✅ PrometheusRules (alle Alert Rules)                          │
│ ✅ ConfigMaps (Grafana Datasources, Alertmanager Config)       │
│ ✅ Secrets (Grafana Admin Password, etc.)                      │
│ ✅ Thanos Config (S3 credentials)                              │
│ ✅ ALLES in Kubernetes! 🚀                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Backup Strategy

#### Daily Backup (Automatisch via Velero Schedule)

```yaml
# velero-schedule-monitoring-daily.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: monitoring-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Jeden Tag um 2:00 AM
  template:
    includedNamespaces:
    - monitoring
    - grafana
    includeClusterResources: true
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h  # Keep for 30 days
```

**Apply:**
```bash
kubectl apply -f velero-schedule-monitoring-daily.yaml
```

**Was wird gebackuped:**
- Prometheus PVC (100 GB TSDB data)
- Loki PVC (50 GB logs)
- Alle Grafana Dashboards (68 CRDs)
- Alle ServiceMonitors
- Alle PrometheusRules
- ConfigMaps & Secrets

#### Manual Backup (On-Demand)

```bash
# Backup kompletter Monitoring Stack
velero backup create monitoring-stack-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces monitoring,grafana \
  --include-cluster-resources \
  --storage-location default

# Backup nur Grafana Dashboards (schnell!)
velero backup create grafana-dashboards-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces grafana \
  --include-resources grafanadashboards

# Backup nur ServiceMonitors + Rules
velero backup create prometheus-configs-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces monitoring \
  --include-resources servicemonitors,prometheusrules
```

### Restore Procedure

#### Disaster Recovery (Kompletter Cluster Restore)

**Scenario:** Dein Cluster ist komplett weg! 💥

**IKEA-Style Recovery:**

```
SCHRITT 1: Neuer Kubernetes Cluster
  ├─ Fresh Talos install
  └─ kubectl get nodes → All Ready

SCHRITT 2: Velero installieren
  helm install velero vmware-tanzu/velero \
    --namespace velero \
    --set configuration.backupStorageLocation.bucket=velero \
    --set configuration.backupStorageLocation.config.s3Url=http://rook-ceph-rgw.rook-ceph.svc

SCHRITT 3: Check Backups
  velero backup get
  # Output: monitoring-daily-20250120-020000

SCHRITT 4: Restore Monitoring Stack
  velero restore create --from-backup monitoring-daily-20250120-020000

SCHRITT 5: Wait for Restore
  kubectl get pods -n monitoring --watch
  # Warte bis alle Pods Running

SCHRITT 6: Check Grafana
  kubectl port-forward -n grafana svc/grafana 3000:3000
  http://localhost:3000
  # → Alle 68 Dashboards sind wieder da! 🎉

SCHRITT 7: Check Prometheus
  http://localhost:9090
  # → Alle Metrics sind wieder da!
  # → Historical data from PVC restored!
```

#### Partial Restore (Nur Dashboards)

**Scenario:** Du hast versehentlich ein Dashboard gelöscht

```bash
# Restore nur Grafana Dashboards
velero restore create grafana-dashboards-restore \
  --from-backup grafana-dashboards-20250120-020000 \
  --include-namespaces grafana \
  --include-resources grafanadashboards

# Check restore
kubectl get grafanadashboards -n grafana
```

### Git Backup (Zusätzlich!)

**Best Practice:** Doppelte Absicherung!

```
┌────────────────────────────────────────────────────────────────┐
│ BACKUP STRATEGY (2-fach)                                       │
├────────────────────────────────────────────────────────────────┤
│ 1. Velero Backup (automatisch)                                │
│    └─ Speichert PVCs + CRDs in Ceph S3                        │
│                                                                │
│ 2. Git Backup (automatisch via ArgoCD)                        │
│    └─ Alle YAMLs in Git Repository                            │
│                                                                │
│ Vorteil: Wenn Velero kaputt ist → Git restore!                │
│          Wenn Git kaputt ist → Velero restore!                │
└────────────────────────────────────────────────────────────────┘
```

**Git Backup Struktur:**
```
kubernetes/infrastructure/monitoring/
├─ grafana/
│  ├─ kustomization.yaml
│  ├─ grafana.yaml
│  └─ enterprise-dashboards/
│     ├─ argocd/
│     │  ├─ argocd-gitops.yaml
│     │  └─ ... (68 dashboards)
│     └─ ...
│
├─ servicemonitors/
│  ├─ servicemonitor-n8n.yaml
│  ├─ servicemonitor-kafka.yaml
│  └─ ... (alle ServiceMonitors)
│
└─ alertmanager/
   ├─ alertmanagerconfig-tier0.yaml
   └─ ... (alle Alert Configs)
```

**Restore from Git:**
```bash
# Clone repo
git clone https://github.com/Tim275/talos-homelab.git

# Apply all monitoring YAMLs
kubectl apply -k kubernetes/infrastructure/monitoring/

# Fertig! Alles wieder da! 🎉
```

---

## Quick Reference

### Essential Commands

```bash
# ══════════════════════════════════════════════════════════════
# PROMETHEUS
# ══════════════════════════════════════════════════════════════

# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# → http://localhost:9090

# Check Prometheus Targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'

# Check ServiceMonitors
kubectl get servicemonitors -A

# Check PrometheusRules
kubectl get prometheusrules -A

# ══════════════════════════════════════════════════════════════
# GRAFANA
# ══════════════════════════════════════════════════════════════

# Port-forward to Grafana UI
kubectl port-forward -n grafana svc/grafana 3000:3000
# → http://localhost:3000

# List all Grafana Dashboards
kubectl get grafanadashboards -n grafana

# Get Grafana admin password
kubectl get secret -n grafana grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

# ══════════════════════════════════════════════════════════════
# LOKI
# ══════════════════════════════════════════════════════════════

# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Query Loki logs (via HTTP)
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="n8n-prod"}' | jq .

# Check Loki health
curl http://localhost:3100/ready

# ══════════════════════════════════════════════════════════════
# TEMPO (DISTRIBUTED TRACING)
# ══════════════════════════════════════════════════════════════

# Port-forward to Tempo Query Frontend
kubectl port-forward -n monitoring svc/tempo-query-frontend 3200:3200
# → http://localhost:3200

# Check Tempo health
curl http://localhost:3200/ready

# Search traces by service name (via HTTP API)
curl -s "http://localhost:3200/api/search?tags=service.name%3Dn8n-prod&limit=10" | jq .

# Get specific trace by ID
curl -s "http://localhost:3200/api/traces/<trace-id>" | jq .

# Check Tempo metrics (span metrics generated by Metrics Generator)
curl http://localhost:3200/metrics | grep tempo_

# Check all Tempo pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Check Tempo Distributor (receives traces)
kubectl logs -n monitoring deployment/tempo-distributor --tail=50

# Check Tempo Ingester (buffers traces)
kubectl logs -n monitoring statefulset/tempo-ingester --tail=50

# Check Tempo Compactor (uploads to S3)
kubectl logs -n monitoring deployment/tempo-compactor --tail=50

# Check Tempo S3 bucket (Ceph)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin bucket stats --bucket=tempo-traces

# ══════════════════════════════════════════════════════════════
# JAEGER UI (Uses Tempo as Backend)
# ══════════════════════════════════════════════════════════════

# Port-forward to Jaeger UI
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686
# → http://localhost:16686

# Check Jaeger health
curl http://localhost:16686/

# Jaeger uses Tempo via gRPC plugin (grpc-plugin backend)
kubectl logs -n monitoring deployment/jaeger-query | grep -i tempo

# ══════════════════════════════════════════════════════════════
# THANOS
# ══════════════════════════════════════════════════════════════

# Port-forward to Thanos Query
kubectl port-forward -n monitoring svc/thanos-query 9090:9090
# → http://localhost:9090

# Check Thanos Store status
kubectl logs -n monitoring deployment/thanos-query | grep "store"

# List S3 buckets (Ceph)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin bucket list

# ══════════════════════════════════════════════════════════════
# VELERO BACKUP
# ══════════════════════════════════════════════════════════════

# List backups
velero backup get

# Create manual backup
velero backup create monitoring-manual-$(date +%Y%m%d)

# Describe backup
velero backup describe monitoring-daily-latest

# Restore from backup
velero restore create --from-backup monitoring-daily-latest

# Check restore status
velero restore get
```

### Useful PromQL Queries

```promql
# ══════════════════════════════════════════════════════════════
# SYSTEM METRICS
# ══════════════════════════════════════════════════════════════

# CPU Usage per Node (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage per Node (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk Usage per Node (%)
(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} /
     node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"})) * 100

# ══════════════════════════════════════════════════════════════
# KUBERNETES METRICS
# ══════════════════════════════════════════════════════════════

# Pod Count per Namespace
count(kube_pod_info) by (namespace)

# Container Restarts (last 1h)
increase(kube_pod_container_status_restarts_total[1h]) > 0

# Pods not Running
kube_pod_status_phase{phase!="Running"} == 1

# ══════════════════════════════════════════════════════════════
# APPLICATION METRICS
# ══════════════════════════════════════════════════════════════

# HTTP Request Rate (req/sec)
rate(http_requests_total[5m])

# HTTP Error Rate (%)
rate(http_requests_total{status=~"5.."}[5m]) /
rate(http_requests_total[5m]) * 100

# HTTP Latency p95 (seconds)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Useful LogQL Queries

```logql
# ══════════════════════════════════════════════════════════════
# LOG QUERIES
# ══════════════════════════════════════════════════════════════

# All logs from N8N
{namespace="n8n-prod"}

# Only error logs
{namespace="n8n-prod"} |= "error"

# Logs containing "database"
{namespace="n8n-prod"} |= "database"

# Error count (last 5 min)
count_over_time({namespace="n8n-prod"} |= "error" [5m])

# Top 10 error messages
topk(10, count_over_time({level="error"}[1h]))
```

---

## Summary

### What We Built

```
✅ Enterprise Observability Stack (100% IaC)
✅ Grafana Operator (68 Dashboards as CRDs)
✅ Prometheus Operator (Auto-Discovery)
✅ ServiceMonitor Magic (No Manual Config!)
✅ Loki Log Aggregation
✅ Thanos Unlimited Storage (Ceph S3)
✅ Velero Backup (Everything!)
✅ GitOps-Ready (ArgoCD Synced)
```

### Key Benefits

| Feature | Benefit |
|---------|---------|
| **CRDs** | Git-based, Type-safe, Self-healing |
| **ServiceMonitor** | Auto-discovery, No manual config |
| **Thanos** | Unlimited retention, S3 storage |
| **Loki** | Fast log queries, Low cost |
| **Velero** | Disaster recovery in minutes |
| **GitOps** | Everything in Git, ArgoCD synced |

### Files Reference

```
kubernetes/infrastructure/monitoring/
├─ OBSERVABILITY-MASTER-GUIDE.md          ← YOU ARE HERE
├─ grafana/
│  ├─ kustomization.yaml                  ← 68 dashboards
│  └─ enterprise-dashboards/
├─ servicemonitors/
│  ├─ servicemonitor-n8n.yaml             ← Example ServiceMonitor
│  └─ ... (all ServiceMonitors)
├─ kube-prometheus-stack/
│  └─ values.yaml                         ← Prometheus config
└─ velero/
   └─ schedule-monitoring-daily.yaml      ← Daily backup
```

---

**Created for:** Talos Homelab Production
**Last Updated:** 2025-10-21
**Grafana Operator:** v5.19.1
**Prometheus Operator:** v0.77.0
**Loki:** v2.9.0
**Thanos:** v0.35.0
**Velero:** v1.13.0
