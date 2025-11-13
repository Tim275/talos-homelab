# 🔍 GRAFANA DASHBOARD TROUBLESHOOTING GUIDE

## ✅ DASHBOARD STATUS ÜBERSICHT (2025-10-02)

### 📊 TOTAL: 61 Enterprise Dashboards Deployed

#### 🏗️ **Infrastructure Dashboards (10)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| k8s-views-global | 15757 | ✅ Working | Prometheus |
| k8s-views-namespaces | 15758 | ✅ Working | Prometheus |
| k8s-views-nodes | 15759 | ✅ Working | Prometheus |
| k8s-views-pods | 15760 | ✅ Working | Prometheus |
| k8s-system-api-server | 15761 | ✅ NEW | Prometheus |
| k8s-system-coredns | 15762 | ✅ NEW | Prometheus |
| k8s-addons-prometheus | 19105 | ✅ NEW | Prometheus |
| talos-cluster-health | 5312 | ✅ FIXED | Prometheus |
| talos-control-plane | Custom | ✅ Working | Prometheus |
| talos-etcd | Custom | ✅ Working | Prometheus |

#### 🌐 **Network Dashboards (3)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| cilium-agent | v1.12 | ✅ Working | Prometheus |
| cilium-operator | v1.12 | ✅ Working | Prometheus |
| cilium-hubble | v1.12 | ✅ Working | Prometheus |

#### 💾 **Storage Dashboards (3)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| rook-ceph-cluster | 2842 | ✅ FIXED | Prometheus |
| rook-ceph-pools | Custom | ✅ Working | Prometheus |
| rook-ceph-osd | Custom | ✅ Working | Prometheus |

#### 🐘 **Database Dashboards (6)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| cloudnativepg-cluster | 20417 | ✅ Working | Prometheus |
| postgresql-database | 9628 | ✅ Working | Prometheus |
| postgresql-kube-prometheus | Custom | ✅ Working | Prometheus |
| postgresql-exporter-quickstart | Custom | ✅ Working | Prometheus |
| postgresql-overview | Custom | ✅ Working | Prometheus |
| elasticsearch-cluster | Custom | ✅ Working | Prometheus |

#### 🎯 **GitOps & Platform (6)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| argocd-app | Custom | ✅ Working | Prometheus |
| argocd-operational | Custom | ✅ Working | Prometheus |
| argocd-official | Custom | ✅ Working | Prometheus |
| argocd-notifications | Custom | ✅ Working | Prometheus |
| sealed-secrets-controller | Custom | ✅ Working | Prometheus |
| kafka (Strimzi) | Custom | ✅ Working | Prometheus |

#### 📊 **Observability Dashboards (10)**
| Dashboard | ID | Status | Datasource |
|-----------|-----|--------|------------|
| loki-stack-monitoring | Custom | ✅ Working | Prometheus |
| loki-logs-dashboard | Custom | ✅ Working | Prometheus |
| loki-promtail | Custom | ✅ Working | Prometheus |
| jaeger-all-in-one | Custom | ⚠️ Partial | Prometheus |
| otel-collector | Custom | ✅ Working | Prometheus |
| vector-cluster | Custom | ⚠️ Partial | Prometheus |

---

## 🚨 PROBLEM: "No Data" in Dashboards

### ROOT CAUSES IDENTIFIED:

#### 1️⃣ **ServiceMonitor Label Mismatch** (FIXED ✅)
**Problem**: ServiceMonitors had wrong `release` label
```yaml
# ❌ WRONG (old):
release: prometheus-operator

# ✅ CORRECT (fixed):
release: kube-prometheus-stack
```

**Fixed Files**:
- `rook-ceph/servicemonitor-ceph-mgr.yaml`
- `rook-ceph/servicemonitor-ceph-exporter.yaml`

#### 2️⃣ **ServiceMonitor Selector Mismatch** (FIXED ✅)
**Problem**: ServiceMonitor selector didn't match Service labels
```yaml
# ❌ WRONG:
selector:
  matchLabels:
    ceph_daemon_type: mgr  # Service doesn't have this label!

# ✅ CORRECT:
selector:
  matchLabels:
    app: rook-ceph-mgr
    rook_cluster: rook-ceph
```

#### 3️⃣ **Wrong Dashboard Import** (FIXED ✅)
**Problem**: Dashboard 8073 is generic Kubernetes, not Talos-optimized

**Solution**: Replaced with Dashboard 5312 (Kubernetes Cluster Health - Prometheus)

#### 4️⃣ **Missing Metrics Services** (PARTIALLY FIXED ⚠️)
**Problem**: Some services don't expose metrics endpoints

**Known Issues**:
- ❌ Jaeger Query: Port mismatch (1 target DOWN)
- ❌ Vector Aggregator: Service down (2 targets DOWN)
- ❌ Loki Gateway: 1 target DOWN

