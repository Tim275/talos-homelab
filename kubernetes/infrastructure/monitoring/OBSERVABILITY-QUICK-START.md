# Observability Quick-Start Guide

## 🎯 TL;DR - In 5 Minuten produktiv!

**Dieses Guide:** Schneller Einstieg in dein Observability Stack
**Für Deep Dive:** Siehe [OBSERVABILITY-MASTER-GUIDE.md](./OBSERVABILITY-MASTER-GUIDE.md)

---

## 📋 Was hast du?

```
✅ Grafana    → 68 Dashboards (http://localhost:3000)
✅ Prometheus → Metrics sammeln (http://localhost:9090)
✅ Loki       → Log aggregation
✅ Thanos     → Unlimited metrics storage (S3)
✅ Velero     → Backup everything
```

---

## 🚀 Quick Actions

### 1. Grafana öffnen (Dashboards ansehen)

```bash
# Port-forward
kubectl port-forward -n grafana svc/grafana 3000:3000

# Browser: http://localhost:3000
# Username: admin
# Password:
kubectl get secret -n grafana grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
```

**Dashboards finden:**
- Click "Dashboards" (linke Sidebar)
- Ordner: `ArgoCD`, `Kafka`, `Kubernetes`, etc.

---

### 2. Prometheus öffnen (Metrics ansehen)

```bash
# Port-forward
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Browser: http://localhost:9090
```

**Targets checken:**
- Click "Status" → "Targets"
- ✅ Green = Metrics werden gescraped
- ❌ Red = Problem (siehe Troubleshooting)

---

### 3. Neue App Metrics scrapen (3 Minuten!)

**Schritt 1: Service braucht Port-Name**

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    app: my-app  # ← WICHTIG für ServiceMonitor!
spec:
  selector:
    app: my-app
  ports:
  - name: http   # ← WICHTIG! Port braucht einen Namen!
    port: 8080
    targetPort: 8080
```

**Schritt 2: ServiceMonitor erstellen**

```yaml
# servicemonitor-my-app.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring  # ← IMMER "monitoring"!
spec:
  namespaceSelector:
    matchNames:
    - my-app-namespace  # ← Namespace deiner App
  selector:
    matchLabels:
      app: my-app       # ← Muss mit Service Label übereinstimmen!
  endpoints:
  - port: http          # ← Port-Name aus Service
    path: /metrics      # ← Standard Prometheus endpoint
    interval: 30s
```

**Schritt 3: Apply + Check**

```bash
# Apply ServiceMonitor
kubectl apply -f servicemonitor-my-app.yaml

# Check Prometheus Target (30 Sekunden warten)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# → http://localhost:9090/targets
# → Suche nach "my-app" → State: UP ✅
```

**Fertig!** Prometheus scraped jetzt deine App! 🎉

---

### 4. Dashboard hinzufügen (von Grafana.com)

**Option A: Via UI (schnell, aber nicht GitOps)**

1. Grafana öffnen (http://localhost:3000)
2. Click "+" → "Import"
3. Dashboard ID eingeben (z.B. `15760` für Kubernetes Pods)
4. Click "Load" → Select Datasource "Prometheus"
5. Click "Import"

**Option B: Via CRD (GitOps, empfohlen!)**

```bash
# Dashboard von grafana.com downloaden
curl -s https://grafana.com/api/dashboards/15760/revisions/latest/download \
  -o /tmp/dashboard.json

# JSON komprimieren
DASHBOARD_JSON=$(cat /tmp/dashboard.json | jq -c .)

# GrafanaDashboard CRD erstellen
cat > kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/custom/my-dashboard.yaml << EOF
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: my-dashboard
  namespace: grafana
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/component: dashboard
spec:
  allowCrossNamespaceImport: true
  folder: "Custom"
  instanceSelector:
    matchLabels:
      app: grafana
  json: |
    ${DASHBOARD_JSON}
EOF

# Apply
kubectl apply -f kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/custom/my-dashboard.yaml

# Git commit (für GitOps)
git add kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/custom/my-dashboard.yaml
git commit -m "feat: add custom dashboard"
git push
```

---

### 5. Logs ansehen (Loki)

```bash
# Option 1: In Grafana (Explore)
# 1. Grafana öffnen (http://localhost:3000)
# 2. Click "Explore" (Kompass-Icon links)
# 3. Select Datasource: "Loki"
# 4. Query: {namespace="n8n-prod"}
# 5. Run Query ✅

# Option 2: Via CLI
kubectl port-forward -n monitoring svc/loki 3100:3100

# Query Loki
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="n8n-prod"}' | jq .
```

---

### 6. Backup erstellen

```bash
# Kompletter Monitoring Stack Backup
velero backup create monitoring-backup-$(date +%Y%m%d) \
  --include-namespaces monitoring,grafana

# Nur Grafana Dashboards
velero backup create dashboards-backup \
  --include-namespaces grafana \
  --include-resources grafanadashboards

