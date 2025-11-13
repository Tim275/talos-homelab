# 🧹 DASHBOARD CLEANUP PLAN - Clean Slate 2025

## 📊 CURRENT STATE: 58 Dashboards (chaotic)

### ❌ **PROBLEMS IDENTIFIED:**

1. **Duplicate/Redundant Dashboards**
   - Multiple Node Exporter dashboards (talos-node-exporter-full vs talos-k8s-node-metrics)
   - Generic K8s dashboards not optimized for Talos
   - Too many Elasticsearch dashboards (5!)
   - Too many Loki dashboards (5!)

2. **Missing Application Dashboards**
   - ❌ N8N (prod + dev) - NO dashboards!
   - ❌ Redis - NO dashboards!
   - ❌ Authelia - NO dashboards!

3. **Old/Outdated Dashboards**
   - Cilium v1.12 (current is v1.16+)
   - Generic "Kubernetes Cluster Health" (not Talos-optimized)
   - Multiple OTel/Jaeger dashboards (overkill?)

4. **No Clear Folder Structure**
   - Everything mixed together
   - No composite/overview dashboards

---

## ✅ **NEW STRUCTURE - Enterprise Clean**

### **Tier 1: Platform Core** (Essential, always visible)

#### 📊 **1. Overview Dashboards** (NEW - Custom)
```
🏠 Homelab Overview
   ├─ Cluster Health (nodes, pods, resources)
   ├─ Storage (Ceph capacity, IOPS)
   ├─ Network (Cilium traffic)
   └─ GitOps (ArgoCD sync status)

🎯 Platform SLIs
   ├─ API Server Latency (p50, p95, p99)
   ├─ ETCD Latency
   ├─ Network Latency
   └─ Storage Latency
```

#### ☸️ **2. Kubernetes Core** (dotdc collection - KEEP)
```
✅ k8s-views-global (15757)
✅ k8s-views-namespaces (15758)
✅ k8s-views-nodes (15759)
✅ k8s-views-pods (15760)
✅ k8s-system-api-server (15761)
✅ k8s-system-coredns (15762)
✅ k8s-addons-prometheus (19105)
🆕 k8s-addons-trivy-operator (16337) - Security!
```

#### ⚙️ **3. Talos Linux** (SIMPLIFY - 2 dashboards only)
```
✅ Node Exporter Full (1860) - Comprehensive node metrics
❌ REMOVE: talos-k8s-node-metrics (duplicate)
❌ REMOVE: talos-cluster-health (replaced by k8s-views-global)
❌ REMOVE: talos-control-plane (replaced by k8s-system-api-server)
✅ KEEP: talos-etcd (specific ETCD deep dive)
```

### **Tier 2: Infrastructure** (Core services)

#### 🌐 **4. Network (Cilium)**
```
🔄 UPGRADE from v1.12 to latest:
   - Cilium Agent
   - Cilium Operator
   - Hubble (network observability)
```

#### 💾 **5. Storage (Ceph)** - KEEP ALL ✅
```
✅ rook-ceph-cluster (2842) - Working perfectly!
✅ rook-ceph-pools
✅ rook-ceph-osd
```

#### 📊 **6. GitOps (ArgoCD)** - SIMPLIFY
```
✅ KEEP: argocd-official (best overview)
❌ REMOVE: argocd-app, argocd-operational, argocd-notifications (redundant)
```

### **Tier 3: Data Layer** (Databases & messaging)

#### 🐘 **7. PostgreSQL** - SIMPLIFY
```
✅ KEEP: cloudnativepg-cluster (CloudNativePG operator)
✅ KEEP: postgresql-database (9628) - Best general dashboard
❌ REMOVE: postgresql-exporter-quickstart (duplicate)
❌ REMOVE: postgresql-kube-prometheus (duplicate)
❌ REMOVE: postgresql-overview (duplicate)
```

#### 📨 **8. Kafka (Strimzi)** - KEEP ESSENTIALS
```
✅ KEEP: strimzi-kafka-exporter - Best for monitoring
✅ KEEP: strimzi-operators - Operator health
❌ REMOVE: strimzi-kafka, strimzi-kraft, strimzi-kafka-connect (too detailed)
```

#### 🔍 **9. Elasticsearch** - SIMPLIFY DRASTICALLY
```
✅ KEEP: elasticsearch-cluster - Best overview
❌ REMOVE: elasticsearch-exporter, elasticsearch-exporter-quickstart (redundant)
❌ REMOVE: elasticsearch-node-stats, elasticsearch-stats (too detailed)
```

### **Tier 4: Observability** (Logs & traces - SIMPLIFY)

#### 📝 **10. Loki (Logs)** - SIMPLIFY
```
✅ KEEP: loki-stack-monitoring - Stack health
✅ KEEP: loki-logs-dashboard - Log viewing
❌ REMOVE: loki-dashboard, loki-promtail, loki-logging-v2 (redundant)
```

