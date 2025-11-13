# 📊 Step-by-Step Monitoring Guide - From Zero to Hero

## 🎯 Overview
Complete guide for setting up monitoring from scratch with either VictoriaMetrics or Prometheus, then progressively adding everything you want to monitor.

---

## 🚀 Phase 1: Base Installation

### Option A: VictoriaMetrics (Recommended)
```bash
# 1. Install VM Operator
kubectl apply -f https://github.com/VictoriaMetrics/operator/releases/latest/download/bundle_crd.yaml

# 2. Create monitoring namespace
kubectl create namespace monitoring

# 3. Deploy VM Operator
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm install vm-operator vm/victoria-metrics-operator -n monitoring

# 4. Verify operator is running
kubectl get pods -n monitoring
```

### Option B: Prometheus (Alternative)
```bash
# 1. Install Prometheus Operator
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/latest/download/bundle.yaml

# 2. Create monitoring namespace
kubectl create namespace monitoring

# 3. Deploy Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

---

## 🔧 Phase 2: Core Monitoring Setup

### VictoriaMetrics Core Components

#### Step 1: Deploy VMCluster (Storage)
```yaml
# vmcluster.yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMCluster
metadata:
  name: vm-cluster
  namespace: monitoring
spec:
  retentionPeriod: "30d"
  vminsert:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
  vmselect:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
  vmstorage:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
```

#### Step 2: Deploy VMAgent (Collection)
```yaml
# vmagent.yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAgent
metadata:
  name: vm-agent
  namespace: monitoring
spec:
  # 📡 Remote write to VMCluster
  remoteWrite:
    - url: "http://vminsert-vm-cluster.monitoring.svc.cluster.local:8480/insert/0/prometheus/"

  # 🔧 Basic configuration
  scrapeInterval: "30s"
  scrapeTimeout: "10s"

  # 🎯 Enable automatic service discovery
  selectAllByDefault: true
  serviceScrapeNamespaceSelector: {}
  podScrapeNamespaceSelector: {}
```

#### Step 3: Verify Core Setup
```bash
# Check if all components are running
kubectl get vmcluster,vmagent -n monitoring

# Port forward to VMSelect for UI
kubectl port-forward -n monitoring svc/vmselect-vm-cluster 8481:8481

# Access UI at http://localhost:8481
```

---

## 🎯 Phase 3: Progressive Monitoring - What to Monitor

### Level 1: Infrastructure Monitoring (Must-Have)

#### 1. Kubernetes API Server
```yaml
# Already included in VMAgent by default
# Check targets: kubernetes-apiservers job
```

#### 2. Kubelet & cAdvisor (Node Metrics)
```yaml
# Add to VMAgent inlineScrapeConfig
inlineScrapeConfig: |
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
    - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true  # For homelab
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - source_labels: [__address__]
      action: replace
      target_label: __address__
      regex: ([^:]+):(.+)
      replacement: $1:10250
```

#### 3. Node Exporter (System Metrics)
```bash
# Deploy via DaemonSet
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install node-exporter prometheus-community/prometheus-node-exporter -n monitoring
```

### Level 2: Application Discovery (Easy Wins)

#### Auto-Discovery Pattern
```yaml
# Add universal service discovery to VMAgent
inlineScrapeConfig: |
  - job_name: 'kubernetes-service-endpoints'
    kubernetes_sd_configs:
    - role: endpoints
    relabel_configs:
    # Only scrape services with prometheus.io/scrape=true
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    # Use custom port if specified
    - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\\d+)?;(\\d+)
      replacement: $1:$2
      target_label: __address__
    # Use custom path if specified
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    # Skip known UI ports (CRITICAL!)
    - source_labels: [__meta_kubernetes_endpoint_port_name]
      action: drop
      regex: (ui|web|http|admin-http|console|query)
```

#### How to Add Any Service
```bash
# Example: Annotate your application service
kubectl annotate service my-app -n my-namespace \
  prometheus.io/scrape=true \
  prometheus.io/port=8080 \
  prometheus.io/path=/metrics
```

### Level 3: Specific Infrastructure Components

#### Database Monitoring (PostgreSQL Example)
```yaml
# Deploy Postgres Exporter
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: database
spec:
  selector:
    matchLabels:
      app: postgres-exporter
  template:
    metadata:
      labels:
        app: postgres-exporter
    spec:
      containers:
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:latest
        env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://user:password@postgres:5432/dbname?sslmode=disable"
        ports:
        - containerPort: 9187
          name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-exporter
  namespace: database
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9187"
spec:
  selector:
    app: postgres-exporter
  ports:
  - port: 9187
    name: metrics