# Backup Status
velero backup get
```

---

## 🔧 Troubleshooting (Schnell-Fixes)

### Problem: "No Data" in Dashboard

**IKEA-Checklist (in Reihenfolge abarbeiten):**

```
☐ 1. App hat /metrics endpoint?
     → curl http://my-app:8080/metrics
     → Sollte Prometheus-Format zeigen

☐ 2. Service hat Port-Name?
     → kubectl get svc my-app -o yaml | grep "name:"

☐ 3. ServiceMonitor in namespace "monitoring"?
     → kubectl get servicemonitor -n monitoring

☐ 4. ServiceMonitor Labels = Service Labels?
     → kubectl get svc my-app -o yaml | grep "labels:" -A 5

☐ 5. Prometheus Target UP?
     → http://localhost:9090/targets
     → Suche nach deiner App

☐ 6. Metrics in Prometheus?
     → http://localhost:9090/graph
     → Query: {namespace="my-app-namespace"}

☐ 7. PromQL Query korrekt?
     → Test Query erst in Prometheus UI
```

**Häufigste Fehler:**
```
❌ ServiceMonitor im falschen Namespace (muss in "monitoring" sein!)
❌ Service Labels ≠ ServiceMonitor selector.matchLabels
❌ Port-Name im Service fehlt
❌ /metrics endpoint gibt 404
```

---

### Problem: Prometheus Target DOWN

```bash
# Check Prometheus Logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus

# Häufige Ursachen:
# 1. Service existiert nicht
kubectl get svc my-app -n my-app-namespace

# 2. Service Port falsch
kubectl get svc my-app -n my-app-namespace -o yaml

# 3. Network Policy blockiert
kubectl get networkpolicies -n my-app-namespace
```

---

### Problem: Grafana Dashboard nicht sichtbar

```bash
# Check GrafanaDashboard CRD
kubectl get grafanadashboards -n grafana

# Check Grafana Operator Logs
kubectl logs -n grafana-operator deployment/grafana-operator

# Force Re-Sync
kubectl delete pod -n grafana -l app=grafana
```

---

## 📊 Nützliche PromQL Queries (Copy-Paste!)

```promql
# CPU Usage per Node (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage per Pod (GB)
sum(container_memory_working_set_bytes{namespace="my-namespace"}) by (pod) / 1024 / 1024 / 1024

# HTTP Request Rate (req/sec)
rate(http_requests_total{namespace="my-namespace"}[5m])

# HTTP Error Rate (%)
rate(http_requests_total{status=~"5..",namespace="my-namespace"}[5m]) /
rate(http_requests_total{namespace="my-namespace"}[5m]) * 100

# Pod Restart Count (last 1h)
increase(kube_pod_container_status_restarts_total{namespace="my-namespace"}[1h])

# Top 5 CPU Pods
topk(5, rate(container_cpu_usage_seconds_total{namespace="my-namespace"}[5m]))
```

---

## 📝 Nützliche LogQL Queries (Copy-Paste!)

```logql
# All logs from namespace
{namespace="my-namespace"}

# Only error logs
{namespace="my-namespace"} |= "error"

# Logs with "database" keyword
{namespace="my-namespace"} |= "database"

# Error count (last 5 min)
count_over_time({namespace="my-namespace"} |= "error" [5m])

# Logs from specific pod
{namespace="my-namespace", pod="my-pod-0"}

# Exclude info logs
{namespace="my-namespace"} != "info"
```

---

## 🎯 Wichtige URLs (Bookmarks!)

```
Grafana:    http://localhost:3000    (Port-forward: kubectl port-forward -n grafana svc/grafana 3000:3000)
Prometheus: http://localhost:9090    (Port-forward: kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090)
Loki:       http://localhost:3100    (Port-forward: kubectl port-forward -n monitoring svc/loki 3100:3100)
Thanos:     http://localhost:9090    (Port-forward: kubectl port-forward -n monitoring svc/thanos-query 9090:9090)
```

---

## 📚 Next Steps

**Du willst mehr wissen?** → Siehe [OBSERVABILITY-MASTER-GUIDE.md](./OBSERVABILITY-MASTER-GUIDE.md)

**Spezielle Topics:**
- Grafana Operator vs Helm → Section 3
- Prometheus Operator Magie → Section 5
- ServiceMonitor Deep Dive → Section 10
- Velero Backup Strategy → Section 19
- Complete Architecture → Section 9

---

## 🆘 Hilfe?

**Frage:** "Mein Dashboard zeigt 'No Data'"
**Antwort:** → Siehe "Troubleshooting" oben oder MASTER-GUIDE Section 10

**Frage:** "Wie füge ich eine neue App hinzu?"
**Antwort:** → Siehe "3. Neue App Metrics scrapen" oben

**Frage:** "Wie restore ich nach Disaster?"
**Antwort:** → MASTER-GUIDE Section 19 → "Disaster Recovery"

---

**Created for:** Talos Homelab Production
**Last Updated:** 2025-10-21
**See also:** [OBSERVABILITY-MASTER-GUIDE.md](./OBSERVABILITY-MASTER-GUIDE.md) (Deep Dive)
