# 🚀 MONITORING BEST PRACTICES - VictoriaMetrics for Talos Kubernetes

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   METRICS SOURCES                        │
├───────────────┬───────────────┬────────────┬────────────┤
│  Talos Nodes  │  Kubernetes   │   Apps     │  External  │
│  - kubelet    │  - apiserver  │  - Redis   │  - Proxmox │
│  - containerd │  - etcd       │  - Elastic │  - TrueNAS │
│  - node-exp   │  - scheduler  │  - Ceph    │            │
└───────┬───────┴───────┬───────┴─────┬──────┴─────┬──────┘
        │               │             │            │
        ▼               ▼             ▼            ▼
┌──────────────────────────────────────────────────────────┐
│              VMAgent (Scraping Layer)                     │
│  - ServiceDiscovery via ServiceMonitor/VMServiceScrape   │
│  - Cross-namespace scraping enabled                       │
│  - Deduplication & relabeling                           │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│           VMCluster (Storage & Query Layer)               │
├────────────────┬──────────────────┬──────────────────────┤
│   VMStorage    │    VMSelect      │     VMInsert         │
│  100Gi Ceph    │  Query Engine    │   Write Buffer       │
└────────────────┴──────────────────┴──────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│                    Grafana Dashboards                     │
└──────────────────────────────────────────────────────────┘
```

## ✅ MONITORING CHECKLIST - Never Missing Metrics Again!

### 1️⃣ TALOS SYSTEM COMPONENTS
```yaml
# Already monitored via prometheus-operator ServiceMonitors:
✅ kubelet           - prometheus-operator-kube-p-kubelet
✅ kube-apiserver    - prometheus-operator-kube-p-apiserver
✅ kube-scheduler    - prometheus-operator-kube-p-kube-scheduler
✅ kube-controller   - prometheus-operator-kube-p-kube-controller-manager
✅ etcd              - prometheus-operator-kube-p-kube-etcd
✅ kube-proxy        - prometheus-operator-kube-p-kube-proxy
✅ node-exporter     - prometheus-operator-prometheus-node-exporter

# Talos-specific configuration required:
controllerManager:
  extraArgs:
    bind-address: 0.0.0.0  # Required for metrics exposure
scheduler:
  extraArgs:
    bind-address: 0.0.0.0  # Required for metrics exposure
```

### 2️⃣ APPLICATION MONITORING PATTERNS

#### **Pattern A: Sidecar Exporter (RECOMMENDED)**
```yaml
# Example: Redis in ArgoCD
redis:
  exporter:
    enabled: true
    image:
      repository: ghcr.io/oliver006/redis_exporter
      tag: v1.65.0
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
```

**Advantages:**
- No separate deployment needed
- Automatic service discovery
- Shared network namespace (localhost access)
- Lifecycle managed by parent application

#### **Pattern B: Standalone Exporter Deployment**
```yaml
# When sidecar not possible (e.g., managed services)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-exporter
spec:
  template:
    spec:
      containers:
      - name: exporter
        image: appropriate/exporter:latest
        env:
        - name: SERVICE_ENDPOINT
          value: "service.namespace:port"
```

#### **Pattern C: Native Metrics Endpoint**
```yaml
# Applications with built-in metrics (e.g., ArgoCD, Cilium)
# Just create ServiceMonitor/VMServiceScrape
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: service-name
  endpoints:
  - port: metrics
    path: /metrics
```

## 🎯 COMPLETE APPLICATION MONITORING

### **Infrastructure Layer**
```yaml
# ArgoCD (GitOps)
✅ argocd-server         - Native /metrics endpoint
✅ argocd-controller     - Native /metrics endpoint
✅ argocd-repo-server    - Native /metrics endpoint
✅ argocd-redis          - Sidecar exporter pattern
✅ argocd-applicationset - Native /metrics endpoint

# Cert-Manager (Certificates)
✅ cert-manager          - Native /metrics endpoint

# Cilium (CNI)
✅ cilium-agent          - Native /metrics endpoint
✅ cilium-operator       - Native /metrics endpoint
✅ hubble                - Native /metrics endpoint

# Istio (Service Mesh)
✅ istiod                - Native /metrics on :15014
✅ istio-proxy           - Native /metrics on :15090

# Rook-Ceph (Storage)
✅ ceph-exporter         - Built-in exporters per node
✅ ceph-mgr              - Native Prometheus module
```

### **Platform Layer**
```yaml
# Elasticsearch (Logging)
✅ elasticsearch         - elasticsearch-exporter deployment
✅ kibana                - Native /api/stats endpoint

# PostgreSQL (CloudNativePG)
✅ cnpg-clusters         - Native metrics via operator

# Vector (Log Aggregation)
✅ vector-agent          - Native /metrics endpoint
✅ vector-aggregator     - Native /metrics endpoint

# Velero (Backup)
✅ velero                - Native /metrics endpoint
```

### **Monitoring Stack**
```yaml
# VictoriaMetrics
✅ vmagent               - Native /metrics endpoint
✅ vmselect              - Native /metrics endpoint
✅ vminsert              - Native /metrics endpoint
✅ vmstorage             - Native /metrics endpoint

