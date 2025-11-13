# 📊 Dashboards as Code - Implementation Guide

**How we manage 80+ Grafana Dashboards as Infrastructure as Code**

---

## 🎯 **Architecture Overview**

```yaml
Stack:
  ├─ Grafana Operator (v5.19.1)
  │  └─ Manages Grafana instance lifecycle
  ├─ GrafanaDashboard CRD (grafana.integreatly.org/v1beta1)
  │  └─ Dashboard definitions as YAML
  ├─ GrafanaDataSource CRD
  │  └─ Datasources (Prometheus, Loki, Alertmanager)
  └─ ArgoCD
     └─ GitOps sync from Git → Kubernetes

Benefits:
  ✅ Version control (Git history)
  ✅ Code review (Pull Requests)
  ✅ Automated deployment (ArgoCD)
  ✅ Declarative (desired state)
  ✅ No manual imports!
```

---

## 📝 **How It Works**

### 1. **GrafanaDashboard CRD Pattern**

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: argocd-overview-v3
  namespace: grafana
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/component: dashboard
    dashboard-tier: argocd
spec:
  # 🎯 Which Grafana instance to deploy to
  instanceSelector:
    matchLabels:
      app: grafana

  # 📁 Dashboard folder in Grafana UI
  folder: "ArgoCD"

  # 🔄 Allow cross-namespace import (dashboards → grafana instance)
  allowCrossNamespaceImport: true

  # 📊 Dashboard JSON (embedded)
  json: |
    {
      "dashboard": {
        "title": "ArgoCD Overview",
        "panels": [...]
      }
    }
```

**Key Concepts:**

- **instanceSelector**: Matches Grafana CR with label `app: grafana`
- **folder**: Organizes dashboards in Grafana UI (not filesystem!)
- **json**: Full Grafana dashboard JSON embedded in YAML
- **allowCrossNamespaceImport**: Dashboard in any namespace can target Grafana in `grafana` namespace

### 2. **Datasource Pattern**

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: prometheus-operated
  namespace: grafana
spec:
  instanceSelector:
    matchLabels:
      app: grafana
  datasource:
    name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus-operator-kube-p-prometheus.monitoring:9090
    isDefault: true
    jsonData:
      timeInterval: 30s
```

---

## 📂 **Directory Structure**

```
kubernetes/infrastructure/monitoring/grafana/
├── kustomization.yaml                    # Main kustomize file (80+ dashboard references)
├── grafana.yaml                          # Grafana CR (instance config)
├── http-route.yaml                       # HTTPRoute (Envoy Gateway)
├── datasources/
│   ├── prometheus-operated.yaml          # ✅ Main Prometheus datasource
│   ├── loki.yaml                         # ✅ Loki logs datasource
│   └── alertmanager-operated.yaml        # ✅ Alertmanager datasource
└── enterprise-dashboards/
    ├── tier0-executive/
    │   ├── k8s-global-view.yaml          # Executive overview
    │   └── node-system-overview.yaml     # Node-level metrics
    ├── argocd/
    │   ├── official-argocd-overview-v3.yaml      # ID: 24192 ✅
    │   ├── official-argocd-operational.yaml      # ID: 19993
    │   └── official-argocd-application.yaml      # ID: 19974
    ├── postgresql/
    │   ├── postgresql-cnpg.yaml          # Custom CNPG dashboard
    │   └── official-cloudnativepg.yaml   # ID: 20417 ✅
    ├── kafka/
    │   ├── kafka-strimzi.yaml            # Custom Strimzi dashboard
    │   ├── official-kafka-exporter.yaml  # ID: 7589
    │   └── official-kafka-cluster.yaml   # ID: 14505
    ├── ceph/
    │   ├── official-ceph-cluster.yaml    # ID: 2842 ✅
    │   ├── official-ceph-pools.yaml      # ID: 5342
    │   └── official-ceph-osd.yaml        # ID: 5336
    ├── opentelemetry/
    │   ├── official-opentelemetry-collector.yaml # ID: 15983
    │   └── official-opentelemetry-apm.yaml       # ID: 19419
    └── ...80+ more dashboards
```

