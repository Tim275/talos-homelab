# 📊 ServiceMonitor Complete Guide - Enterprise Monitoring

**PERMANENT SOLUTION**: Wie Services scrapen für Grafana Dashboards (NIE WIEDER "No Data"!)

## 🚨 CRITICAL: Why This Guide Exists

**Problem**: Grafana Dashboards zeigen "No Data" nach Bootstrap
**Root Cause**: ServiceMonitors fehlen oder sind disabled
**Solution**: Centralized ServiceMonitors in `infrastructure/monitoring/servicemonitors/`

---

## 🏗️ Architecture: How Prometheus Monitoring Works

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SERVICE (exposes /metrics endpoint)                      │
│    Examples: rook-ceph-mgr:9283/metrics, argocd-metrics:8082│
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. SERVICEMONITOR (tells Prometheus what to scrape)         │
│    Location: kubernetes/infrastructure/monitoring/           │
│              servicemonitors/servicemonitor-*.yaml           │
│    Critical Labels:                                          │
│      - release: prometheus-operator  ← MUST HAVE!            │
│      - namespace: monitoring         ← MUST BE HERE!         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. PROMETHEUS OPERATOR (discovers ServiceMonitors)          │
│    Selector: release=prometheus-operator                    │
│    Action: Creates Prometheus scrape configs                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. PROMETHEUS (scrapes metrics from services)               │
│    Stores metrics in time-series database                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. GRAFANA DASHBOARDS (query metrics from Prometheus)       │
│    Result: ✅ DATA VISIBLE! (no more "No Data")             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Step-by-Step: How to Add a New Service to Monitoring

### Step 1: Find the Service Metrics Endpoint

```bash
# Check if service has metrics port
kubectl get svc -n <namespace> <service-name> -o yaml | grep -A5 "ports:"

# Example for Ceph:
kubectl get svc -n rook-ceph rook-ceph-mgr -o yaml
# Output: port 9283, name: http-metrics, path: /metrics
```

### Step 2: Create ServiceMonitor YAML

