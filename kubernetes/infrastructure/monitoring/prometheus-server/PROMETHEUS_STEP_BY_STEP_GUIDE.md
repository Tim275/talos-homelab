# 📊 Prometheus Step-by-Step Monitoring Guide - From Zero to Hero

## 🎯 Overview
Complete guide for setting up **native Prometheus monitoring** from scratch, then progressively adding everything you want to monitor. This is the **Prometheus equivalent** to our VictoriaMetrics universal monitoring solution.

---

## 🚀 Phase 1: Base Prometheus Installation

### Option A: Helm Chart (Recommended)
```bash
# 1. Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Create monitoring namespace
kubectl create namespace monitoring

# 3. Deploy Prometheus with our values
helm install prometheus-server prometheus-community/prometheus \
  -n monitoring \
  -f values.yaml
```

### Option B: Prometheus Operator
```bash
# Alternative: Use Prometheus Operator
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/latest/download/bundle.yaml

# Deploy using CRDs
kubectl apply -f prometheus-crd.yaml
```

---

## 🔧 Phase 2: Core Prometheus Setup

### Our Current Configuration Analysis
Based on your existing `values.yaml`, you already have:

#### ✅ **Infrastructure Components**
- **Prometheus Server**: Main metrics collection and storage
- **Node Exporter**: System-level metrics from all nodes (`hostNetwork: true` for Talos)
- **Kube State Metrics**: Kubernetes object state metrics
- **Pushgateway**: For batch job metrics

#### ✅ **Storage & Resources**
```yaml
server:
  persistentVolume:
    enabled: true
    size: 100Gi
    storageClass: rook-ceph-block
  resources:
    requests: {cpu: 200m, memory: 1Gi}
    limits: {cpu: 1000m, memory: 2Gi}
```

#### ✅ **Service Discovery Jobs**
1. **prometheus** - Self-monitoring
2. **kubernetes-nodes** - Node Exporter metrics
3. **kubernetes-pods** - Pod-level discovery

---

## 🎯 Phase 3: Universal Service Discovery Pattern

### Enhance Your Prometheus Config
Add this to your `values.yaml` under `scrape_configs`:

```yaml
# 🌍 UNIVERSAL KUBERNETES SERVICE DISCOVERY
- job_name: 'kubernetes-service-endpoints'
  kubernetes_sd_configs:
  - role: endpoints
  relabel_configs:
  # Only scrape services with prometheus.io/scrape=true
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  # Use custom scheme if specified
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
    action: replace
    target_label: __scheme__
    regex: (https?)
    replacement: ${1}
  # Use custom path if specified
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
    replacement: ${1}
  # Use custom port if specified
  - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\\d+)?;(\\d+)
    replacement: $1:$2
    target_label: __address__
  # 🚫 CRITICAL: Skip known UI ports (prevents HTML parsing errors)
  - source_labels: [__meta_kubernetes_endpoint_port_name]
    action: drop
    regex: (ui|web|http|admin-http|console|query)
  # 🚫 Skip services without explicit metrics intent
  - source_labels: [__meta_kubernetes_service_name]
    action: drop
    regex: (jaeger-query|redpanda-console|.*-ui|.*-web)
  # Add useful labels
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_service_name]
    action: replace
    target_label: kubernetes_name

# 🔍 KUBERNETES API SERVER
- job_name: 'kubernetes-apiservers'
  kubernetes_sd_configs:
  - role: endpoints
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: false
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
  - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
    action: keep
    regex: default;kubernetes;https

# 📊 KUBERNETES CADVISOR (container metrics)
- job_name: 'kubernetes-cadvisor'
  kubernetes_sd_configs:
  - role: node
  scheme: https
  metrics_path: /metrics/cadvisor
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true  # For homelab environments
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
  - source_labels: [__address__]
    action: replace
    target_label: __address__
    regex: ([^:]+):(.+)
    replacement: $1:10250  # Kubelet metrics port

# 🔍 ENHANCED KUBELET METRICS
- job_name: 'kubernetes-kubelet'
  kubernetes_sd_configs:
  - role: node
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
  - source_labels: [__address__]
    action: replace
    target_label: __address__
    regex: ([^:]+):(.+)
    replacement: $1:10250
```

---

## 📋 Phase 4: Progressive Monitoring - What to Monitor

### Level 1: Infrastructure Monitoring (Must-Have)

#### ✅ Already Configured (Your Setup)
- **Kubernetes API Server** ✅
- **Kubelet & cAdvisor** ✅
- **Node Exporter** ✅
- **Kube State Metrics** ✅

#### Add These Infrastructure Components:
```bash
# CoreDNS metrics (if using CoreDNS)
kubectl patch configmap coredns -n kube-system --patch '
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }'

# Annotate CoreDNS service for scraping
kubectl annotate service kube-dns -n kube-system \
  prometheus.io/scrape=true \
  prometheus.io/port=9153
```

### Level 2: Application Discovery (Easy Wins)

#### Universal Service Annotation Pattern
```bash
# Example: Annotate ANY service for automatic discovery
kubectl annotate service my-app -n my-namespace \
  prometheus.io/scrape=true \
  prometheus.io/port=8080 \
  prometheus.io/path=/metrics
```

#### Applications with Built-in Metrics:
```bash
# Istio Control Plane
kubectl annotate service istiod -n istio-system \
  prometheus.io/scrape=true \
  prometheus.io/port=15014

# Cilium Hubble
kubectl annotate service hubble-metrics -n kube-system \
  prometheus.io/scrape=true \
  prometheus.io/port=9965

# Rook Ceph Manager
kubectl annotate service rook-ceph-mgr -n rook-ceph \
  prometheus.io/scrape=true \
  prometheus.io/port=9283
```

