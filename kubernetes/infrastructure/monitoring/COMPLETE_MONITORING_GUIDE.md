# Complete Monitoring Stack Guide - Tier 0 Enterprise Observability

## Inhaltsverzeichnis

1. [Was ist Monitoring?](#was-ist-monitoring)
2. [Die Drei Säulen der Observability](#die-drei-säulen-der-observability)
3. [Komponenten-Übersicht](#komponenten-übersicht)
4. [Datenfluss-Diagramme](#datenfluss-diagramme)
5. [Operator vs Helm Deployment](#operator-vs-helm-deployment)
6. [Aktuelle Homelab-Konfiguration](#aktuelle-homelab-konfiguration)
7. [Best Practices & Optimierungen](#best-practices--optimierungen)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Was ist Monitoring?

**Monitoring** = Beobachtung und Aufzeichnung von System- und Anwendungsverhalten in Echtzeit

### Warum Monitoring?

1. **Probleme erkennen** - Bevor Benutzer sie bemerken
2. **Performance optimieren** - Bottlenecks identifizieren
3. **Kapazität planen** - Wann brauche ich mehr Ressourcen?
4. **Security** - Ungewöhnliches Verhalten erkennen
5. **Compliance** - Audit Logs für Regulierungen

### Monitoring in diesem Homelab

**Ziel:** Enterprise-Grade Observability wie in US-Unternehmen 2025

**Stack:**
- **Prometheus** - Metrics (Zahlen: CPU, RAM, Request Rate)
- **Loki** - Logs (Text: Error Messages, Events)
- **Grafana** - Visualization (Dashboards, Alerts)
- **Jaeger** - Traces (Distributed Request Tracking)
- **Alertmanager** - Alerting (Slack, Email, PagerDuty)

---

## Die Drei Säulen der Observability

### 1. Metrics (Metriken) - Prometheus

**Was:** Numerische Zeitreihen-Daten

**Beispiele:**
- CPU-Auslastung: 45%
- Memory Usage: 2.5GB
- HTTP Requests/s: 1200
- Disk IOPS: 500

**Datenformat:**
```promql
# Prometheus metric
http_requests_total{method="GET", status="200", job="n8n"} 15234
```

**Vorteile:**
- ✅ Sehr kompakt (nur Zahlen)
- ✅ Schnelle Queries (Aggregation über Millionen Datenpunkte)
- ✅ Langzeit-Trends erkennbar

**Nachteile:**
- ❌ Kein Kontext (warum ist CPU hoch?)
- ❌ Keine Details (welcher Request war langsam?)

### 2. Logs (Protokolle) - Loki

**Was:** Textbasierte Event-Streams

**Beispiele:**
- `ERROR: Database connection timeout after 30s`
- `INFO: User 'tim275' logged in from 192.168.1.100`
- `WARN: Memory usage above 80% threshold`

**Datenformat:**
```
{namespace="monitoring", pod="loki-0", level="error"}
2025-10-20T03:14:08Z ERROR Failed to flush chunk: timeout
```

**Vorteile:**
- ✅ Vollständiger Kontext (Stack Traces, Error Messages)
- ✅ Debugging möglich (genau sehen was passiert ist)
- ✅ Compliance (Audit Logs für Regulierungen)

**Nachteile:**
- ❌ Große Datenmengen (GBs pro Tag)
- ❌ Langsame Queries (Text-Suche über TBs)
- ❌ Teuer bei langer Retention

### 3. Traces (Verteilte Anfragen) - Jaeger

**Was:** End-to-End Request Flow durch Microservices

**Beispiel:**
```
User Request → API Gateway (50ms)
            → Auth Service (20ms)
            → Database Query (200ms) ← SLOW!
            → Response (10ms)
Total: 280ms
```

**Datenformat:**
```
Trace ID: abc123
Span 1: api-gateway → auth-service (20ms)
Span 2: auth-service → database (200ms)
Span 3: database → response (10ms)
```

**Vorteile:**
- ✅ Sieht komplette Request-Journey
- ✅ Findet Bottlenecks genau
- ✅ Microservices-Debugging

**Nachteile:**
- ❌ Nur für Microservices sinnvoll
- ❌ Instrumentation erforderlich (Code-Änderungen)
- ❌ Hoher Overhead bei 100% Sampling

### Wann was nutzen?

| Frage | Tool | Beispiel |
|-------|------|----------|
| **Ist das System gesund?** | Metrics (Prometheus) | CPU < 80%, Memory < 90% |
| **Warum ist es langsam?** | Logs (Loki) | ERROR: Database timeout |
| **Welcher Service ist langsam?** | Traces (Jaeger) | Auth-Service: 200ms (slow!) |
| **Was soll ich tun?** | Alerts (Alertmanager) | Slack: API Server DOWN! |
| **Wie sieht es aus?** | Visualization (Grafana) | Dashboard mit Graphen |

---

## Komponenten-Übersicht

### Prometheus - Metrics Collection

**Von wem:** Cloud Native Computing Foundation (CNCF)
**Lizenz:** Apache 2.0 (Open Source)
**Sprache:** Go
**Seit:** 2012 (SoundCloud)

**Was es tut:**
1. **Scraping** - Holt Metrics von Anwendungen (HTTP Pull)
2. **Storage** - Speichert Zeitreihen-Daten lokal (TSDB)
3. **Querying** - PromQL für Abfragen
4. **Alerting** - Sendet Alerts an Alertmanager

**Deployment-Modi:**
- **Standalone** - Single Binary, kein HA
- **HA Pair** - 2+ Replicas mit externem Storage
- **Federated** - Hierarchisch (Cluster → Global)
- **Remote Write** - Zu VictoriaMetrics/Thanos

**Datenquellen:**
```
Applications (exporters)
    ↓
ServiceMonitors (CRDs)
    ↓
Prometheus (scrapes every 30s)
    ↓
TSDB Storage (local disk)
```

### Grafana - Visualization

**Von wem:** Grafana Labs
**Lizenz:** AGPLv3 (OSS) + Enterprise (paid)
**Sprache:** TypeScript/Go
**Seit:** 2014

**Was es tut:**
1. **Dashboards** - Visualisiert Metrics/Logs
2. **Alerts** - Grafana Unified Alerting (optional)
3. **Datasources** - Verbindet zu Prometheus, Loki, Jaeger, etc.
4. **Users** - RBAC, Teams, OIDC/SAML

**Deployment-Modi:**
- **Helm Chart** - Traditionell (values.yaml)
- **Grafana Operator** - Kubernetes-native (CRDs)

**Datenquellen:**
```
Grafana
  ↓
Datasources:
  - Prometheus (metrics)
  - Loki (logs)
  - Jaeger (traces)
  - Alertmanager (alerts)
  - Elasticsearch (logs alternative)
```

### Loki - Log Aggregation

**Von wem:** Grafana Labs
**Lizenz:** AGPLv3 (Open Source)
**Sprache:** Go
**Seit:** 2018

**Was es tut:**
1. **Ingestion** - Empfängt Logs von Promtail/Fluent Bit
2. **Indexing** - Nur Labels indexiert (nicht Log-Content!)
3. **Storage** - Chunks in Object Storage (S3/Ceph)
4. **Querying** - LogQL (ähnlich PromQL)

**Deployment-Modi:**
- **SingleBinary** - Monolith (1 Pod, kein HA)
- **Simple Scalable** - Read/Write/Backend (HA-ready)
- **Microservices** - Distributor, Ingester, Querier, etc.

**Datenquellen:**
```
Applications (stdout/stderr)
    ↓
Promtail / Fluent Bit (log shipper)
    ↓
Loki Gateway (nginx proxy)
    ↓
Loki (distributor → ingester)
    ↓
Object Storage (S3/Ceph)
```

### Alertmanager - Alert Routing

**Von wem:** Cloud Native Computing Foundation (CNCF)
**Lizenz:** Apache 2.0
**Sprache:** Go
**Teil von:** Prometheus Project

**Was es tut:**
1. **Grouping** - Fasst ähnliche Alerts zusammen
2. **Inhibition** - Unterdrückt redundante Alerts
3. **Silencing** - Temporär Alerts stummschalten
4. **Routing** - Nach Priority/Labels an Channels

**Notification Channels:**
- Slack
- Email
- PagerDuty
- Webhook (Keep AIOps, Opsgenie)
- Custom (Telegram, Discord, etc.)

---

## Datenfluss-Diagramme

### Metrics Flow (Prometheus → Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                    METRICS DATA FLOW                             │
└─────────────────────────────────────────────────────────────────┘

Step 1: APPLICATION EXPOSES METRICS
┌────────────────────────┐
│  N8N Application       │
│  Port: 8080            │
│  ┌──────────────────┐  │
│  │ /metrics endpoint│  │  ← Prometheus format
│  │ http_req_total=1 │  │
│  │ cpu_usage=0.45   │  │
│  └──────────────────┘  │
└────────────────────────┘

Step 2: SERVICEMONITOR DISCOVERS APP
┌────────────────────────┐
│ ServiceMonitor (CRD)   │
│ ┌──────────────────┐   │
│ │ namespace: apps  │   │
│ │ selector:        │   │
│ │   app: n8n       │   │
│ │ port: http       │   │
│ └──────────────────┘   │
└────────────────────────┘
         │
         ↓ Watched by Prometheus Operator

Step 3: PROMETHEUS SCRAPES METRICS
┌────────────────────────┐
│  Prometheus            │
│  ┌──────────────────┐  │
│  │ GET /metrics     │  │ ← Every 30 seconds
│  │ → Scrape N8N     │  │
│  │ → Store in TSDB  │  │
│  └──────────────────┘  │
│  Storage: 20GB Ceph    │
│  Retention: 15 days    │
└────────────────────────┘
         │
         ↓ Query via PromQL

Step 4: GRAFANA VISUALIZES DATA
┌────────────────────────┐
│  Grafana Dashboard     │
│  ┌──────────────────┐  │
│  │ Datasource:      │  │
│  │   Prometheus     │  │
│  │                  │  │
│  │ Query:           │  │
│  │ rate(http_req[5m])│ │
│  │                  │  │
│  │ Graph: ───────   │  │
│  │       /      \   │  │
│  │      /        ── │  │
│  └──────────────────┘  │
└────────────────────────┘
         │
         ↓ User views dashboard

Step 5: USER SEES METRICS
┌────────────────────────┐
│  Web Browser           │
│  http://grafana:3000   │
│  ┌──────────────────┐  │
│  │ 📊 N8N Dashboard │  │
│  │ Requests: 1.2k/s │  │
│  │ Latency: 45ms    │  │
│  │ Errors: 0.1%     │  │
│  └──────────────────┘  │
└────────────────────────┘
```

### Logs Flow (Loki → Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                     LOGS DATA FLOW                               │
└─────────────────────────────────────────────────────────────────┘

Step 1: APPLICATION WRITES LOGS
┌────────────────────────┐
│  N8N Pod               │
│  ┌──────────────────┐  │
│  │ stdout/stderr    │  │
│  │ ERROR: DB timeout│  │
│  │ INFO: User login │  │
│  └──────────────────┘  │
└────────────────────────┘
         │
         ↓ Kubernetes logs (kubectl logs)

Step 2: PROMTAIL COLLECTS LOGS
┌────────────────────────┐
│  Promtail DaemonSet    │
│  (runs on every node)  │
│  ┌──────────────────┐  │
│  │ Read pod logs    │  │
│  │ Add labels:      │  │
│  │  namespace=apps  │  │
│  │  pod=n8n-0       │  │
│  └──────────────────┘  │
└────────────────────────┘
         │
         ↓ HTTP POST /loki/api/v1/push

Step 3: LOKI INGESTS & STORES LOGS
┌────────────────────────┐
│  Loki SingleBinary     │
│  ┌──────────────────┐  │
│  │ Distributor      │  │ ← Receives logs
│  │    ↓             │  │
│  │ Ingester         │  │ ← Creates chunks
│  │    ↓             │  │
│  │ Storage          │  │ ← Filesystem/S3
│  └──────────────────┘  │
│  Retention: 30 days    │
│  Size: 50Gi            │
└────────────────────────┘
         │
         ↓ Query via LogQL

Step 4: GRAFANA QUERIES LOGS
┌────────────────────────┐
│  Grafana Explore       │
│  ┌──────────────────┐  │
│  │ Datasource: Loki │  │
│  │                  │  │
│  │ Query:           │  │
│  │ {namespace="apps"}│ │
│  │ |= "ERROR"       │  │
│  │                  │  │
│  │ Results:         │  │
│  │ ERROR: DB timeout│  │
│  │ ERROR: Auth fail │  │
│  └──────────────────┘  │
└────────────────────────┘
         │
         ↓ User searches logs

Step 5: USER DEBUGS ISSUES
┌────────────────────────┐
│  Web Browser           │
│  http://grafana:3000   │
│  ┌──────────────────┐  │
│  │ 🔍 Logs Viewer   │  │
│  │ Filter: ERROR    │  │
│  │ Time: Last 6h    │  │
│  │ Found: 15 errors │  │
│  └──────────────────┘  │
└────────────────────────┘
```

### Complete Stack Integration

```
┌──────────────────────────────────────────────────────────────────────────┐
│                  COMPLETE MONITORING STACK ARCHITECTURE                   │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  TIER 3: USER APPLICATIONS                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │   N8N    │  │   Kafka  │  │  Elastic │  │   Rook   │               │
│  │  (App)   │  │  (Stream)│  │  (Search)│  │  (Storage)│               │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬────┘               │
│        │             │              │             │                      │
│        │ /metrics    │ /metrics     │ /metrics    │ /metrics            │
│        │ logs        │ logs         │ logs        │ logs                │
│        │             │              │             │                      │
└────────┼─────────────┼──────────────┼─────────────┼──────────────────────┘
         │             │              │             │
         ↓             ↓              ↓             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  TIER 1: COLLECTION LAYER                                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  METRICS                           LOGS                                  │
│  ┌───────────────────┐            ┌───────────────────┐                 │
│  │  ServiceMonitors  │            │  Promtail Pods    │                 │
│  │  (CRDs)           │            │  (DaemonSet)      │                 │
│  │  ┌─────────────┐  │            │  ┌─────────────┐  │                │
│  │  │ Namespace:* │  │            │  │ Read /var/  │  │                │
│  │  │ Selector:   │  │            │  │ log/pods/** │  │                │
│  │  │   app=n8n   │  │            │  │ Add labels  │  │                │
│  │  └─────────────┘  │            │  └─────────────┘  │                │
│  └──────┬────────────┘            └──────┬────────────┘                 │
│         │                                 │                              │
└─────────┼─────────────────────────────────┼──────────────────────────────┘
          │                                 │
          ↓                                 ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  TIER 0: STORAGE & PROCESSING                                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────┐         ┌──────────────────────┐              │
│  │  PROMETHEUS          │         │  LOKI                │              │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │              │
│  │  │ TSDB Storage   │  │         │  │ SingleBinary   │  │              │
│  │  │ 20GB Ceph      │  │         │  │ 50Gi Ceph      │  │              │
│  │  │ Retention: 15d │  │         │  │ Retention: 30d │  │              │
│  │  │                │  │         │  │                │  │              │
│  │  │ Metrics:       │  │         │  │ Logs:          │  │              │
│  │  │ - CPU usage    │  │         │  │ - ERROR msgs   │  │              │
│  │  │ - Memory       │  │         │  │ - INFO events  │  │              │
│  │  │ - Request rate │  │         │  │ - WARN status  │  │              │
│  │  └────────────────┘  │         │  └────────────────┘  │              │
│  └──────────┬───────────┘         └──────────┬───────────┘              │
│             │                                 │                          │
│             └─────────────┬───────────────────┘                          │
│                           │                                              │
└───────────────────────────┼──────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  TIER 0: VISUALIZATION & ALERTING                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  GRAFANA OPERATOR                                             │       │
│  │  ┌────────────────────┐  ┌────────────────────┐             │       │
│  │  │ Grafana Instance   │  │ Datasources (CRDs) │             │       │
│  │  │ ┌────────────────┐ │  │ ┌────────────────┐ │             │       │
│  │  │ │ Dashboards:    │ │  │ │ - Prometheus   │ │             │       │
│  │  │ │ - Tier 0-3     │ │  │ │ - Loki         │ │             │       │
│  │  │ │ - Executive    │ │  │ │ - Alertmanager │ │             │       │
│  │  │ │                │ │  │ │ - Jaeger       │ │             │       │
│  │  │ │ Users:         │ │  │ └────────────────┘ │             │       │
│  │  │ │ - OIDC (opt)   │ │  └────────────────────┘             │       │
│  │  │ │ - Admin        │ │                                      │       │
│  │  │ └────────────────┘ │                                      │       │
│  │  └────────────────────┘                                      │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  ALERTMANAGER (2 replicas)                                   │       │
│  │  ┌────────────────────────────────────────────────────┐      │       │
│  │  │ Alert Routing (Priority-based)                     │      │       │
│  │  │ ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐   │      │       │
│  │  │ │ P1     │  │ P2     │  │ P3     │  │ P5     │   │      │       │
│  │  │ │ 5min   │  │ 15min  │  │ 1h     │  │ 4h     │   │      │       │
│  │  │ │ Slack  │  │ Slack  │  │ Slack  │  │ Slack  │   │      │       │
│  │  │ │ 🔴     │  │ 🟠     │  │ 🟡     │  │ 🔵     │   │      │       │
│  │  │ └────────┘  └────────┘  └────────┘  └────────┘   │      │       │
│  │  │                                                    │      │       │
│  │  │ Keep AIOps + Ollama AI (all alerts)              │      │       │
│  │  └────────────────────────────────────────────────────┘      │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  END USER ACCESS                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  http://grafana.timourhomelab.org                                        │
│  - View dashboards                                                        │
│  - Search logs                                                            │
│  - Create alerts                                                          │
│  - Explore metrics                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Operator vs Helm Deployment

### Was ist ein Kubernetes Operator?

**Definition:** Software die Kubernetes um domänenspezifisches Wissen erweitert

**Konzept:**
```
Traditional Deployment:
You → Helm Chart → YAML → Kubernetes → Pods

Operator Pattern:
You → CRD (Custom Resource) → Operator → Smart Logic → Pods
```

**Vorteile:**
1. **Deklarativ** - Beschreibe was du willst, nicht wie
2. **Self-Healing** - Operator repariert automatisch
3. **Day 2 Operations** - Upgrades, Backups, Scaling
4. **Domain Knowledge** - Best Practices eingebaut

**Beispiel - Prometheus Scaling:**

**Ohne Operator (Helm):**
```bash
# values.yaml ändern
prometheus:
  replicas: 2

# Helm upgrade
helm upgrade prometheus prometheus-community/prometheus -f values.yaml

# Manuell Thanos konfigurieren
# Manuell ServiceMonitors erstellen
# Manuell Alert Rules deployen
```

**Mit Operator:**
```yaml
# Prometheus CRD
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: main
spec:
  replicas: 2
  serviceMonitorSelector: {}  # Auto-discover all ServiceMonitors
  ruleSelector: {}            # Auto-discover all PrometheusRules
```

Operator macht automatisch:
- ✅ ServiceMonitor Discovery
- ✅ Alert Rule Loading
- ✅ Secret Management
- ✅ Graceful Upgrades

### Prometheus: Operator (kube-prometheus-stack)

**Current Deployment:** Helm Chart `kube-prometheus-stack`

**Was ist kube-prometheus-stack?**
- Helm Chart das Prometheus Operator deployed
- NICHT nur Prometheus, sondern komplettes Monitoring-Stack

**Komponenten:**
1. **Prometheus Operator** - Verwaltet Prometheus Instances
2. **Prometheus** - Metrics Collection
3. **Alertmanager** - Alert Routing
4. **Grafana** - Visualization (optional, bei uns disabled)
5. **kube-state-metrics** - Kubernetes Cluster Metrics
6. **node-exporter** - Node Hardware Metrics

**CRDs (Custom Resource Definitions):**

```yaml
# 1. Prometheus Instance
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: kube-prometheus-stack
spec:
  retention: 15d
  retentionSize: 18GB
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: rook-ceph-block-enterprise
        resources:
          requests:
            storage: 20G

# 2. ServiceMonitor (auto-discovery)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: n8n-metrics
  namespace: apps
spec:
  selector:
    matchLabels:
      app: n8n
  endpoints:
    - port: http
      path: /metrics
      interval: 30s

# 3. PrometheusRule (alerts)
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tier0-control-plane
spec:
  groups:
    - name: kubernetes
      rules:
        - alert: KubeAPIServerDown
          expr: up{job="kube-apiserver"} == 0
          for: 1m
          labels:
            severity: critical
            priority: P1
```

**Warum Operator statt Helm-Only?**

| Feature | Helm Chart | kube-prometheus-stack (Operator) |
|---------|------------|----------------------------------|
| **ServiceMonitor Auto-Discovery** | ❌ Manual config | ✅ Automatic (label selector) |
| **Alert Rule Loading** | ❌ ConfigMaps | ✅ PrometheusRule CRDs |
| **Multi-Namespace Scraping** | ⚠️ Komplex | ✅ Einfach (`namespaceSelector: {}`) |
| **Upgrades** | ⚠️ Manual apply | ✅ Operator handles |
| **Secret Rotation** | ❌ Manual | ✅ Automatic reconciliation |
| **GitOps-Friendly** | ⚠️ OK | ✅ Excellent (CRDs in Git) |

**Best Practice:** ✅ **Operator verwenden** (kube-prometheus-stack)

### Grafana: Operator vs Helm

**Current Deployment:** Grafana Operator

**Vergleich:**

#### Grafana Helm Chart (Traditional)

```yaml
# values.yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus:9090
        isDefault: true

dashboards:
  default:
    my-dashboard:
      json: |
        {
          "dashboard": {...}
        }
```

**Probleme:**
- ❌ Dashboards als JSON in YAML (unreadable)
- ❌ Datasources in values.yaml (nicht versioniert separat)
- ❌ Kein Multi-Tenancy
- ❌ Manuelles Dashboard-Management

#### Grafana Operator (Kubernetes-Native)

```yaml
# 1. Grafana Instance
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
spec:
  config:
    log:
      mode: console
  deployment:
    spec:
      template:
        spec:
          containers:
            - name: grafana
              resources:
                limits:
                  cpu: 500m
                  memory: 512Mi

# 2. Datasource (CRD)
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: prometheus
spec:
  datasource:
    name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true

# 3. Dashboard (CRD)
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: n8n-overview
spec:
  folder: Tier 3 - Applications
  json: |
    {
      "title": "N8N Overview",
      ...
    }
```

**Vorteile Operator:**
- ✅ Kubernetes-native (CRDs statt ConfigMaps)
- ✅ GitOps-friendly (separate files für Datasources/Dashboards)
- ✅ Auto-Reload bei Änderungen
- ✅ Multi-Instance support (mehrere Grafana Instanzen)
- ✅ Namespace-scoped Dashboards

**Comparison Table:**

| Feature | Helm Chart | Grafana Operator |
|---------|------------|------------------|
| **Datasources** | values.yaml | GrafanaDatasource CRD |
| **Dashboards** | ConfigMaps/values | GrafanaDashboard CRD |
| **Folders** | ❌ Nicht möglich | ✅ GrafanaFolder CRD |
| **Multi-Instance** | ⚠️ 1 per namespace | ✅ Unlimited |
| **Auto-Reload** | ❌ Manual restart | ✅ Automatic |
| **GitOps** | ⚠️ OK | ✅ Excellent |
| **Complexity** | ✅ Simple | ⚠️ More CRDs |

**Best Practice:** ✅ **Operator verwenden** (besonders für GitOps)

**Warum du Operator nutzt:**
- Dashboards als separate YAML files (nicht in values.yaml)
- Datasources versioniert in Git
- Automatisches Reload bei Änderungen
- Cleaner separation of concerns

### Loki: Operator vs Helm

**Current Deployment:** Helm Chart `grafana/loki`

**Loki Operator Optionen:**

#### 1. Grafana Loki Operator (Official)

**GitHub:** `github.com/grafana/loki/tree/main/operator`
**Status:** Production-ready (seit 2023)

**Features:**
- ✅ LokiStack CRD (deployment management)
- ✅ Multi-tenancy (OpenShift integration)
- ✅ Automatic mTLS (secure communication)
- ✅ Object Storage management
- ✅ Gateway with authentication

**CRDs:**
```yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging
spec:
  size: 1x.small    # Pre-defined sizes
  storage:
    secret:
      name: loki-s3-credentials
      type: s3
    schemas:
      - version: v13
        effectiveDate: "2024-01-01"
  tenants:
    mode: openshift   # Multi-tenancy
```

**Deployment Sizes:**
```
1x.extra-small: Development (1 replica each)
1x.small:       Homelab (<100GB/day)
1x.medium:      Production (<500GB/day)
2x.small:       HA Production
```

#### 2. Helm Chart (Current)

```yaml
# values.yaml
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  storage:
    type: filesystem  # or s3

  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 10

singleBinary:
  replicas: 1
  persistence:
    size: 50Gi
```

**Comparison:**

| Feature | Helm Chart | Loki Operator |
|---------|------------|---------------|
| **Deployment Mode** | Manual config | Pre-defined sizes |
| **Storage Management** | Manual | Automatic (via Secret) |
| **Multi-Tenancy** | Manual config | Built-in (OpenShift mode) |
| **TLS/mTLS** | Manual certs | Automatic |
| **Upgrades** | helm upgrade | Operator handles |
| **Object Storage** | Manual setup | Secret-based config |
| **Gateway** | Optional nginx | Built-in with auth |
| **Complexity** | ✅ Simple | ⚠️ More complex |
| **Flexibility** | ✅ Full control | ⚠️ Opinionated |

**Wann Operator nutzen?**

✅ **JA (Operator):**
- OpenShift/Enterprise environment
- Multi-Tenancy erforderlich
- Automatische TLS gewünscht
- Wenig Loki-Erfahrung (pre-defined sizes helfen)

❌ **NEIN (Helm):**
- Homelab/Development
- Volle Kontrolle über Config gewünscht
- Spezielle Setup-Requirements
- Kein OpenShift

**Empfehlung für Homelab:** ✅ **Helm Chart** (aktuell korrekt!)

**Warum?**
- Volle Flexibilität (SingleBinary → Simple Scalable)
- Kein OpenShift-Overhead
- Einfachere Konfiguration
- Community-Support besser für Helm

**Migration zu Operator:**
Nur wenn:
- Du zu OpenShift wechselst
- Multi-Tenancy brauchst (mehrere Teams)
- Enterprise-Support willst

### Summary: Operator vs Helm Decision Matrix

| Component | Current | Recommendation | Reason |
|-----------|---------|----------------|--------|
| **Prometheus** | kube-prometheus-stack (Operator) | ✅ Keep | ServiceMonitor auto-discovery, GitOps |
| **Grafana** | Grafana Operator | ✅ Keep | Dashboard CRDs, multi-instance, GitOps |
| **Loki** | Helm Chart | ✅ Keep | Flexibility, homelab-friendly, simple |
| **Alertmanager** | Included in kube-prom-stack | ✅ Keep | Integrated with Prometheus Operator |

**General Rule:**

```
Use Operator when:
- GitOps is critical
- Auto-discovery needed
- Multi-namespace management
- Day 2 operations complex

Use Helm when:
- Simple deployment
- Full control needed
- Homelab/Development
- Component-specific requirements
```

---

## Aktuelle Homelab-Konfiguration

### Deployment Overview

| Component | Method | Version | Replicas | Storage |
|-----------|--------|---------|----------|---------|
| **Prometheus** | kube-prometheus-stack | v3.5.0 | 1 | 20Gi Ceph |
| **Grafana** | Grafana Operator | v12.1.0 | 1 | Ephemeral |
| **Loki** | Helm Chart | v3.1.1 | 1 (SingleBinary) | 50Gi Ceph |
| **Alertmanager** | kube-prometheus-stack | v0.27.0 | 2 | No storage |
| **Jaeger** | Helm | v1.61.0 | 1 | Ephemeral |

### Applied Quick Wins (Today)

#### ✅ 1. Prometheus Retention

**File:** `kubernetes/infrastructure/monitoring/kube-prometheus-stack/values.yaml`

```yaml
prometheus:
  prometheusSpec:
    retention: 15d           # Explicit retention
    retentionSize: "18GB"    # Prevents disk full
```

**Status:** ✅ Applied via ArgoCD

#### ✅ 2. Loki Retention & Rate Limits

**File:** `kubernetes/infrastructure/monitoring/loki/values.yaml`

```yaml
loki:
  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 10
    ingestion_burst_size_mb: 20
    max_line_size: 256kb
    max_streams_per_user: 10000

  compactor:
    retention_enabled: true
```

**Status:** ✅ Applied via ArgoCD

#### ✅ 3. Loki Storage Increase

```yaml
singleBinary:
  persistence:
    size: 50Gi  # Increased from 10Gi
```

**Status:** ✅ Applied via ArgoCD

### Current Issues

#### 🔴 CRITICAL: Grafana Datasource UID Mismatch

**Problem:** 101 Dashboard-Files, viele mit falschen Datasource UIDs

**Current UIDs:**
- Prometheus: `bcc9d3ee-2926-4b20-b364-f067529673ff`
- Loki: `d2b40721-7276-43cf-afbc-d064116217e4`
- Alertmanager: `4a200eff-39ee-4f38-9608-28b9e8535176`

**Solution:**
```json
// BAD
{"datasource": {"uid": "WRONG_UID"}}

// GOOD
{"datasource": "Prometheus"}  // Use name instead
```

**Effort:** 2-4 hours (101 files)
**Priority:** HIGH (user can't see many dashboards)

#### ⚠️ WARNING: Loki Filesystem Storage

**Problem:** Logs auf lokalem Disk, nicht production-ready

**Issues:**
- No HA (Logs lost if pod dies)
- No retention (will fill disk)
- Cannot scale horizontally

**Solution:** Migrate to Ceph RGW S3
- See `LOKI_BEST_PRACTICES.md` for migration guide
- Effort: 4-6 hours
- Priority: MEDIUM (works for now, but not scalable)

### Pending Tasks

**This Month:**
1. Fix Grafana datasource UIDs (2-4h)
2. Create dashboard folder hierarchy (1-2h)
3. Migrate Loki to S3 (4-6h)
4. Enable Grafana OIDC if Keycloak available (1h)

**This Quarter:**
5. Enable VictoriaMetrics remote write (2-4h)
6. Create recording rules for slow queries (4-6h)

---

## Best Practices & Optimierungen

### Prometheus Best Practices

**From `PROMETHEUS_BEST_PRACTICES.md`:**

1. ✅ **Explicit Retention** (done today)
2. ⚠️ **HA Setup** - 2+ replicas (not yet)
3. ❌ **Remote Write** - VictoriaMetrics/Thanos (planned)
4. ❌ **Recording Rules** - For expensive queries (planned)
5. ✅ **Resource Limits** - Already configured
6. ✅ **ServiceMonitor Discovery** - Already enabled

**Production Readiness:** 3/9 (33%)

### Grafana Best Practices

**From `GRAFANA_SETUP_GUIDE.md`:**

1. ✅ **Grafana Operator** - Using CRDs (done)
2. ✅ **Datasources Configured** - Prometheus, Loki, Alertmanager
3. 🔴 **Fix Datasource UIDs** - CRITICAL (101 dashboards broken)
4. ❌ **Dashboard Folders** - No hierarchy yet
5. ❌ **OIDC** - Using default admin password
6. ❌ **Persistent Storage** - Ephemeral (user prefs lost on restart)

**Production Readiness:** 3/8 (38%)

### Loki Best Practices

**From `LOKI_BEST_PRACTICES.md`:**

1. ✅ **Retention Configuration** (done today)
2. ✅ **Rate Limits** (done today)
3. ✅ **Modern TSDB v13 Schema** - Already using
4. ⚠️ **Filesystem Storage** - Should be S3
5. ⚠️ **SingleBinary Mode** - Should be Simple Scalable for production
6. ❌ **Label Cardinality Audit** - Not done yet

**Production Readiness:** 3/8 (38%)

### Overall Stack Health

**Summary:**
- ✅ **Functional** - Metrics & Logs are collected
- ✅ **Resource-Efficient** - Good for homelab
- ⚠️ **Production-Ready** - 40-50% (needs HA, S3, OIDC)
- 🔴 **User-Facing Issues** - Datasource UID mismatch

**Next Critical Fix:** Grafana Datasource UIDs (blocks user)

---

## Troubleshooting Guide

### Common Issues

#### Issue: "Datasource not found" in Grafana

**Symptoms:**
- Dashboard shows "datasource not found"
- Panel queries fail
- Many dashboards broken

**Root Cause:** Datasource UID mismatch

**Solution:**
```bash
# 1. Get current UIDs
kubectl get grafanadatasources -n grafana -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.uid}{"\n"}{end}'

# 2. Update dashboard JSONs
# Replace hardcoded UIDs with datasource names
```

**See:** `GRAFANA_SETUP_GUIDE.md` Section "Datasource Configuration"

#### Issue: Prometheus disk full

**Symptoms:**
- Prometheus pod CrashLoopBackOff
- Logs: `no space left on device`

**Root Cause:** No `retentionSize` configured

**Solution:**
✅ Already fixed today! (`retentionSize: "18GB"`)

**Prevention:**
- Monitor PVC usage: `kubectl get pvc -n monitoring`
- Set up alert for >85% disk usage

#### Issue: Loki ingestion errors

**Symptoms:**
- Logs not appearing in Grafana
- Loki logs: `ingestion rate limit exceeded`

**Root Cause:** App sending too many logs

**Solution:**
✅ Already fixed today! (rate limits configured)

**Check:**
```bash
# See dropped logs
kubectl logs -n monitoring loki-0 | grep "discarded"

# Increase limits if legitimate traffic
# In values.yaml: ingestion_rate_mb: 20  (default was 10)
```

#### Issue: Slow Grafana dashboards

**Symptoms:**
- Dashboards take >10s to load
- Queries timeout

**Root Causes:**
1. Too many panels (>30)
2. Long time range (30d instead of 6h)
3. High-resolution queries
4. No recording rules

**Solutions:**
1. Split dashboard into multiple (use rows)
2. Reduce default time range: `from: now-6h`
3. Use `$__rate_interval` instead of hardcoded `[5m]`
4. Create recording rules for expensive queries

**See:** `GRAFANA_SETUP_GUIDE.md` Section "Performance Optimization"

#### Issue: High memory usage (Prometheus)

**Symptoms:**
- Prometheus pod OOMKilled
- High memory usage (>4GB)

**Root Causes:**
1. Too many metrics series (high cardinality)
2. Large queries
3. Under-provisioned memory

**Solutions:**
```bash
# Check cardinality
kubectl exec -n monitoring prometheus-0 -- \
  promtool tsdb analyze /prometheus

# Top 10 high-cardinality metrics
topk(10, count by (__name__)({__name__=~".+"}))

# Solutions:
# 1. Drop high-cardinality metrics (relabeling)
# 2. Increase memory limits
# 3. Enable remote_write to VictoriaMetrics
```

---

## Quick Reference

### Important URLs

```
Grafana:      http://grafana.timourhomelab.org
Prometheus:   http://prometheus.timourhomelab.org (internal only)
Alertmanager: http://alertmanager.timourhomelab.org (internal only)
```

### Important Commands

```bash
# Check ArgoCD sync status
kubectl get application kube-prometheus-stack loki -n argocd

# Force ArgoCD sync
kubectl patch application loki -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Open: http://localhost:9090/targets

# Check Loki logs
kubectl logs -n monitoring loki-0 -f

# Check Grafana datasources
kubectl get grafanadatasources -n grafana

# Check Grafana dashboards
kubectl get grafanadashboard -A
```

### Important Files

```
Prometheus Config:
  kubernetes/infrastructure/monitoring/kube-prometheus-stack/values.yaml

Loki Config:
  kubernetes/infrastructure/monitoring/loki/values.yaml

Grafana Config:
  kubernetes/infrastructure/monitoring/grafana/grafana.yaml

Grafana Datasources:
  kubernetes/infrastructure/monitoring/grafana/datasources/*.yaml

Alert Rules:
  kubernetes/infrastructure/monitoring/alertmanager/tier*.yaml

Dashboards:
  kubernetes/infrastructure/monitoring/grafana/dashboards/**/*.yaml
```

### Documentation Index

- `MONITORING_STACK_OVERVIEW.md` - High-level architecture
- `PROMETHEUS_BEST_PRACTICES.md` - Prometheus setup & optimization
- `GRAFANA_SETUP_GUIDE.md` - Grafana configuration & troubleshooting
- `LOKI_BEST_PRACTICES.md` - Loki deployment & best practices
- `COMPLETE_MONITORING_GUIDE.md` - This file (comprehensive guide)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-20
**Status:** Complete - Production guide for Tier 0 monitoring stack
**Similar to:** `kubernetes/infrastructure/observability/elasticsearch/LICENSE_COMPARISON.md` (comprehensive Elasticsearch guide)