# Grafana
✅ grafana               - Native /metrics endpoint

# Loki
✅ loki                  - Native /metrics endpoint
✅ promtail              - Native /metrics endpoint

# AlertManager
✅ alertmanager          - Native /metrics endpoint
```

## 🔧 VMSERVICESCRAPE TEMPLATE

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: service-name
  namespace: monitoring
  annotations:
    argocd.argoproj.io/sync-wave: "5"  # After VMAgent
spec:
  # Target Selection
  selector:
    matchLabels:
      app.kubernetes.io/name: service-name

  # Namespace Selection
  namespaceSelector:
    matchNames:
      - target-namespace

  # Scrape Configuration
  endpoints:
    - port: "metrics"     # Port name or number
      path: "/metrics"    # Metrics path
      interval: "30s"     # Scrape interval
      scrapeTimeout: "10s"

      # Metric Filtering & Relabeling
      metricRelabelConfigs:
        # Keep only relevant metrics
        - sourceLabels: [__name__]
          regex: "service_.*"
          action: keep

        # Add standard labels
        - targetLabel: cluster
          replacement: "homelab"
        - targetLabel: environment
          replacement: "production"
```

## 📈 PERFORMANCE OPTIMIZATION

### **VMAgent Configuration**
```yaml
spec:
  selectAllByDefault: true              # Auto-discover all ServiceMonitors
  serviceScrapeNamespaceSelector: {}    # All namespaces
  podScrapeNamespaceSelector: {}        # All namespaces

  # Resource allocation
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi

  # Scraping performance
  extraArgs:
    promscrape.maxScrapeSize: "16MB"
    promscrape.streamParse: "true"      # Stream parsing for large responses
```

### **VMCluster Sizing**
```yaml
# VMStorage (Time-series storage)
vmstorage:
  replicaCount: 1  # Increase for HA
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: "rook-ceph-block-enterprise"
        resources:
          requests:
            storage: 100Gi  # Adjust based on retention

# VMSelect (Query engine)
vmselect:
  replicaCount: 1  # Increase for query load distribution
  resources:
    requests:
      cpu: 200m
      memory: 512Mi

# VMInsert (Write buffer)
vminsert:
  replicaCount: 1  # Increase for write throughput
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
```

## 🛠️ TROUBLESHOOTING

### **No Data in Dashboard?**

1. **Check VMServiceScrape Status:**
```bash
kubectl get vmservicescrape -A
# Look for "operational" status
```

2. **Verify Target Discovery:**
```bash
# Port forward to VMAgent
kubectl port-forward -n monitoring svc/vmagent-vm-agent 8429:8429

# Check targets
curl http://localhost:8429/targets
```

3. **Test Metrics Endpoint:**
```bash
# Port forward to service
kubectl port-forward -n <namespace> svc/<service> <port>:<port>

# Test metrics
curl http://localhost:<port>/metrics
```

4. **Check VMAgent Logs:**
```bash
kubectl logs -n monitoring deployment/vmagent-vm-agent -f
```

### **Common Issues:**

| Issue | Solution |
|-------|----------|
| Service not discovered | Check ServiceMonitor labels match VMAgent selector |
| Authentication required | Add bearer token or basic auth to VMServiceScrape |
| Metrics missing | Check metricRelabelConfigs not dropping metrics |
| High cardinality | Add metric_relabel_configs to drop unnecessary labels |
| Slow queries | Increase VMSelect resources or add replicas |

## 🚀 MIGRATION FROM PROMETHEUS

1. **Keep Prometheus Running** during migration
2. **Deploy VictoriaMetrics** alongside
3. **VMAgent auto-converts** ServiceMonitors to VMServiceScrapes
4. **Update Grafana datasource** to VictoriaMetrics
5. **Verify all dashboards** work
6. **Remove Prometheus** after validation

## 📝 EXTERNAL TARGETS (Proxmox, TrueNAS)

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMStaticScrape
metadata:
  name: proxmox-nodes
  namespace: monitoring
spec:
  targetEndpoints:
    - targets:
      - "proxmox1.local:9100"  # node_exporter on Proxmox
      - "proxmox2.local:9100"
      labels:
        job: "proxmox"
        environment: "production"
```

## 🎨 KEY METRICS TO MONITOR

### **Golden Signals**
- **Latency**: Response time percentiles (p50, p95, p99)
- **Traffic**: Requests per second
- **Errors**: Error rate percentage
- **Saturation**: Resource utilization

### **Infrastructure Health**
- CPU usage < 80%
- Memory usage < 90%
- Disk usage < 85%
- Network errors < 0.01%
- Pod restart rate < 5/hour

### **Application SLIs**
- Availability > 99.9%
- Request success rate > 99%
- p99 latency < 1s
- Error budget consumption < 100%

---

**Remember:** VictoriaMetrics is a drop-in Prometheus replacement with:
- ✅ Better performance (10x compression)
- ✅ Lower resource usage
- ✅ Long-term storage support
- ✅ Multi-tenancy capabilities
- ✅ PromQL compatibility
- ✅ Native deduplication

Keep this document updated as you add new services!
