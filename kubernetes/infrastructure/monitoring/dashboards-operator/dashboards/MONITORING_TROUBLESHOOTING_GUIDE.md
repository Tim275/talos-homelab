# 🚨 ENTERPRISE MONITORING TROUBLESHOOTING GUIDE

## ❌ HÄUFIGE "DATASOURCE NOT FOUND" / "NO DATA" PROBLEME

### 🔧 PROBLEM 1: Datasource Name Mismatch
**Fehler**: `Datasource prometheus not found` oder `DS_PROMETHEUS not found`

**✅ LÖSUNG**:
```bash
# 1. Check Grafana Datasource Namen
kubectl get grafanadatasource -n grafana -o json | jq '.items[].spec.datasource.name'

# 2. Fix Dashboard Datasource Mapping
# In GrafanaDashboard YAML:
datasources:
  - inputName: "DS_PROMETHEUS"
    datasourceName: "Prometheus"  # ⚠️ WICHTIG: Exakt wie in Grafana definiert
```

### 🔧 PROBLEM 2: ServiceMonitor im falschen Namespace
**Fehler**: Metrics kommen nicht an, obwohl Service läuft

**✅ LÖSUNG**:
```bash
# 1. ServiceMonitor MUSS im 'monitoring' Namespace sein
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-service-monitor
  namespace: monitoring  # ⚠️ KRITISCH: monitoring namespace!
  labels:
    release: prometheus-operator  # ⚠️ KRITISCH: für kube-prometheus-stack
```

### 🔧 PROBLEM 3: Service ohne Metrics Port
**Fehler**: ServiceMonitor findet keinen metrics port

**✅ LÖSUNG**:
```bash
# 1. Check ob Service metrics port hat
kubectl get service <service-name> -n <namespace> -o yaml

# 2. Wenn kein metrics port → Service erstellen:
apiVersion: v1
kind: Service
metadata:
  name: my-service-metrics
  namespace: <target-namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/component: metrics
spec:
  ports:
  - name: metrics
    port: 8080        # ⚠️ Muss mit Pod containerPort übereinstimmen
    targetPort: 8080
  selector:
    app.kubernetes.io/name: <app-name>
```

### 🔧 PROBLEM 4: Falsche ServiceMonitor Selectors
**Fehler**: ServiceMonitor findet Service nicht

**✅ LÖSUNG**:
```bash
# 1. Check Service Labels
kubectl get service <service-name> -n <namespace> --show-labels

# 2. ServiceMonitor selector anpassen:
spec:
  namespaceSelector:
    matchNames:
    - <target-namespace>
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>  # ⚠️ MUSS mit Service Labels übereinstimmen
```

### 🔧 PROBLEM 5: Falscher Metrics Path/Port
**Fehler**: Target ist "down" in Prometheus

**✅ LÖSUNG**:
```bash
# 1. Test metrics endpoint direkt:
kubectl port-forward -n <namespace> service/<service-name> 8080:8080
curl http://localhost:8080/metrics

# 2. ServiceMonitor path/port korrigieren:
spec:
  endpoints:
  - port: metrics          # ⚠️ Name vom Service port
    interval: 30s
    path: /metrics         # ⚠️ Korrekter path (nicht /stats/prometheus)
    scheme: http           # ⚠️ http oder https je nach Service
```

## 🛠️ STEP-BY-STEP DEBUGGING PROZESS

### 1️⃣ PROMETHEUS TARGETS CHECKEN
```bash
kubectl port-forward -n monitoring service/kube-prometheus-stack-prometheus 9090:9090
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health == "down")'
```

### 2️⃣ GRAFANA DATASOURCES VERIFIZIEREN
```bash
kubectl get grafanadatasource -n grafana -o yaml
# Check name, url, isDefault fields
```

### 3️⃣ SERVICEMONITOR LABELS & SELECTORS PRÜFEN
```bash
kubectl get servicemonitor -A
kubectl describe servicemonitor <name> -n monitoring
```