```

#### Storage Monitoring (Ceph Example)
```yaml
# Ceph Manager already exposes metrics
kubectl annotate service rook-ceph-mgr -n rook-ceph \
  prometheus.io/scrape=true \
  prometheus.io/port=9283
```

#### Network Monitoring (Cilium Example)
```yaml
# Cilium Hubble metrics
kubectl annotate service hubble-metrics -n kube-system \
  prometheus.io/scrape=true \
  prometheus.io/port=9965
```

### Level 4: Application-Specific Monitoring

#### Custom Application Metrics
```bash
# Your app needs to expose /metrics endpoint
# Example in Go:
```

```go
// main.go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

```yaml
# Service with annotations
apiVersion: v1
kind: Service
metadata:
  name: my-custom-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: my-custom-app
  ports:
  - port: 8080
    name: metrics
```

---

## 🛠️ Phase 4: Advanced Patterns

### VMServiceScrape for Complex Cases
```yaml
# For services that need custom scraping logic
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: my-complex-service
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-complex-service
  endpoints:
  - port: metrics
    path: /custom/metrics/path
    interval: 15s
    scrapeTimeout: 10s
    params:
      format: ['prometheus']
```

### Multi-Cluster Monitoring
```yaml
# VMAgent for remote cluster
spec:
  remoteWrite:
    - url: "http://central-vminsert.monitoring.example.com/insert/0/prometheus/"
      basicAuth:
        username:
          name: remote-auth
          key: username
        password:
          name: remote-auth
          key: password
  externalLabels:
    cluster: "production-east"
    environment: "prod"
```

---

## 🔍 Phase 5: Monitoring Your Monitoring

### VMAgent Health Checks
```bash
# Check VMAgent logs
kubectl logs -n monitoring deployment/vmagent-vm-agent

# Check targets status
curl http://localhost:8429/targets

# Check configuration
curl http://localhost:8429/config
```

### Common Issues & Solutions

#### Problem: Service not being scraped
```bash
# 1. Check service annotations
kubectl get service my-service -o yaml | grep annotations -A 5

# 2. Check if VMAgent can reach the service
kubectl exec -n monitoring deployment/vmagent-vm-agent -- wget -O- http://my-service.my-namespace:8080/metrics

# 3. Check VMAgent targets
kubectl port-forward -n monitoring svc/vmagent-vm-agent 8429:8429
# Visit http://localhost:8429/targets
```

#### Problem: HTML parsing errors
```bash
# Check if service returns Prometheus format
curl http://my-service:8080/metrics

# Should return:
# metric_name{label="value"} 1.0
# NOT HTML like: <html><body>...</body></html>
```

#### Problem: TLS/Certificate issues
```yaml
# Add TLS skip for internal services
tls_config:
  insecure_skip_verify: true
```

---

## 📋 Complete Checklist

### Infrastructure ✅
- [ ] Kubernetes API Server metrics
- [ ] Kubelet/cAdvisor metrics (nodes)
- [ ] Node Exporter (system metrics)
- [ ] CoreDNS metrics
- [ ] Etcd metrics (if accessible)

### Storage ✅
- [ ] Persistent Volume metrics
- [ ] Storage class metrics
- [ ] Ceph/Storage backend metrics

### Network ✅
- [ ] Cilium/CNI metrics
- [ ] Ingress controller metrics
- [ ] Service mesh metrics (if used)

### Applications ✅
- [ ] Database metrics (PostgreSQL, MongoDB, etc.)
- [ ] Message queue metrics (Kafka, RabbitMQ, etc.)
- [ ] Cache metrics (Redis, Memcached, etc.)
- [ ] Custom application metrics

### Monitoring Stack ✅
- [ ] VMAgent metrics (monitoring the monitor)
- [ ] VMCluster metrics
- [ ] Grafana metrics
- [ ] AlertManager metrics

---

## 🎯 Pro Tips

1. **Start Small**: Begin with infrastructure, then add applications progressively
2. **Use Annotations**: `prometheus.io/scrape=true` is the universal pattern
3. **Filter UI Ports**: Always exclude web/ui/console ports from scraping
4. **Test Endpoints**: Always `curl /metrics` before adding to monitoring
5. **Monitor Your Monitoring**: VMAgent must monitor itself
6. **Use Labels**: Add environment/cluster labels for multi-cluster setups
7. **Documentation**: Keep track of what each metric means and why you monitor it

## 🚀 Result
Progressive monitoring setup that scales from basic infrastructure to comprehensive observability across your entire stack!