#### 🔭 **11. Tracing** - SIMPLIFY DRASTICALLY
```
✅ KEEP: jaeger-complete (all-in-one view)
❌ REMOVE: jaeger-all-in-one, jaeger-collector, jaeger-query, jaeger-traces-metrics
❌ REMOVE: All OTel dashboards (5!) - overkill for homelab
```

#### 🦀 **12. Vector (Logs)** - SIMPLIFY
```
✅ KEEP: vector-cluster - Best overview
❌ REMOVE: vector-full, vector-monitoring, vector-stats (redundant)
❌ REMOVE: vector-kubernetes-logging (use Loki instead)
```

### **Tier 5: Applications** (NEW - Missing!)

#### 🔄 **13. N8N Workflow Automation**
```
🆕 n8n-prod-overview (Dashboard ID: TBD - search grafana.com)
   ├─ Active workflows
   ├─ Execution success/failure rate
   ├─ Queue length
   └─ PostgreSQL connection pool

🆕 n8n-dev-overview (same as prod, different namespace)
```

#### 🔐 **14. Sealed Secrets** - KEEP
```
✅ KEEP: sealed-secrets-controller
   (once ServiceMonitor is working)
```

#### 🔴 **15. Redis** (if deployed)
```
🆕 redis-overview (Dashboard ID: 11835 - Redis Dashboard for Prometheus)
```

#### 🔑 **16. Authelia** (if deployed)
```
🆕 authelia-overview (Dashboard ID: TBD - search or create custom)
```

---

## 📋 **EXECUTION PLAN:**

### **Step 1: Remove Redundant Dashboards** ❌

Delete these from Git:
```bash
# Talos (remove 3 of 4):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/talos/
  ❌ talos-cluster-health.yaml
  ❌ talos-control-plane.yaml
  ❌ talos-k8s-node-metrics.yaml
  ✅ KEEP: talos-etcd.yaml
  ✅ KEEP: talos-node-exporter-full.yaml

# ArgoCD (remove 3 of 4):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/argocd/
  ❌ argocd-app.yaml
  ❌ argocd-operational.yaml
  ❌ argocd-notifications.yaml
  ✅ KEEP: argocd-official.yaml

# PostgreSQL (remove 3 of 5):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/postgresql/
  ❌ postgresql-exporter-quickstart.yaml
  ❌ postgresql-kube-prometheus.yaml
  ❌ postgresql-overview.yaml
  ✅ KEEP: cloudnativepg-cluster.yaml
  ✅ KEEP: postgresql-database.yaml

# Kafka (remove 3 of 5):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/kafka/
  ❌ strimzi-kafka.yaml
  ❌ strimzi-kraft.yaml
  ❌ strimzi-kafka-connect.yaml
  ✅ KEEP: strimzi-kafka-exporter.yaml
  ✅ KEEP: strimzi-operators.yaml

# Elasticsearch (remove 4 of 5):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/elasticsearch/
  ❌ elasticsearch-exporter.yaml
  ❌ elasticsearch-exporter-quickstart.yaml
  ❌ elasticsearch-node-stats.yaml
  ❌ elasticsearch-stats.yaml
  ✅ KEEP: elasticsearch-cluster.yaml

# Loki (remove 3 of 5):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/loki/
  ❌ loki-dashboard.yaml
  ❌ loki-promtail.yaml
  ❌ loki-logging-v2.yaml
  ✅ KEEP: loki-stack-monitoring.yaml
  ✅ KEEP: loki-logs-dashboard.yaml

# Jaeger (remove 4 of 5):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/jaeger/
  ❌ jaeger-all-in-one.yaml
  ❌ jaeger-collector.yaml
  ❌ jaeger-query.yaml
  ❌ jaeger-traces-metrics.yaml
  ✅ KEEP: jaeger-complete.yaml

# OpenTelemetry (remove ALL 5 - overkill):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/opentelemetry/
  ❌ otel-apm.yaml
  ❌ otel-collector.yaml
  ❌ otel-data-flow.yaml
  ❌ otel-jvm.yaml
  ❌ otel-lightweight-apm.yaml

# Vector (remove 3 of 4):
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/vector/
  ❌ vector-full.yaml
  ❌ vector-monitoring.yaml
  ❌ vector-stats.yaml
  ❌ vector-kubernetes-logging.yaml (use Loki)
  ✅ KEEP: vector-cluster.yaml
```

**RESULT**: Remove **30 dashboards**, keep **28 essentials**

### **Step 2: Add Missing Dashboards** 🆕

