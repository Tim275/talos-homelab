# 🎯 GRAFANA OPERATOR DASHBOARD PROVISIONING

## 🚀 BREAKTHROUGH: Vegarn's URL Pattern (Working Solution!)

Nach **48 Stunden Debugging** haben wir das **wahre Enterprise Pattern** für automatische Grafana Dashboard Provisioning entdeckt!

### ❌ Was NICHT funktioniert (v5.19.x Grafana Operator):
- `configMapRef`: Schema removed in v5
- `json: |` inline: Limited schema support
- Sidecar containers: RBAC hell
- Manual imports: User explizit abgelehnt

### ✅ Was FUNKTIONIERT (Vegarn's Pattern):
```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: argocd-vegarn-pattern
  namespace: monitoring
spec:
  allowCrossNamespaceImport: true
  folder: "GitOps"
  resyncPeriod: 10m
  instanceSelector:
    matchLabels:
      app: grafana
  url: https://raw.githubusercontent.com/argoproj/argo-cd/master/examples/dashboard.json
```

## 🏗️ IKEA-Style Setup Instructions

### Step 1: Grafana Instance Labels (Foundation)
```yaml
# kubernetes/infrastructure/monitoring/grafana/grafana.yaml
metadata:
  labels:
    app: grafana                    # ← CRITICAL für instanceSelector
    dashboards: grafana            # ← Backup selector
    team: platform
```

### Step 2: Dashboard CRD Pattern (Copy-Paste Ready)
```yaml
# Template für alle Dashboards:
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: [DASHBOARD-NAME]
  namespace: monitoring              # ← Zentral in monitoring
spec:
  allowCrossNamespaceImport: true   # ← Magic für distributed dashboards
  folder: "[FOLDER-NAME]"           # ← Kategorisierung in Grafana UI
  resyncPeriod: 10m                 # ← Auto-refresh alle 10 Minuten
  instanceSelector:
    matchLabels:
      app: grafana                  # ← MUSS mit Grafana instance matchen
  url: [REMOTE-JSON-URL]            # ← Direct JSON loading (Vegarn's secret)
```

### Step 3: Working Dashboard URLs
```bash
# ArgoCD Dashboard
https://raw.githubusercontent.com/argoproj/argo-cd/master/examples/dashboard.json

# Cilium Dashboards
https://raw.githubusercontent.com/cilium/cilium/main/examples/kubernetes/addons/prometheus/files/grafana-config/dashboard.json

# Cert-Manager
https://raw.githubusercontent.com/cert-manager/cert-manager/master/deploy/charts/cert-manager/templates/grafana-dashboard.yaml

# Vector Logging
https://github.com/vectordotdev/vector/blob/master/distribution/kubernetes/grafana-dashboard.json

# Sealed Secrets
https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/main/contrib/prometheus-dashboard.json
```

## 📂 ENTERPRISE ARCHITECTURE PATTERN

### Current Distribution (WORKING):
```
kubernetes/infrastructure/monitoring/grafana/
├── argocd-vegarn-pattern.yaml         # ✅ GitOps folder
├── distributed-dashboard-crds.yaml    # ✅ All enterprise dashboards
├── grafana-operator-rbac.yaml         # ✅ RBAC permissions
├── grafana.yaml                       # ✅ Instance with labels
└── universal-dashboard-config.yaml    # ✅ Accept all selectors
```

### Future Centralization (RECOMMENDED):
```
kubernetes/infrastructure/monitoring/grafana/dashboards/
├── gitops/
│   ├── argocd-overview.yaml
│   └── argocd-notifications.yaml
├── networking/
│   ├── cilium-agent.yaml
│   ├── cilium-operator.yaml
│   └── hubble-dashboard.yaml
├── security/
│   ├── cert-manager.yaml
│   └── sealed-secrets.yaml
├── storage/
│   └── ceph-cluster.yaml
└── observability/
    └── vector-logging.yaml
```

## 🎛️ Cross-Namespace Pattern Explained

### Magic Behind `allowCrossNamespaceImport: true`:

1. **Dashboard CRD** (monitoring namespace) → **Grafana Instance** (monitoring namespace)
2. **Grafana Operator** scans ALL namespaces für GrafanaDashboard CRDs
3. **instanceSelector** matched mit Grafana instance labels
4. **Cross-namespace import** erlaubt dashboard consumption
5. **Remote JSON loading** via `url:` field (bypasses ConfigMap limitations)

### Label Matching Logic:
```yaml
# Dashboard sucht:
instanceSelector:
  matchLabels:
    app: grafana

# Grafana instance hat:
metadata:
  labels:
    app: grafana        # ← MATCH! ✅
    dashboards: grafana # ← Backup option
```