---

## 🔧 **ServiceMonitor vs PodMonitor**

### **When to use what?**

```yaml
ServiceMonitor (Most Common):
  ├─ Scrapes metrics via Kubernetes Service
  ├─ Use when: Service exposes metrics endpoint
  ├─ Example: Kafka Exporter, Jaeger, ArgoCD
  └─ Pattern: Service → ServiceMonitor → Prometheus

PodMonitor (Special Cases):
  ├─ Scrapes metrics directly from Pods (bypasses Service)
  ├─ Use when: Pods expose metrics but no dedicated Service
  ├─ Example: CNPG PostgreSQL clusters
  └─ Pattern: Pod → PodMonitor → Prometheus
```

### **ServiceMonitor Example (Kafka)**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-exporter
  namespace: monitoring
  labels:
    release: kube-prometheus-stack  # ✅ Prometheus Operator selector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kafka-exporter
  namespaceSelector:
    matchNames:
      - kafka
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

**How it works:**
1. ServiceMonitor matches Service with label `app.kubernetes.io/name: kafka-exporter`
2. Prometheus Operator generates Prometheus scrape config
3. Prometheus scrapes `http://kafka-exporter.kafka:9308/metrics` every 30s

### **PodMonitor Example (CNPG PostgreSQL)**

```yaml
# ⚠️ PodMonitor is auto-created by CNPG Operator!
# Enable via Cluster CR:

apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: n8n-postgres
  namespace: n8n-prod
spec:
  instances: 2

  # 📊 THIS CREATES PodMonitor AUTOMATICALLY!
  monitoring:
    enablePodMonitor: true                    # ✅ Enable metrics scraping
    customQueriesConfigMap:
      - name: cnpg-default-monitoring         # ✅ Custom queries (lag, connections, etc.)
        key: queries
    disableDefaultQueries: false              # ✅ Keep default metrics
```

**Result:**
- CNPG Operator creates PodMonitor: `n8n-postgres` in `n8n-prod` namespace
- Prometheus scrapes Pod on port `9187` (CNPG metrics port)
- Metrics: `cnpg_pg_database_size_bytes`, `cnpg_pg_replication_lag_seconds`, etc.

---

## ✅ **What We Just Fixed: PostgreSQL Monitoring**

### **Problem**

```yaml
Before:
  ├─ CNPG Dashboard deployed ✅
  ├─ CNPG Pods running ✅
  ├─ Metrics exposed on port 9187 ✅
  └─ BUT: enablePodMonitor: false ❌
     Result: Prometheus NOT scraping → Dashboard EMPTY!
```

### **Solution**

**Files Modified:**
1. `/platform/data/n8n-prod-cnpg/cluster.yaml`
2. `/platform/data/n8n-dev-cnpg/postgres-cluster.yaml`
3. `/platform/identity/keycloak/postgres-cluster.yaml`
4. `/platform/identity/infisical/postgres-cluster.yaml`

**Changes:**
```yaml
spec:
  monitoring:
    enablePodMonitor: true                    # ✅ Enable PodMonitor creation
    customQueriesConfigMap:
      - name: cnpg-default-monitoring
        key: queries
    disableDefaultQueries: false
```

**Result:**
```bash
$ kubectl get podmonitor -A | grep postgres
infisical    infisical-postgres   4d19h
n8n-dev      n8n-postgres         5m
n8n-prod     n8n-postgres         5m
keycloak     keycloak-db          13d

$ kubectl exec -n monitoring prometheus-0 -- \
    wget -qO- 'http://localhost:9090/api/v1/query?query=cnpg_pg_database_size_bytes'
# 28 time series found! ✅
```

---

## 📊 **Dashboard Status - What Works Now**