---

## 🔧 DEBUGGING WORKFLOW

### Step 1: Check Prometheus Targets
```bash
export KUBECONFIG=/path/to/kubeconfig
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \\
  wget -qO- 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.health!="up")'
```

### Step 2: Check ServiceMonitor Labels
```bash
kubectl get servicemonitor -n <namespace> -o yaml | grep -A 3 "labels:"
```

**Required Labels**:
```yaml
metadata:
  labels:
    release: kube-prometheus-stack  # ⚠️ CRITICAL!
```

### Step 3: Verify Service Selector
```bash
# Get ServiceMonitor selector
kubectl get servicemonitor <name> -n <namespace> -o jsonpath='{.spec.selector.matchLabels}'

# Get Service labels
kubectl get service <name> -n <namespace> -o jsonpath='{.metadata.labels}'

# ✅ They MUST match!
```

### Step 4: Test Metrics Endpoint
```bash
kubectl exec -n <namespace> <pod-name> -- wget -qO- http://localhost:<port>/metrics
```

### Step 5: Query Prometheus
```bash
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \\
  wget -qO- 'http://localhost:9090/api/v1/query?query=up{job="<job-name>"}'
```

---

## 📋 CRITICAL METRICS REFERENCE

### **API Server**
```promql
up{job="apiserver"}                                    # API Server is UP
apiserver_request_total                                # Total API requests
apiserver_request_duration_seconds                     # Request latency
```

### **ETCD**
```promql
up{job="kube-etcd"}                                    # ETCD is UP
etcd_server_has_leader                                 # Leader status
etcd_disk_backend_commit_duration_seconds              # Disk performance
```

### **Nodes**
```promql
kube_node_info                                         # Node information
kube_node_status_condition{condition="Ready"}          # Node readiness
node_memory_MemAvailable_bytes                         # Available memory
node_cpu_seconds_total                                 # CPU usage
```

### **Pods**
```promql
kube_pod_info                                          # Pod information
kube_pod_status_phase{phase="Running"}                # Running pods
kube_pod_container_status_restarts_total               # Restart count
```

### **Ceph Storage**
```promql
ceph_cluster_total_bytes                               # Total storage
ceph_cluster_total_used_bytes                          # Used storage
ceph_health_status                                     # Ceph health (0=OK)
ceph_osd_up                                            # OSDs UP
```

---

## 🎯 DASHBOARD RECOMMENDATIONS

### **Best Talos/Kubernetes Dashboards**:

1. **k8s-views-global** (15757) - Best overall cluster view
2. **k8s-system-api-server** (15761) - API server deep dive
3. **talos-cluster-health** (5312) - Cluster health overview
4. **rook-ceph-cluster** (2842) - Storage monitoring
5. **k8s-addons-prometheus** (19105) - Prometheus self-monitoring

### **Avoid These**:
- ❌ Dashboard 8073 (old, generic Kubernetes)
- ❌ Dashboard 315 (outdated queries)
- ❌ Any dashboard without datasource override

---

## ✅ VERIFICATION CHECKLIST

Before reporting "No Data":

- [ ] ServiceMonitor has `release: kube-prometheus-stack` label
- [ ] ServiceMonitor selector matches Service labels
- [ ] Service has `metrics` port defined
- [ ] Metrics endpoint returns data (curl test)
- [ ] Prometheus target shows "up" status
- [ ] Dashboard datasourceName = "Prometheus"
- [ ] Grafana can query Prometheus datasource

---

## 🚀 FIXES APPLIED (2025-10-02)

1. ✅ Fixed Ceph ServiceMonitor labels → Metrics now flowing
2. ✅ Fixed Ceph ServiceMonitor selectors → All targets UP
3. ✅ Replaced Dashboard 8073 with 5312 → Better queries
4. ✅ Added k8s-system-api-server (15761) → API server visibility
5. ✅ Added k8s-system-coredns (15762) → CoreDNS monitoring
6. ✅ Added k8s-addons-prometheus (19105) → Prometheus health

---

## 📊 PROMETHEUS TARGETS STATUS

**Total Targets: 119**

- ✅ UP: 116 targets (97.5%)
- ❌ DOWN: 3 targets (2.5%)
  - jaeger-query (port mismatch)
  - loki-gateway (config issue)
  - vector-aggregator (service down)

**Critical Services: ALL UP ✅**
- API Server: ✅ UP
- ETCD: ✅ UP
- Controller Manager: ✅ UP
- Scheduler: ✅ UP
- Kubelet: ✅ UP (21 targets)
- Node Exporter: ✅ UP (7 targets)
- Ceph: ✅ UP (7 targets)

---

## 🔗 REFERENCES

- [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [ServiceMonitor Spec](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor)