### 4️⃣ SERVICE PORTS & LABELS CHECKEN
```bash
kubectl get service <service> -n <namespace> -o yaml
# Check ports.name, labels, selector
```

### 5️⃣ POD METRICS ENDPOINT TESTEN
```bash
kubectl port-forward -n <namespace> pod/<pod-name> 8080:8080
curl http://localhost:8080/metrics | head -10
```

## 🏗️ ENTERPRISE SERVICEMONITOR TEMPLATE

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.serviceName }}-metrics
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.appName }}
    app.kubernetes.io/component: metrics
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "{{ .Values.metricsPort }}"
    prometheus.io/path: "/metrics"
spec:
  ports:
  - name: metrics
    port: {{ .Values.metricsPort }}
    targetPort: {{ .Values.metricsPort }}
    protocol: TCP
  selector:
    app.kubernetes.io/name: {{ .Values.appName }}
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Values.serviceName }}-metrics
  namespace: monitoring  # ⚠️ IMMER monitoring namespace
  labels:
    app.kubernetes.io/name: {{ .Values.appName }}
    app.kubernetes.io/component: metrics
    release: prometheus-operator  # ⚠️ KRITISCH für kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
    - {{ .Values.namespace }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.appName }}
      app.kubernetes.io/component: metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
    # Optional für HTTPS:
    # tlsConfig:
    #   insecureSkipVerify: true
```

## 🎯 ENTERPRISE DASHBOARD TEMPLATE

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: {{ .Values.dashboardName }}
  labels:
    app: grafana
    tier: {{ .Values.tier }}  # infrastructure/platform/application
    component: {{ .Values.component }}
spec:
  instanceSelector:
    matchLabels:
      app: grafana  # ⚠️ MUSS mit Grafana CR label übereinstimmen
  folder: "{{ .Values.folderName }}"
  grafanaCom:
    id: {{ .Values.grafanaComId }}
    revision: {{ .Values.revision }}
  datasources:
    - inputName: "DS_PROMETHEUS"
      datasourceName: "Prometheus"  # ⚠️ EXAKT wie GrafanaDatasource.spec.datasource.name
```

## 🚨 TROUBLESHOOTING CHECKLISTE

- [ ] ServiceMonitor im `monitoring` namespace?
- [ ] ServiceMonitor hat `release: prometheus-operator` label?
- [ ] Service hat korrekten metrics port mit name `metrics`?
- [ ] ServiceMonitor selector matched Service labels?
- [ ] Metrics endpoint auf `/metrics` erreichbar?
- [ ] GrafanaDashboard datasourceName = GrafanaDatasource name?
- [ ] Prometheus target ist "up" status?
- [ ] Pod exportiert metrics auf konfiguriertem port?

## 🔍 DEBUGGING COMMANDS

```bash
# Prometheus Targets Status
kubectl port-forward -n monitoring service/kube-prometheus-stack-prometheus 9090:9090 &
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health != "up")'

# Grafana Datasources
kubectl get grafanadatasource -n grafana -o jsonpath='{.items[*].spec.datasource.name}'

# ServiceMonitor Discovery
kubectl get servicemonitor -A --show-labels

# Service & Pod Metrics Test
kubectl get pods -A -o wide | grep <app-name>
kubectl port-forward -n <namespace> service/<service> <port>:<port>
curl http://localhost:<port>/metrics
```

## 🎯 ERFOLGREICH IMPLEMENTIERTE LÖSUNGEN (ENTERPRISE DASHBOARD REFACTOR)

### ✅ ARCHITEKTUR TRANSFORMATION (2025-09-29)

**VON**: Abstract tier-based Structure → **ZU**: Application-based Structure
**ERGEBNIS**: 🚀 Enterprise-grade monitoring mit yamllint compliance