### ✅ **Working Dashboards (Metrics Flowing)**

```yaml
ArgoCD:
  ├─ ArgoCD Overview V3 (24192)              # ✅ 6 ServiceMonitors
  ├─ ArgoCD Operational (19993)              # ✅ Application metrics
  ├─ ArgoCD Application (19974)              # ✅ Sync status
  └─ ArgoCD Notifications (19975)            # ✅ Notification metrics

PostgreSQL (CNPG):
  ├─ CloudNativePG Official (20417)          # ✅ 4 PodMonitors (JUST FIXED!)
  └─ Custom CNPG Dashboard                   # ✅ Replication lag, connections

Kafka (Strimzi):
  ├─ Kafka Exporter (7589)                   # ✅ 3 ServiceMonitors
  ├─ Kafka Cluster (14505)                   # ✅ Broker metrics
  └─ Kafka Topics (14506)                    # ✅ Topic metrics

Ceph Storage:
  ├─ Ceph Cluster (2842)                     # ✅ Rook-Ceph metrics
  ├─ Ceph Pools (5342)                       # ✅ Pool capacity
  └─ Ceph OSD (5336)                         # ✅ OSD health

OpenTelemetry:
  ├─ OTel Collector (15983)                  # ✅ Traces, metrics, logs
  └─ OTel APM (19419)                        # ✅ Application performance

Kubernetes:
  ├─ Global View (15757)                     # ✅ Cluster overview
  ├─ API Server (15761)                      # ✅ API latency
  ├─ etcd (20330)                            # ✅ Control plane health
  └─ 10+ more K8s dashboards                 # ✅ All working

Istio Service Mesh:
  ├─ Istio Mesh (7639)                       # ✅ Service graph
  ├─ Istio Service (7636)                    # ✅ Request rate
  └─ Istio Control Plane (7645)              # ✅ istiod health

Total: 80+ Dashboards deployed as IaC ✅
```

---

## 🚀 **How to Add New Dashboard**

### **Method 1: From Grafana.com (Recommended)**

1. **Find dashboard on grafana.com**
   ```bash
   # Example: https://grafana.com/grafana/dashboards/24192
   Dashboard ID: 24192
   Name: ArgoCD Overview V3
   ```

2. **Download JSON**
   ```bash
   curl -o argocd-overview.json \
     https://grafana.com/api/dashboards/24192/revisions/1/download
   ```

3. **Create GrafanaDashboard YAML**
   ```bash
   cat > official-argocd-overview-v3.yaml <<EOF
   apiVersion: grafana.integreatly.org/v1beta1
   kind: GrafanaDashboard
   metadata:
     name: official-argocd-overview-v3
     namespace: grafana
     labels:
       app.kubernetes.io/name: grafana
       app.kubernetes.io/component: dashboard
       dashboard-tier: argocd
   spec:
     allowCrossNamespaceImport: true
     folder: "ArgoCD"
     instanceSelector:
       matchLabels:
         app: grafana
     json: |
       $(cat argocd-overview.json | sed 's/^/      /')
   EOF
   ```

4. **Add to kustomization.yaml**
   ```yaml
   resources:
     - enterprise-dashboards/argocd/official-argocd-overview-v3.yaml
   ```

5. **Commit + Push**
   ```bash
   git add .
   git commit -m "feat: add ArgoCD Overview V3 dashboard (ID: 24192)"
   git push
   ```

6. **ArgoCD auto-syncs** (or manual: `kubectl patch application grafana -n argocd --type merge -p '{"operation":{"sync":{}}}'`)

### **Method 2: Custom Dashboard**