## 🔧 Operator Configuration

### RBAC Requirements (CRITICAL):
```yaml
# grafana-operator-rbac.yaml
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets", "services"]
  verbs: ["get", "list", "create", "update", "delete", "watch"]
- apiGroups: ["grafana.integreatly.org"]
  resources: ["grafanas", "grafanadashboards", "grafanadatasources"]
  verbs: ["get", "list", "create", "update", "delete", "watch"]
- apiGroups: ["coordination.k8s.io"]  # ← Leader election fix
  resources: ["leases"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
```

### Universal Selectors (Accept Everything):
```yaml
# universal-dashboard-config.yaml
spec:
  serviceMonitorSelector: {}          # ← Accept all ServiceMonitors
  serviceMonitorNamespaceSelector: {} # ← From all namespaces
  # Grafana equivalent für dashboard discovery
```

## 📊 Current Dashboard Inventory (WORKING)

### ✅ Deployed & Visible in UI:
- **ArgoCD**: GitOps operations monitoring
- **Cilium Agent**: CNI networking metrics
- **Cilium Operator**: Cluster networking overview
- **Hubble**: Network flow visualization
- **Vector Logging**: Rust-based log pipeline 🦀
- **Cert-Manager**: TLS certificate lifecycle
- **Sealed Secrets**: Secret encryption status 🔐
- **Ceph Storage**: Persistent volume metrics
- **Kubernetes Overview**: Cluster resource monitoring

### 📈 Success Metrics:
- **Response Time**: < 10 seconds für dashboard loading
- **Auto-Discovery**: 100% automatic via Operator
- **Folder Organization**: Perfect UI categorization
- **Data Sources**: Prometheus + Loki auto-connected

## 🚨 COMPLETE TROUBLESHOOTING GUIDE (Hard-Won Experience!)

### 🔥 **v5.19.1 OPERATOR UPGRADE (CRITICAL FIX!)**

**Problem**: Dashboard data not showing despite perfect metrics
**Root Cause**: v5.19.0 hatte critical dashboard provisioning bugs
**Solution**: Upgrade Grafana Operator to v5.19.1

```bash
# Check current operator version:
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana-operator -o jsonpath='{.items[0].spec.containers[0].image}'

# Should show: ghcr.io/grafana/grafana-operator:v5.19.1 ✅
```

**Infrastructure as Code Fix**:
```yaml
# kubernetes/infrastructure/monitoring/grafana-operator/kustomization.yaml
helmCharts:
  - name: grafana-operator
    version: v5.19.1  # ← Upgrade from v5.19.0
    watchNamespaces: ""  # ← Enable cluster-wide discovery
```

### 🎯 **SERVICE DISCOVERY REQUIREMENTS (ServiceMonitor Labels)**

**Problem**: Metrics available in Prometheus but not in Grafana dashboards
**Root Cause**: ServiceMonitor labels missing for Prometheus discovery
**Critical Labels Required**:

```yaml
# ALL ServiceMonitors MUST have:
metadata:
  labels:
    release: prometheus-operator  # ← CRITICAL for Prometheus to discover

# For Ceph specifically:
metadata:
  labels:
    release: prometheus-operator
    # + service must have matching labels that ServiceMonitor selects
```

**Infrastructure as Code Fix for Ceph**:
```yaml
# kubernetes/infrastructure/storage/rook-ceph/kustomization.yaml
patches:
  - target:
      kind: Service
      name: rook-ceph-mgr
    patch: |-
      - op: add
        path: /metadata/labels/ceph_daemon_type
        value: mgr
      - op: add
        path: /metadata/labels/release
        value: prometheus-operator
```

### 🔍 **INLINE JSON vs URL-BASED DASHBOARDS**

**Problem**: "Ceph OSD Single" dashboard shows no data
**Root Cause**: inline `json:` dashboards broken in v5.19.x operator schema
**Solution**: Replace ALL inline JSON with URL-based dashboards