#### 📂 **NEUE STRUKTUR:**
```
infrastructure/monitoring/dashboards-operator/
├── servicemonitors/           # ✅ Cross-namespace ServiceMonitors
│   ├── kafka-exporter.yaml   # ✅ Kafka metrics - monitoring/→kafka
│   ├── cnpg-controller.yaml  # ✅ CloudNativePG HTTP scheme fix
│   └── sail-operator.yaml    # ✅ Sail Operator HTTPS mit TLS config
└── dashboards/               # ✅ Application-based GrafanaDashboards
    ├── n8n/                 # 🔧 N8N workflow automation (dev/prod)
    ├── audiobookshelf/      # 🎧 Media server dashboards (dev/prod)
    ├── elasticsearch/       # 🔍 Logging stack (ES/Kibana/Fluentd/Vector)
    ├── istio/              # 🌊 Service mesh (Sail/Control/Traffic)
    ├── ceph/               # 💾 Storage cluster (Rook/Pools/OSD/CNPG)
    ├── argocd/             # 🚀 GitOps platform (Overview/Performance/Rollouts)
    └── kubernetes/         # ☸️ Infrastructure (Cluster/Node Exporter)
```

#### 🔧 **GELÖSTE SERVICEMONITOR PROBLEME:**

**1. Kafka-Exporter ServiceMonitor:**
```yaml
# ❌ VORHER: servicemonitor in grafana namespace → keine discovery
# ✅ NACHHER: servicemonitor in monitoring namespace mit cross-namespace selector
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-exporter-fixed
  namespace: monitoring  # ⚠️ KRITISCH: monitoring namespace!
  labels:
    release: prometheus-operator  # ⚠️ KRITISCH: für kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - kafka  # Cross-namespace: monitoring → kafka
  selector:
    matchLabels:
      app.kubernetes.io/name: kafka-exporter
      strimzi.io/kind: KafkaExporter
```

**2. CloudNativePG ServiceMonitor:**
```yaml
# ❌ VORHER: scheme: https → "server gave HTTP response to HTTPS client"
# ✅ NACHHER: scheme: http nach direktem endpoint test
endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http  # ✅ FIX: HTTP statt HTTPS
```

**3. Sail Operator ServiceMonitor:**
```yaml
# ❌ VORHER: Kein ServiceMonitor für Istio Sail Operator
# ✅ NACHHER: HTTPS ServiceMonitor mit TLS config
endpoints:
  - port: https-metrics
    interval: 30s
    path: /metrics
    scheme: https
    scrapeTimeout: 10s
    tlsConfig:
      insecureSkipVerify: true  # ✅ Für self-signed certs
```

#### 🏗️ **ENTERPRISE BENEFITS:**

✅ **Developer-Friendly**: Find dashboards by application (n8n/, ceph/, etc.)
✅ **Cross-Namespace Discovery**: ServiceMonitors in monitoring namespace
✅ **yamllint Compliance**: Single-document YAML files enterprise-grade
✅ **Centralized Deployment**: Single infrastructure-dashboards-operator app
✅ **Netflix/Google Pattern**: Application-based statt abstract tiers
✅ **Sail Operator Included**: Komplette Istio service mesh monitoring

#### 💡 **KEY LEARNINGS:**

- **ServiceMonitors MÜSSEN in monitoring namespace** für kube-prometheus-stack discovery
- **Cross-namespace funktioniert** via namespaceSelector.matchNames
- **HTTP/HTTPS scheme testing** ist kritisch vor ServiceMonitor deployment
- **Application-based structure** ist praktischer als tier-based abstractions
- **yamllint compliance** ist enterprise standard (single-document files)

#### 🚀 **DEPLOYMENT STATUS:**
- ✅ **Git committed & pushed**: Enterprise dashboard refactor deployed
- ✅ **ArgoCD sync**: infrastructure-dashboards-operator wird deployed
- ✅ **ServiceMonitors**: Kafka, CNPG, Sail Operator cross-namespace ready
- ✅ **GrafanaDashboards**: 20+ enterprise applications organiziert