1. **Create in Grafana UI** (http://grafana.timourhomelab.org)
2. **Export JSON** (Share → Export → Save to file)
3. **Convert to YAML** (same as Method 1, step 3)
4. **Commit to Git**

---

## 🔍 **Troubleshooting**

### **Dashboard not appearing in Grafana?**

```bash
# 1. Check if GrafanaDashboard CR exists
kubectl get grafanadashboard -n grafana | grep argocd

# 2. Check status
kubectl describe grafanadashboard official-argocd-overview-v3 -n grafana

# 3. Check if instance selector matches
kubectl get grafana grafana -n grafana -o jsonpath='{.metadata.labels}'
# Should have: "app":"grafana"

# 4. Check Grafana Operator logs
kubectl logs -n grafana -l app.kubernetes.io/name=grafana-operator
```

### **Dashboard shows "No Data"?**

```bash
# 1. Check if ServiceMonitor/PodMonitor exists
kubectl get servicemonitor,podmonitor -A | grep <component>

# 2. Check if metrics are in Prometheus
kubectl port-forward -n monitoring prometheus-kube-prometheus-stack-prometheus-0 9090
# Open: http://localhost:9090/targets
# Search for your component

# 3. Check metric names in Prometheus
# Example: cnpg_pg_database_size_bytes

# 4. Check datasource in Grafana
# Settings → Data Sources → Prometheus
# Test & Save
```

### **PodMonitor not created (CNPG)?**

```bash
# 1. Check if monitoring is enabled in Cluster CR
kubectl get cluster.postgresql.cnpg.io <name> -n <namespace> -o yaml | grep -A 5 monitoring

# Expected:
#   monitoring:
#     enablePodMonitor: true

# 2. If missing, add to Cluster YAML and sync ArgoCD

# 3. Verify PodMonitor created
kubectl get podmonitor -n <namespace>

# 4. Check CNPG Operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

---

## 📚 **Best Practices**

### ✅ **DO**

- **Organize by component** (`argocd/`, `postgresql/`, `kafka/`)
- **Prefix with `official-`** for Grafana.com dashboards
- **Use descriptive names** (`official-argocd-overview-v3.yaml`)
- **Add dashboard ID in comment** (`# ID: 24192`)
- **Set proper folder** (`folder: "ArgoCD"`)
- **Version control everything** (Git history = audit trail)
- **Test in dev first** (deploy to dev Grafana instance first)

### ❌ **DON'T**

- **Manual imports** (use GrafanaDashboard CRD instead!)
- **Duplicate dashboards** (check if already exists)
- **Hardcode datasource UIDs** (use `${DS_PROMETHEUS}` variables)
- **Skip instance selector** (dashboard won't deploy!)
- **Forget allowCrossNamespaceImport** (if dashboard in different namespace)

---

## 🎯 **Summary: What We Built**

```yaml
Infrastructure as Code:
  ├─ 80+ Grafana Dashboards (GrafanaDashboard CRDs)
  ├─ 3 Datasources (Prometheus, Loki, Alertmanager)
  ├─ 50+ ServiceMonitors (Kafka, ArgoCD, Jaeger, etc.)
  ├─ 4 PodMonitors (CNPG PostgreSQL clusters)
  └─ GitOps deployment (ArgoCD)

Benefits:
  ✅ Zero manual dashboard imports
  ✅ Version control (every change tracked)
  ✅ Code review (PR approval required)
  ✅ Automated deployment (push = deploy)
  ✅ Disaster recovery (Git = source of truth)
  ✅ Multi-environment (dev/prod from same repo)

Result:
  🎉 Enterprise-grade Dashboard Management!
```

---

## 📖 **Related Documentation**

- [MONITORING_BEST_PRACTICES.md](./MONITORING_BEST_PRACTICES.md) - Industry best practices from Grafana blog
- [TRACING_STORAGE_RESEARCH.md](./TRACING_STORAGE_RESEARCH.md) - Jaeger vs Tempo comparison
- [PRODUCTION_OBSERVABILITY_STACK.md](./PRODUCTION_OBSERVABILITY_STACK.md) - Full stack overview

---

**Last Updated**: 2025-10-23
**Status**: Production-Ready ✅