### Level 3: ServiceMonitor CRDs (Prometheus Operator)

If using Prometheus Operator, create ServiceMonitors:

```yaml
# Infrastructure ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: infrastructure-services
  namespace: monitoring
spec:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    any: true
```

### Level 4: Specific Infrastructure Components

#### Database Monitoring (PostgreSQL Example)
```yaml
# PostgreSQL Exporter Deployment
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
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
    spec:
      containers:
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:latest
        env:
        - name: DATA_SOURCE_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-exporter-secret
              key: data-source-name
        ports:
        - containerPort: 9187
          name: metrics
```

#### Message Queue Monitoring (Kafka Example)
```bash
# Kafka already has built-in JMX metrics
# Use Kafka Exporter for Prometheus format
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kafka-exporter prometheus-community/prometheus-kafka-exporter \
  --set kafkaServer="{kafka-broker-1:9092,kafka-broker-2:9092}" \
  --set annotations."prometheus\.io/scrape"="true" \
  --set annotations."prometheus\.io/port"="9308"
```

---

## 🔍 Phase 5: Monitoring Your Monitoring

### Prometheus Health Checks
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Visit http://localhost:9090/targets

# Check configuration
curl http://localhost:9090/api/v1/status/config

# Check rules
curl http://localhost:9090/api/v1/rules
```

### Query Examples
```promql
# Infrastructure Health
up == 0  # Down targets

# Node Resources
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10

# Pod Resources
container_memory_usage_bytes{container!="POD",container!=""} / container_spec_memory_limit_bytes > 0.8

# API Server Health
apiserver_request_duration_seconds_bucket{le="1"}
```

---

## 🛠️ Phase 6: Troubleshooting Common Issues

### Problem: Service not being scraped
```bash
# 1. Check service annotations
kubectl get service my-service -o yaml | grep -A 5 annotations

# 2. Check Prometheus targets page
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Visit http://localhost:9090/targets and search for your service

# 3. Check if service returns Prometheus format
kubectl exec -n monitoring deployment/prometheus-server -- \
  wget -O- http://my-service.my-namespace:8080/metrics

# Should return:
# metric_name{label="value"} 1.0
# NOT HTML: <html><body>...</body></html>
```

### Problem: HTML parsing errors (like our VictoriaMetrics experience)
```yaml
# Add these filters to your scrape_configs
relabel_configs:
# Skip known UI ports
- source_labels: [__meta_kubernetes_endpoint_port_name]
  action: drop
  regex: (ui|web|http|admin-http|console|query)
# Skip UI services
- source_labels: [__meta_kubernetes_service_name]
  action: drop
  regex: (jaeger-query|redpanda-console|.*-ui|.*-web)
```

### Problem: TLS/Certificate issues with kubelet
```yaml
# For homelab environments, add TLS skip
tls_config:
  insecure_skip_verify: true
```

---

## 📊 Phase 7: Prometheus vs VictoriaMetrics Comparison

### **Prometheus Advantages:**
✅ **Native Kubernetes Integration** - No operator complexity
✅ **PromQL Standard** - Industry standard query language
✅ **Rich Ecosystem** - Largest monitoring ecosystem
✅ **ServiceMonitor CRDs** - Clean Kubernetes-native configuration
✅ **Recording Rules** - Pre-computed metrics for performance

### **Prometheus Limitations:**
❌ **High Memory Usage** - Can be resource-intensive
❌ **Single Node** - No built-in clustering
❌ **Limited Retention** - Typically 15 days locally
❌ **Slower Queries** - For large datasets

### **When to Choose Prometheus:**
- **Standard Kubernetes environments**
- **Rich ecosystem requirements** (AlertManager, Grafana, etc.)
- **ServiceMonitor workflow preferred**
- **Memory/storage not constrained**

### **When to Choose VictoriaMetrics:**
- **Large scale deployments** (millions of metrics)
- **Long-term retention requirements**
- **Memory/cost optimization critical**
- **Prometheus drop-in replacement needed**

---

## 📋 Complete Monitoring Checklist (Prometheus)

### Infrastructure ✅
- [ ] Kubernetes API Server (built-in)
- [ ] Kubelet/cAdvisor (values.yaml)
- [ ] Node Exporter (values.yaml)
- [ ] Kube State Metrics (values.yaml)
- [ ] CoreDNS (annotation)
- [ ] Etcd (if accessible)

### Network ✅
- [ ] Cilium/CNI metrics
- [ ] Istio control plane
- [ ] Ingress controller metrics

### Storage ✅
- [ ] Persistent Volume metrics
- [ ] Ceph/Storage backend metrics
- [ ] CSI driver metrics

### Applications ✅
- [ ] Database exporters
- [ ] Message queue metrics
- [ ] Cache metrics (Redis, etc.)
- [ ] Custom application metrics

### Monitoring Stack ✅
- [ ] Prometheus self-monitoring
- [ ] AlertManager metrics
- [ ] Grafana metrics

---

## 🎯 Pro Tips for Prometheus

1. **Start with Universal Discovery**: Use `kubernetes-service-endpoints` job
2. **Filter UI Ports**: Always exclude web/ui/console ports
3. **Use ServiceMonitors**: For Prometheus Operator environments
4. **Monitor the Monitor**: Prometheus must monitor itself
5. **Recording Rules**: Pre-compute expensive queries
6. **Federation**: For multi-cluster setups
7. **Remote Storage**: For long-term retention (Thanos, Cortex)

## 🚀 Result
Progressive Prometheus monitoring setup that scales from basic infrastructure to comprehensive observability - **the native Kubernetes way!**