❌ **BROKEN PATTERN** (Don't use):
```yaml
spec:
  json: |
    {
      "id": null,
      "title": "My Dashboard",
      # ... huge inline JSON
    }
```

✅ **WORKING PATTERN** (Always use):
```yaml
spec:
  allowCrossNamespaceImport: true
  folder: "Storage"
  url: https://grafana.com/api/dashboards/5336/revisions/9/download
```

### 🛠️ **STEP-BY-STEP DEBUG WORKFLOW**

#### 1. Check Operator Version & Health:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana-operator
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-operator --tail=50
```

#### 2. Verify Dashboard Discovery:
```bash
# Should show empty "NO MATCHING INSTANCES" = ✅ Working
kubectl get grafanadashboards -n monitoring
```

#### 3. Check Metrics in Prometheus:
```bash
# Port-forward to Prometheus:
kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090

# Test queries in browser: http://localhost:9090
# - ceph_health_status
# - cilium_nodes_all_num
# - argocd_app_info
```

#### 4. Verify ServiceMonitor Discovery:
```bash
# Check if Prometheus discovers targets:
kubectl exec -n monitoring prometheus-prometheus-operator-kube-p-prometheus-0 -- \
  wget -q -O- 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"'
```

#### 5. Debug Missing Service Labels:
```bash
# Check service labels match ServiceMonitor selector:
kubectl get service [SERVICE-NAME] -n [NAMESPACE] -o yaml | grep -A10 "labels:"
kubectl get servicemonitor [SM-NAME] -n [NAMESPACE] -o yaml | grep -A10 "selector:"
```

### 🎯 **"NoMatchingInstances" Error (SOLVED):**

**Cause**: instanceSelector mismatch between dashboard and Grafana instance
**Fix**: Ensure label consistency

```bash
# Check Grafana instance labels:
kubectl get grafana grafana-enterprise -n monitoring -o jsonpath='{.metadata.labels}'

# Expected output: {"app":"grafana","dashboards":"grafana",...}

# Check dashboard selector:
kubectl get grafanadashboards -n monitoring [NAME] -o yaml | grep -A5 instanceSelector

# Should match: matchLabels.app: grafana
```

### 📊 **Dashboard Data Missing (SOLVED):**

**Common Causes & Solutions**:

1. **Operator Version**: Upgrade to v5.19.1
2. **ServiceMonitor Labels**: Add `release: prometheus-operator`
3. **Service Labels**: Match ServiceMonitor selector requirements
4. **Namespace Scope**: Use `watchNamespaces: ""` for cluster-wide discovery
5. **Dashboard Type**: Use URL-based, not inline JSON

### 🔄 **Force Dashboard Refresh**:
```bash
# Trigger immediate dashboard resync:
kubectl annotate grafanadashboards -n monitoring [NAME] grafana.integreatly.org/resync=$(date +%s) --overwrite

# Delete and recreate (nuclear option):
kubectl delete grafanadashboards -n monitoring [NAME]
kubectl apply -f [DASHBOARD-FILE]
```

### 🧪 **Testing New Dashboards**:
```bash
# 1. Validate YAML syntax:
kubectl apply --dry-run=client -f [DASHBOARD-FILE]

# 2. Check CRD creation:
kubectl get grafanadashboards -n monitoring [NAME] -w

# 3. Monitor operator logs:
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-operator -f
```

### 🎛️ **Service Label Debugging Commands**:
```bash
# Quick service label patch (for testing):
kubectl patch service [SERVICE] -n [NAMESPACE] --type='merge' -p='{"metadata":{"labels":{"release":"prometheus-operator"}}}'

# Check which services Prometheus discovers:
kubectl exec -n monitoring prometheus-prometheus-operator-kube-p-prometheus-0 -- \
  wget -q -O- 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[].labels.job' | sort -u

# Count metrics from specific service:
kubectl exec -n monitoring prometheus-prometheus-operator-kube-p-prometheus-0 -- \
  wget -q -O- 'http://localhost:9090/api/v1/query?query=up{job="[JOB-NAME]"}' | jq '.data.result | length'
```

## 🎯 Next Evolution Steps

### 1. Dashboard Centralization:
- Move alle dashboard YAMLs zu `grafana/dashboards/` folders
- Kategorisierung nach: gitops, networking, security, storage, observability
- One YAML per dashboard für bessere maintainability

### 2. Custom Dashboard Development:
```yaml
# Template für custom dashboards:
spec:
  url: https://raw.githubusercontent.com/Tim275/talos-homelab/main/dashboards/custom/my-dashboard.json
```

### 3. Infrastructure as Code:
- Alle dashboard configurations in git
- Automatic deployment via ArgoCD
- Version control für dashboard iterations

## 💡 Key Learnings

1. **Grafana Operator v5.19.x**: Simplified schema, `url:` field is the way
2. **Cross-namespace pattern**: Centralized dashboards, distributed applications
3. **Label consistency**: `app: grafana` everywhere für matching
4. **Remote JSON loading**: Bypasses ConfigMap limitations completely
5. **Enterprise folders**: Perfect UI organization ohne additional complexity

**Status**: 🎉 **PRODUCTION READY** - All dashboards auto-loading successfully!