```bash
# Kubernetes Security:
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/infrastructure/
  🆕 k8s-addons-trivy-operator.yaml (Dashboard 16337)

# Upgrade Cilium:
kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/cilium/
  🔄 Update to latest Cilium dashboards (v1.16+)

# Applications:
kubernetes/apps/base/n8n/dashboards/
  🆕 n8n-prod-dashboard.yaml
  🆕 n8n-dev-dashboard.yaml

kubernetes/platform/data/redis/dashboards/
  🆕 redis-dashboard.yaml (Dashboard 11835)
```

### **Step 3: Create Custom Composite Dashboards** 🎨

```bash
kubernetes/infrastructure/monitoring/grafana/custom-dashboards/
  🆕 homelab-overview.yaml - Single pane of glass
  🆕 platform-slis.yaml - SRE metrics
  🆕 application-health.yaml - All apps status
```

### **Step 4: Update Kustomization** 📝

Rebuild kustomization.yaml with CLEAN structure:
```yaml
resources:
  # ☸️ KUBERNETES CORE (8 dashboards)
  - kubernetes/k8s-views-global.yaml
  - kubernetes/k8s-views-namespaces.yaml
  - kubernetes/k8s-views-nodes.yaml
  - kubernetes/k8s-views-pods.yaml
  - kubernetes/k8s-system-api-server.yaml
  - kubernetes/k8s-system-coredns.yaml
  - kubernetes/k8s-addons-prometheus.yaml
  - kubernetes/k8s-addons-trivy-operator.yaml

  # ⚙️ TALOS LINUX (2 dashboards)
  - talos/talos-node-exporter-full.yaml
  - talos/talos-etcd.yaml

  # 🌐 NETWORK (3 dashboards)
  - cilium/cilium-agent.yaml
  - cilium/cilium-operator.yaml
  - cilium/cilium-hubble.yaml

  # 💾 STORAGE (3 dashboards)
  - ceph/rook-ceph-cluster.yaml
  - ceph/rook-ceph-pools.yaml
  - ceph/rook-ceph-osd.yaml

  # 📊 GITOPS (1 dashboard)
  - argocd/argocd-official.yaml

  # 🐘 DATA (4 dashboards)
  - postgresql/cloudnativepg-cluster.yaml
  - postgresql/postgresql-database.yaml
  - kafka/strimzi-kafka-exporter.yaml
  - kafka/strimzi-operators.yaml

  # 🔍 OBSERVABILITY (4 dashboards)
  - elasticsearch/elasticsearch-cluster.yaml
  - loki/loki-stack-monitoring.yaml
  - loki/loki-logs-dashboard.yaml
  - jaeger/jaeger-complete.yaml
  - vector/vector-cluster.yaml

  # 🔐 SECURITY (1 dashboard)
  - sealed-secrets/sealed-secrets-controller.yaml

  # 📱 APPLICATIONS (3+ dashboards)
  - applications/n8n-prod.yaml
  - applications/n8n-dev.yaml
  - applications/redis.yaml

  # 🎨 CUSTOM COMPOSITES (3 dashboards)
  - custom/homelab-overview.yaml
  - custom/platform-slis.yaml
  - custom/application-health.yaml
```

---

## 📊 **FINAL STATE:**

```
BEFORE: 58 dashboards (chaotic, redundant)
AFTER:  35 dashboards (clean, organized)

Breakdown:
  ☸️ Kubernetes Core: 8
  ⚙️ Talos Linux: 2
  🌐 Network (Cilium): 3
  💾 Storage (Ceph): 3
  📊 GitOps (ArgoCD): 1
  🐘 Data (PostgreSQL/Kafka): 4
  🔍 Observability: 5
  🔐 Security: 1
  📱 Applications: 3
  🎨 Custom: 3
```

**Reduction**: -23 dashboards (-40%)
**Quality**: +100% (only best-in-class dashboards)
**Organization**: Enterprise-grade folder structure

---

## ✅ **BENEFITS:**

1. ✅ **No More Duplicates** - One dashboard per purpose
2. ✅ **Talos-Optimized** - dotdc collection designed for kube-prometheus-stack
3. ✅ **Application Visibility** - N8N, Redis dashboards added
4. ✅ **Custom Overviews** - Composite dashboards for quick insights
5. ✅ **Modern & Maintained** - All dashboards from 2024/2025
6. ✅ **Clear Structure** - Easy to find what you need

---

## 🚀 **NEXT STEPS:**

1. ✅ Approve this plan
2. 🔨 Execute Step 1: Remove redundant dashboards (Git commit)
3. 🆕 Execute Step 2: Add missing dashboards (Git commit)
4. 🎨 Execute Step 3: Create custom composites (Git commit)
5. 📝 Execute Step 4: Update kustomization.yaml (Git commit)
6. 🚀 Push all changes → ArgoCD deploys clean dashboard set
7. 🎉 Enjoy clean, organized, modern dashboards!

**Ready to start? Say "YES" and I'll begin the cleanup!**