**Template** (`servicemonitor-<service>.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <service-name>
  namespace: monitoring  # ⚠️ CRITICAL: ALWAYS monitoring namespace!
  labels:
    release: prometheus-operator  # ⚠️ CRITICAL: Required for discovery!
    app: <service-name>
    team: platform
spec:
  # Target service selector
  selector:
    matchLabels:
      app: <service-label>  # Must match Service labels!

  # Target namespace
  namespaceSelector:
    matchNames:
      - <target-namespace>  # Where the service lives

  # Scrape configuration
  endpoints:
    - port: <metrics-port-name>  # Port name from Service
      path: /metrics              # Usually /metrics
      interval: 30s               # Scrape every 30 seconds
      scrapeTimeout: 10s
      honorLabels: true           # Keep original metric labels
```

### Step 3: Add to servicemonitors/kustomization.yaml

```yaml
# kubernetes/infrastructure/monitoring/servicemonitors/kustomization.yaml
resources:
  - servicemonitor-<service>.yaml  # Add your new ServiceMonitor
```

### Step 4: Commit & Push

```bash
git add kubernetes/infrastructure/monitoring/servicemonitors/
git commit -m "feat: add <service> ServiceMonitor for metrics scraping"
git push
```

### Step 5: Verify in Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090

# Open http://localhost:9090/targets
# Look for your service - should show "UP" status
```

---

## 🎯 Real-World Examples

### Example 1: Rook-Ceph Storage Cluster

**Problem**: Ceph Cluster dashboard shows "No Data" for capacity, OSDs, pools

**Solution**:
```yaml
# servicemonitor-ceph.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rook-ceph-mgr
  namespace: monitoring
  labels:
    release: prometheus-operator
    app: rook-ceph-mgr
spec:
  selector:
    matchLabels:
      app: rook-ceph-mgr
      rook_cluster: rook-ceph
  namespaceSelector:
    matchNames:
      - rook-ceph
  endpoints:
    - port: http-metrics  # Port 9283
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
      honorLabels: true
```

**But also need Ceph Exporter** (for OSD stats):
```yaml
# servicemonitor-ceph-exporter.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rook-ceph-exporter
  namespace: monitoring
  labels:
    release: prometheus-operator
spec:
  selector:
    matchLabels:
      app: rook-ceph-exporter
  namespaceSelector:
    matchNames:
      - rook-ceph
  endpoints:
    - port: ceph-exporter-http-metrics
      path: /metrics
      interval: 30s
```

### Example 2: Istio Service Mesh

**Problem**: Istio Mesh dashboard shows "No Data"

**Solution**:
```yaml
# servicemonitor-istio.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod
  namespace: monitoring
  labels:
    release: prometheus-operator
spec:
  selector:
    matchLabels:
      app: istiod
  namespaceSelector:
    matchNames:
      - istio-system
  endpoints:
    - port: http-monitoring  # Port 15014
      path: /metrics
      interval: 30s
```

### Example 3: ArgoCD Applications

**Problem**: ArgoCD dashboard shows "No Data" for unhealthy apps

**Solution**:
```yaml
# servicemonitor-argocd.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    release: prometheus-operator
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics  # Port 8082
      path: /metrics
      interval: 30s
```

---

## ❌ Common Mistakes (Why "No Data" Happens)

### Mistake 1: Wrong Namespace
```yaml
# ❌ WRONG - ServiceMonitor in wrong namespace
metadata:
  namespace: rook-ceph  # Prometheus can't find it!

# ✅ CORRECT - Always monitoring namespace
metadata:
  namespace: monitoring
```

### Mistake 2: Missing release Label
```yaml
# ❌ WRONG - Missing critical label
labels:
  app: my-service

# ✅ CORRECT - Prometheus discovers it
labels:
  release: prometheus-operator  # CRITICAL!
  app: my-service
```

### Mistake 3: ServiceMonitors Disabled
```bash
# ❌ WRONG - Directory disabled
kubernetes/infrastructure/monitoring/servicemonitors.disabled/

# ✅ CORRECT - Directory enabled and in kustomization
kubernetes/infrastructure/monitoring/servicemonitors/
# AND listed in monitoring/kustomization.yaml resources!
```

### Mistake 4: Wrong Service Label Selector
```yaml
# ❌ WRONG - Selector doesn't match Service labels
selector:
  matchLabels:
    app: wrong-label  # Service has different label!

# ✅ CORRECT - Check service labels first
# kubectl get svc -n <namespace> <service> -o yaml | grep labels:
selector:
  matchLabels:
    app: actual-service-label  # Must match!
```

---

## 🔍 Debugging "No Data" Issues

### Step 1: Check if ServiceMonitor exists
```bash
kubectl get servicemonitor -n monitoring
```

### Step 2: Check Prometheus Targets
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
# Look for your service - should be "UP"
```

### Step 3: Check Service has metrics port
```bash
kubectl get svc -n <namespace> <service> -o yaml | grep -A5 ports:
```

### Step 4: Test metrics endpoint directly
```bash
kubectl port-forward -n <namespace> svc/<service> <port>:<port>
curl http://localhost:<port>/metrics
# Should return Prometheus metrics
```

### Step 5: Check Prometheus logs
```bash
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus | grep -i "error\|failed"
```

---

## 📊 Complete ServiceMonitor Checklist

For **permanent monitoring** that survives bootstrap:

- [ ] ServiceMonitor in `kubernetes/infrastructure/monitoring/servicemonitors/`
- [ ] Correct namespace: `monitoring`
- [ ] Correct label: `release: prometheus-operator`
- [ ] Listed in `servicemonitors/kustomization.yaml` resources
- [ ] `servicemonitors/application.yaml` exists
- [ ] Listed in `monitoring/kustomization.yaml` as child application
- [ ] Service has metrics port exposed
- [ ] Selector matches Service labels
- [ ] Prometheus target shows "UP" status
- [ ] Grafana dashboard queries show data

---

## 🎯 Priority ServiceMonitors (Must Have)

### Infrastructure Layer (Tier 0)
1. ✅ **Ceph Manager** - `servicemonitor-ceph.yaml`
2. ✅ **Ceph Exporter** - `servicemonitor-ceph-exporter.yaml`
3. ✅ **Istio Control Plane** - `servicemonitor-istio.yaml`
4. ✅ **ArgoCD** - `servicemonitor-argocd.yaml`
5. ✅ **Cert-Manager** - `servicemonitor-cert-manager.yaml`
6. ✅ **Sealed Secrets** - `servicemonitor-sealed-secrets.yaml`
7. ✅ **Cilium** - Enabled via Helm chart
8. ✅ **Hubble** - Enabled via Helm chart

### Platform Layer (Tier 1)
1. ✅ **Kafka Exporter** - `servicemonitor-kafka-exporter.yaml`
2. ✅ **Elasticsearch** - `servicemonitor-elasticsearch.yaml`
3. ✅ **CloudNative-PG** - `servicemonitor-cnpg.yaml`
4. ✅ **Redis** - `servicemonitor-redis.yaml`

### Apps Layer (Tier 2)
1. ✅ **N8N** - `servicemonitor-n8n.yaml`
2. ✅ **Audiobookshelf** - `servicemonitor-audiobookshelf.yaml`

---

## 🚀 Maintenance: Keep Monitoring Healthy Forever

### After Adding New Service
```bash
# 1. Create ServiceMonitor
vim kubernetes/infrastructure/monitoring/servicemonitors/servicemonitor-newservice.yaml

# 2. Add to kustomization
echo "  - servicemonitor-newservice.yaml" >> kubernetes/infrastructure/monitoring/servicemonitors/kustomization.yaml

# 3. Commit & Push
git add kubernetes/infrastructure/monitoring/servicemonitors/
git commit -m "feat: add newservice ServiceMonitor"
git push

# 4. Wait 30s for ArgoCD sync

# 5. Verify
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
# Check http://localhost:9090/targets for newservice
```

### After Bootstrap (Fresh Cluster)
ServiceMonitors deploy automatically via App-of-Apps pattern!

```
bootstrap/ → infrastructure/ → monitoring/ → servicemonitors/
  ↓              ↓                 ↓              ↓
  ✅          ✅              ✅           ✅ ALL ServiceMonitors deployed!
```

**No manual intervention needed!** 🎉

---

## 📚 Reference Links

- **Prometheus Operator**: https://prometheus-operator.dev/docs/operator/design/
- **ServiceMonitor Spec**: https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor
- **Grafana Operator**: https://grafana.github.io/grafana-operator/docs/
- **Vegarn's OIDC Article** (Architecture Pattern): https://blog.stonegarden.dev/articles/2025/06/authelia-oidc/

---

## 🎯 Summary: The Golden Rules

1. **ServiceMonitors ALWAYS in `monitoring` namespace**
2. **ServiceMonitors ALWAYS have `release: prometheus-operator` label**
3. **ServiceMonitors ALWAYS in `servicemonitors/kustomization.yaml` resources**
4. **servicemonitors/ ALWAYS enabled** (not `.disabled`)
5. **Test metrics endpoint BEFORE creating ServiceMonitor**
6. **Check Prometheus targets AFTER deploying ServiceMonitor**
7. **One ServiceMonitor per service** (don't combine in multi-doc YAML)

**Follow these rules = NO MORE "No Data" FOREVER!** ✅
