# Grafana Setup Guide - GitOps with Grafana Operator

**Cross-reference:** For observability stack components (Prometheus, Loki, Tempo, Thanos), see [OBSERVABILITY-STACK-GUIDE.md](./OBSERVABILITY-STACK-GUIDE.md)

---

## 📖 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Was ist Grafana?](#was-ist-grafana)
3. [Grafana Operator vs Helm Chart](#grafana-operator-vs-helm-chart)
4. [Grafana Operator Architecture](#grafana-operator-architecture)
5. [ServiceMonitor → Dashboard (No Data Fix!)](#servicemonitor--dashboard-no-data-fix)
6. [Grafana Dashboards Deep Dive](#grafana-dashboards-deep-dive)
7. [Backup & Disaster Recovery](#backup--disaster-recovery)
8. [Quick Reference - Grafana Commands](#quick-reference---grafana-commands)

---

## Executive Summary

### TL;DR - Grafana Setup

```
┌─────────────────────────────────────────────────────────────────┐
│ GRAFANA OPERATOR SETUP (100% GitOps)                            │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Grafana Operator - Kubernetes-native Grafana                │
│ ✅ 68 Enterprise Dashboards (as CRDs!)                         │
│ ✅ 4 Datasources (Prometheus, Loki, Tempo, Alertmanager)      │
│ ✅ 100% GitOps (ArgoCD synced)                                 │
│ ✅ Self-Healing (CRD reconciliation)                           │
│ ✅ Type-Safe (Kubernetes schema validation)                    │
│ ✅ Backup = Git Commit!                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 Was macht Grafana Operator so gut?

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
| **Grafana Dashboards** | 68 (as CRDs) |
| **Datasources** | 4 (Prometheus, Loki, Tempo, Alertmanager) |
| **Folders** | 15 (organized by domain) |
| **Dashboard Categories** | Kubernetes, Apps, Infrastructure, Security |
| **Operator Version** | v5.19.1 |
| **Auto-Sync** | ArgoCD enabled |

---

## Was ist Grafana?

### Definition (IKEA-Style)

**Grafana** = Dein **Fernseher** für Kubernetes 📺

- Zeigt **Metriken** (Prometheus) = Live TV 📊
- Zeigt **Logs** (Loki) = Untertitel 📝
- Zeigt **Traces** (Tempo) = Behind-the-Scenes 🎬
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
├─ Tempo (traces)              → http://tempo:3200
├─ Alertmanager (alerts)       → http://alertmanager:9093
└─ Jaeger (traces frontend)    → http://jaeger:16686
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

## Grafana Operator Architecture

### 🏗️ How Grafana Operator Works

```
┌─────────────────────────────────────────────────────────────────┐
│ GRAFANA OPERATOR ARCHITECTURE                                   │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────┐
│ Git Repository                     │
│ └─ kubernetes/monitoring/grafana/  │
│    ├─ grafana.yaml (Grafana CRD)  │
│    ├─ datasource.yaml             │
│    └─ dashboards/                 │
│       ├─ dashboard-1.yaml          │
│       └─ dashboard-2.yaml          │
└────────────┬───────────────────────┘
             │ git push
             ▼
┌────────────────────────────────────┐
│ ArgoCD                             │
│ └─ Watches Git repo                │
│    └─ Auto-applies changes         │
└────────────┬───────────────────────┘
             │ kubectl apply
             ▼
┌────────────────────────────────────────────────────────────────┐
│ Kubernetes API Server                                          │
│ └─ Stores CRDs:                                                │
│    ├─ Grafana CRD (defines Grafana instance)                  │
│    ├─ GrafanaDashboard CRD (defines dashboards)               │
│    ├─ GrafanaDatasource CRD (defines datasources)             │
│    └─ GrafanaFolder CRD (defines folders)                     │
└────────────┬───────────────────────────────────────────────────┘
             │ Watch CRDs
             ▼
┌────────────────────────────────────┐
│ Grafana Operator (Deployment)     │
│ └─ Watches for CRD changes         │
│    └─ Reconciles desired state     │
└────────────┬───────────────────────┘
             │ Creates/Updates
             ▼
┌────────────────────────────────────┐
│ Grafana Pod (Deployment)           │
│ ├─ HTTP API (port 3000)            │
│ └─ Database (SQLite or Postgres)   │
└────────────┬───────────────────────┘
             │ Grafana API calls
             ▼
┌────────────────────────────────────┐
│ Grafana Internal Database          │
│ ├─ Dashboards (from CRDs)         │
│ ├─ Datasources (from CRDs)        │
│ └─ Folders (from CRDs)             │
└────────────────────────────────────┘
```

### CRD Workflow (Dashboard Creation)

```
┌─────────────────────────────────────────────────────────────────┐
│ CRD WORKFLOW: GrafanaDashboard → Grafana UI                    │
└─────────────────────────────────────────────────────────────────┘

Step 1: Developer creates dashboard YAML
┌─────────────────────────────────┐
│ dashboard-n8n.yaml              │
│ apiVersion: grafana/v1beta1     │
│ kind: GrafanaDashboard          │
│ spec:                           │
│   folder: "Applications"        │
│   json: |                       │
│     {"title": "N8N Metrics"}    │
└─────────────┬───────────────────┘
              │ git commit && push
              ▼
Step 2: ArgoCD detects change
┌─────────────────────────────────┐
│ ArgoCD Application              │
│ └─ Syncs to Kubernetes          │
└─────────────┬───────────────────┘
              │ kubectl apply
              ▼
Step 3: Kubernetes API stores CRD
┌─────────────────────────────────┐
│ Kubernetes etcd                 │
│ └─ GrafanaDashboard/n8n         │
└─────────────┬───────────────────┘
              │ Watch event
              ▼
Step 4: Grafana Operator sees new CRD
┌──────────────────────────────────┐
│ Grafana Operator (Controller)   │
│ ├─ Detects: New GrafanaDashboard│
│ └─ Action: Call Grafana API     │
└─────────────┬────────────────────┘
              │ HTTP POST /api/dashboards
              ▼
Step 5: Grafana API imports dashboard
┌──────────────────────────────────┐
│ Grafana Pod                      │
│ └─ Saves dashboard to DB         │
└─────────────┬────────────────────┘
              │
              ▼
Step 6: Dashboard visible in Grafana UI
┌──────────────────────────────────┐
│ Grafana Web UI                   │
│ └─ Folder: "Applications"        │
│    └─ Dashboard: "N8N Metrics"   │
└──────────────────────────────────┘
```

### Datasource Connection Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ DATASOURCE CONNECTION FLOW                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────┐
│ GrafanaDatasource CRD           │
│ apiVersion: grafana/v1beta1     │
│ kind: GrafanaDatasource         │
│ spec:                           │
│   name: Prometheus              │
│   type: prometheus              │
│   url: http://prometheus:9090   │
└─────────────┬───────────────────┘
              │ kubectl apply
              ▼
┌─────────────────────────────────────────────────────────┐
│ Grafana Operator                                        │
│ ├─ Reads GrafanaDatasource CRD                         │
│ ├─ Calls Grafana API: POST /api/datasources            │
│ └─ Payload: {name: "Prometheus", type: "prometheus"}   │
└─────────────┬───────────────────────────────────────────┘
              │ Grafana API call
              ▼
┌─────────────────────────────────┐
│ Grafana Instance                │
│ └─ Saves datasource config      │
│    └─ Tests connection:         │
│       GET http://prometheus:9090│
└─────────────┬───────────────────┘
              │ DNS lookup
              ▼
┌─────────────────────────────────┐
│ Kubernetes DNS (CoreDNS)        │
│ └─ Resolves: prometheus:9090    │
│    → 10.96.100.50:9090          │
└─────────────┬───────────────────┘
              │ HTTP GET
              ▼
┌─────────────────────────────────┐
│ Prometheus Service              │
│ └─ Responds with metrics        │
└─────────────┬───────────────────┘
              │ HTTP 200 OK
              ▼
┌─────────────────────────────────┐
│ Grafana UI                      │
│ └─ Datasource Status: ✅ OK    │
└─────────────────────────────────┘
```

### Operator Reconciliation Loop

```
┌─────────────────────────────────────────────────────────────────┐
│ GRAFANA OPERATOR RECONCILIATION LOOP (Self-Healing!)           │
└─────────────────────────────────────────────────────────────────┘

                  ┌──────────────────────────┐
                  │ Grafana Operator         │
                  │ (Continuous Loop)        │
                  └────────┬─────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────────┐
         │ Step 1: Watch Kubernetes API            │
         │ └─ Listen for CRD changes               │
         └─────────────┬───────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────────────────────┐
         │ Step 2: Compare Desired vs Actual       │
         │ ├─ Desired: CRD spec in Kubernetes      │
         │ └─ Actual: State in Grafana             │
         └─────────────┬───────────────────────────┘
                       │
                       ▼
                ┌──────────────┐
                │ Match?       │
                └──┬───────┬───┘
                   │       │
              YES  │       │ NO
                   │       │
                   ▼       ▼
         ┌─────────────┐  ┌────────────────────────┐
         │ Do Nothing  │  │ Reconcile!             │
         │ (Drift=0)   │  │ ├─ Dashboard missing?  │
         └─────────────┘  │ │  → Create it!        │
                          │ ├─ Config changed?     │
                          │ │  → Update it!        │
                          │ └─ Extra dashboard?    │
                          │    → Delete it!        │
                          └────────┬───────────────┘
                                   │
                                   ▼
                          ┌────────────────────────┐
                          │ Call Grafana API       │
                          │ ├─ POST /dashboards    │
                          │ ├─ PUT /dashboards/:id │
                          │ └─ DELETE /dashboards  │
                          └────────┬───────────────┘
                                   │
                                   ▼
                          ┌────────────────────────┐
                          │ Update CRD Status      │
                          │ └─ status: synced ✅   │
                          └────────────────────────┘
                                   │
                                   │ (Loop continues every 30s)
                                   └───────────────┐
                                                   │
                                                   ▼
                                   ┌───────────────────────────┐
                                   │ Wait 30 seconds...        │
                                   │ (Reconciliation interval) │
                                   └───────────┬───────────────┘
                                               │
                                               └──────────┐
                                                          │
                     (Back to Step 1) ◄───────────────────┘
```

**Key Points:**
- Operator runs continuously (infinite loop)
- Every 30 seconds: Compare Kubernetes CRD spec vs Grafana actual state
- If drift detected: Fix it automatically
- This is **Self-Healing**! If dashboard deleted manually → Operator recreates it!

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
│ ✅ Grafana Datasources (als GrafanaDatasource CRDs!)           │
│ ✅ Grafana Folders (als GrafanaFolder CRDs!)                   │
│ ✅ ConfigMaps (Grafana Config)                                 │
│ ✅ Secrets (Grafana Admin Password)                            │
│ ✅ Grafana PVC (SQLite database if used)                       │
│ ✅ ALLES in Kubernetes! 🚀                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Backup Strategy

#### Daily Backup (Automatisch via Velero Schedule)

```yaml
# velero-schedule-grafana-daily.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: grafana-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Jeden Tag um 2:00 AM
  template:
    includedNamespaces:
    - grafana
    includeClusterResources: true
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h  # Keep for 30 days
```

**Apply:**
```bash
kubectl apply -f velero-schedule-grafana-daily.yaml
```

**Was wird gebackuped:**
- Alle 68 Grafana Dashboards (as CRDs)
- Alle Datasources (Prometheus, Loki, Tempo, Alertmanager)
- Alle Folders
- ConfigMaps & Secrets
- Grafana Pod configuration

#### Manual Backup (On-Demand)

```bash
# Backup kompletter Grafana Stack
velero backup create grafana-stack-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces grafana \
  --include-cluster-resources \
  --storage-location default

# Backup nur Dashboards (schnell!)
velero backup create grafana-dashboards-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces grafana \
  --include-resources grafanadashboards

# Backup nur Datasources
velero backup create grafana-datasources-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces grafana \
  --include-resources grafanadatasources
```

### Restore Procedure

#### Disaster Recovery (Kompletter Grafana Restore)

**Scenario:** Grafana ist komplett weg! 💥

**IKEA-Style Recovery:**

```
SCHRITT 1: Check Backups
  velero backup get
  # Output: grafana-daily-20250120-020000

SCHRITT 2: Restore Grafana Stack
  velero restore create --from-backup grafana-daily-20250120-020000

SCHRITT 3: Wait for Restore
  kubectl get pods -n grafana --watch
  # Warte bis alle Pods Running

SCHRITT 4: Check Grafana Operator
  kubectl logs -n grafana deployment/grafana-operator-controller-manager
  # → Operator reconciles all CRDs

SCHRITT 5: Check Grafana UI
  kubectl port-forward -n grafana svc/grafana 3000:3000
  http://localhost:3000
  # → Alle 68 Dashboards sind wieder da! 🎉

SCHRITT 6: Verify Datasources
  http://localhost:3000/datasources
  # → Prometheus, Loki, Tempo, Alertmanager: All Green! ✅
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
│    └─ Speichert CRDs in Ceph S3                               │
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
│  ├─ datasources/
│  │  ├─ prometheus.yaml
│  │  ├─ loki.yaml
│  │  ├─ tempo.yaml
│  │  └─ alertmanager.yaml
│  └─ enterprise-dashboards/
│     ├─ argocd/
│     │  ├─ argocd-gitops.yaml
│     │  └─ ... (68 dashboards)
│     └─ ...
```

**Restore from Git:**
```bash
# Clone repo
git clone https://github.com/Tim275/talos-homelab.git

# Apply all Grafana YAMLs
kubectl apply -k kubernetes/infrastructure/monitoring/grafana/

# Fertig! Alles wieder da! 🎉
```

---

## Quick Reference - Grafana Commands

### Essential Commands

```bash
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

# Check Grafana Operator logs
kubectl logs -n grafana deployment/grafana-operator-controller-manager

# List all Datasources
kubectl get grafanadatasources -n grafana

# List all Folders
kubectl get grafanafolders -n grafana

# Check Grafana Pod logs
kubectl logs -n grafana deployment/grafana

# Restart Grafana (if needed)
kubectl rollout restart -n grafana deployment/grafana

# ══════════════════════════════════════════════════════════════
# DASHBOARD MANAGEMENT
# ══════════════════════════════════════════════════════════════

# Create new dashboard from YAML
kubectl apply -f dashboard.yaml

# Update existing dashboard
kubectl apply -f dashboard.yaml

# Delete dashboard
kubectl delete -f dashboard.yaml

# Export dashboard (for backup)
kubectl get grafanadashboard -n grafana my-dashboard -o yaml > backup.yaml

# Import dashboard from JSON (convert to CRD first)
cat dashboard.json | jq -Rs '{apiVersion: "grafana.integreatly.org/v1beta1", kind: "GrafanaDashboard", metadata: {name: "my-dash", namespace: "grafana"}, spec: {json: .}}' | kubectl apply -f -

# ══════════════════════════════════════════════════════════════
# TROUBLESHOOTING
# ══════════════════════════════════════════════════════════════

# Check Grafana Operator status
kubectl get pods -n grafana
kubectl describe pod -n grafana <grafana-operator-pod>

# Check if Grafana instance is created
kubectl get grafana -n grafana

# Check dashboard sync status
kubectl get grafanadashboards -n grafana -o wide

# Check datasource connection
kubectl exec -n grafana deployment/grafana -- \
  curl -s http://localhost:3000/api/datasources | jq

# Test Prometheus datasource
kubectl exec -n grafana deployment/grafana -- \
  curl -s "http://prometheus-operated.monitoring.svc:9090/api/v1/query?query=up"

# ══════════════════════════════════════════════════════════════
# BACKUP & RESTORE
# ══════════════════════════════════════════════════════════════

# Backup all Grafana resources to Git
kubectl get grafanadashboards -n grafana -o yaml > dashboards-backup.yaml
kubectl get grafanadatasources -n grafana -o yaml > datasources-backup.yaml

# Restore from backup
kubectl apply -f dashboards-backup.yaml
kubectl apply -f datasources-backup.yaml

# Velero backup
velero backup create grafana-backup --include-namespaces grafana
```

---

## Summary

### What We Built

```
✅ Grafana Operator (Kubernetes-native)
✅ 68 Dashboards (as CRDs, Git-backed)
✅ 4 Datasources (Prometheus, Loki, Tempo, Alertmanager)
✅ 15 Folders (organized by domain)
✅ GitOps-Ready (ArgoCD synced)
✅ Self-Healing (CRD reconciliation)
✅ Backup via Velero + Git
```

### Key Benefits

| Feature | Benefit |
|---------|---------|
| **CRDs** | Git-based, Type-safe, Self-healing |
| **Operator** | Auto-sync, Reconciliation loop |
| **GitOps** | Everything in Git, ArgoCD synced |
| **Backup** | Velero + Git (double protection) |
| **Validation** | Kubernetes API schema validation |
| **Versioning** | Git history for all changes |

### Files Reference

```
kubernetes/infrastructure/monitoring/
├─ GRAFANA-SETUP-GUIDE.md                ← YOU ARE HERE
├─ OBSERVABILITY-STACK-GUIDE.md          ← Prometheus/Loki/Tempo guide
├─ grafana/
│  ├─ kustomization.yaml                  ← 68 dashboards
│  ├─ grafana.yaml                        ← Grafana instance CRD
│  ├─ datasources/                        ← All datasources
│  └─ enterprise-dashboards/              ← All 68 dashboards
└─ servicemonitors/
   └─ ... (all ServiceMonitors)
```

---

**Created for:** Talos Homelab Production
**Last Updated:** 2025-10-31
**Grafana Operator:** v5.19.1
**Total Dashboards:** 68
**Datasources:** 4 (Prometheus, Loki, Tempo, Alertmanager)
