# 📊 Monitoring Best Practices - Grafana Blog & Industry Guides

**Curated Collection**: Wie die Enterprise deine Stack-Komponenten monitored

---

## 🎯 **Inspiration: GitLab CI/CD Observability**

**Article**: [A serverless approach to CI/CD observability with GitLab and Grafana](https://grafana.com/blog/2025/10/10/a-serverless-approach-to-ci-cd-observability-with-gitlab-and-grafana/)

**Key Patterns**:
```yaml
What they monitor:
  ├─ Pipeline success/failure rates (real-time)
  ├─ Deployment frequency & timing
  ├─ Code changes correlated with system performance
  └─ Build duration variations by project

Approach:
  ├─ GitLab webhooks → AWS Lambda → Grafana Loki
  ├─ Treating CI/CD events as structured logs (not isolated metrics)
  ├─ Deployment markers on application dashboards
  └─ Event correlation: commits + deployments + system behavior

Best Practice:
  "The lines between application monitoring, infrastructure observability,
   and CI/CD tracking continue to blur."
```

**Why this matters**:
- ✅ Unified observability (nicht 5 separate Tools!)
- ✅ Deployment events als Grafana Annotations
- ✅ Correlate deploys with performance changes
- ✅ Single pane of glass für Dev + Ops

---

## 🔹 **ArgoCD GitOps Monitoring**

### 📖 **Official Grafana Guide**

**Article**: [How to use Argo CD to configure Kubernetes Monitoring in Grafana Cloud](https://grafana.com/blog/2023/05/23/how-to-use-argo-cd-to-configure-kubernetes-monitoring-in-grafana-cloud/) (2023)

**Key Points**:
```yaml
GitOps-Native Monitoring:
  ├─ Dashboards as Code (Git repository)
  ├─ ArgoCD synchronizes dashboards to Grafana
  ├─ Grafana Operator manages Grafana instance
  └─ No manual dashboard imports!

Metrics to Monitor:
  ├─ Application sync status (OutOfSync, Synced, Healthy)
  ├─ Sync frequency & duration
  ├─ Failed syncs & auto-heal events
  └─ Drift detection (cluster vs Git)
```

### 📈 **ArgoCD Dashboards**

**Dashboard**: [ArgoCD Overview V3](https://grafana.com/grafana/dashboards/24192-argocd-overview/) (2024)

**Metrics**:
- `argocd_app_info` - Application metadata
- `argocd_app_sync_total` - Sync operations count
- `argocd_app_k8s_request_total` - Kubernetes API calls

**Alerts**:
```promql
# Application OutOfSync > 15 minutes
argocd_app_info{sync_status="OutOfSync"} == 1

# Application Degraded
argocd_app_info{health_status="Degraded"} == 1
```

**Your Setup**:
```yaml
Opportunity:
  ├─ 30+ ArgoCD Applications deployed
  ├─ GitOps für ALLES (infrastructure + apps)
  └─ Missing: Deployment annotations in Grafana!

TODO:
  ├─ Add ArgoCD Dashboard (24192)
  ├─ Configure ArgoCD → Grafana annotations
  │  (z.B. "n8n-prod deployed at 14:23")
  └─ Alert on OutOfSync > 15min
```

---

## 🐘 **PostgreSQL (CNPG) Monitoring**

### 📖 **Giant Swarm Production Guide**

**Article**: [Making Grafana remember: our journey to persistence with Grafana and PostgreSQL](https://www.giantswarm.io/blog/making-grafana-remember-our-journey-to-persistence-with-grafana-and-postgresql) (2 weeks ago!)

**Best Practices**:
```yaml
Key Metrics:
  ├─ Connection Pool Utilization
  │  └─ Alert: > 80% = scale replicas!
  ├─ Replication Lag (Primary → Standby)
  │  └─ Alert: > 10s = investigate!
  ├─ WAL Archive Status
  │  └─ Failed backups = disaster risk!
  └─ Query Performance (slow queries)

CNPG-Specific:
  ├─ Failover events (Primary switch)
  ├─ Backup success/failure rate
  ├─ PVC disk usage (Rook-Ceph)
  └─ Fencing state (split-brain prevention)
```

### 📈 **Official CNPG Dashboard**

**Dashboard**: [PostgreSQL Database (CNPG)](https://grafana.com/grafana/dashboards/20417-postgresql-database/)

**Your Setup**:
```yaml
Current:
  ├─ n8n-prod PostgreSQL (CNPG cluster)
  ├─ n8n-dev PostgreSQL (single instance)
  ├─ Keycloak PostgreSQL
  └─ Infisical PostgreSQL

Monitoring Status:
  ✅ Metrics exposed (CNPG Operator)
  ❌ Dashboard nicht deployed!
  ❌ Alerts nicht konfiguriert!

TODO:
  ├─ Deploy CNPG Dashboard (20417)
  ├─ Add alerts: Replication lag, connection pool
  └─ Backup monitoring (Velero S3)
```

---

## 📨 **Kafka (Strimzi) Monitoring**

### 📖 **Grafana Formula 1 Telemetry Guide**

**Article**: [Real-time monitoring of Formula 1 telemetry data on Kubernetes with Grafana, Apache Kafka, and Strimzi](https://grafana.com/blog/2021/02/02/real-time-monitoring-of-formula-1-telemetry-data-on-kubernetes-with-grafana-apache-kafka-and-strimzi/)

**Key Patterns**:
```yaml
Kafka-Specific Metrics:
  ├─ Consumer Lag (CRITICAL!)
  │  └─ "How far behind is consumer from producer?"
  ├─ Broker Health (online/offline)
  ├─ Topic Throughput (messages/sec)
  ├─ Replication Factor (under-replicated partitions)
  └─ Disk Usage (log retention)

JMX Exporter:
  ├─ Strimzi auto-deploys JMX Exporter sidecar
  ├─ Exposes Kafka metrics to Prometheus
  └─ No manual configuration needed!
```

### 📈 **Strimzi Dashboards**

**Dashboard**: [Strimzi Kafka Exporter](https://grafana.com/grafana/dashboards/11285-strimzi-kafka-exporter/)

**Critical Alerts**:
```promql
# Consumer Lag > 1000 messages
kafka_consumergroup_lag > 1000

# Under-replicated partitions
kafka_topic_partition_under_replicated_partition > 0

# Offline brokers
kafka_brokers_online < 3
```

**Your Setup**:
```yaml
Current:
  ├─ Strimzi Kafka Cluster (3 brokers)
  ├─ Kafka Connect (experimental)
  └─ Redpanda Console (UI)

TODO:
  ├─ Deploy Strimzi Dashboard (11285)
  ├─ Configure Consumer Lag alerts
  └─ Monitor: n8n Kafka integration (wenn deployed)
```

---

## 🔭 **OpenTelemetry Best Practices**

### 📖 **Official Grafana OTel Guide**

**Article**: [OpenTelemetry best practices: A user's guide to getting started](https://grafana.com/blog/2023/12/18/opentelemetry-best-practices-a-users-guide-to-getting-started-with-opentelemetry/)

**Key Insights**:
```yaml
Best Practices:
  ├─ Use Grafana Agent (not raw OTel Collector)
  │  └─ "Grafana Agent is built on OTel Collector + optimized"
  ├─ Generate metrics from spans BEFORE tail sampling
  │  └─ Accurate request counts even with 10% sampling!
  ├─ Use semantic conventions (service.name, deployment.environment)
  └─ Instrument at SDK level + Sidecar level (both!)

Sampling Strategy:
  ├─ Head Sampling: Simple but loses rare errors
  ├─ Tail Sampling: Complex but catches errors
  └─ Recommended: Probabilistic (10%) + Error-based (100%)
```

### 📖 **What's New in 2025**

**Article**: [OpenTelemetry and Grafana Labs: what's new and what's next in 2025](https://grafana.com/blog/2025/01/07/opentelemetry-and-grafana-labs-whats-new-and-whats-next-in-2025/)

**Industry Trends**:
```yaml
Adoption:
  ├─ 89% using Prometheus
  ├─ 85% using OpenTelemetry
  └─ 40% using BOTH (overlap!)

New in 2024/2025:
  ├─ Profiling support (CPU, Memory profiles via OTel)
  ├─ Spring Boot Starter (stable!)
  └─ 100% increase in Google search volume

Integration:
  ├─ Loki (logs) + Tempo (traces) + Mimir (metrics) + Pyroscope (profiling)
  └─ "Single pane of glass" für ALLE Signale
```

### 📖 **Kubernetes + OpenTelemetry**

**Article**: [Leveraging OpenTelemetry and Grafana for observing Kubernetes applications](https://grafana.com/blog/2024/11/22/leveraging-opentelemetry-and-grafana-for-observing-visualizing-and-monitoring-kubernetes-applications/)

**Architecture**:
```yaml
┌────────────────────────────────────────────────────┐
│ Application (N8N, Microservices)                   │
│ └─ OpenTelemetry SDK (OTLP)                        │
└────────────────────────────────────────────────────┘
              ↓ OTLP (traces, metrics, logs)
┌────────────────────────────────────────────────────┐
│ OpenTelemetry Collector (DaemonSet)                │
│ ├─ Batch Processor (efficiency)                    │
│ ├─ Resource Detection (k8s.pod.name, namespace)    │
│ └─ Tail Sampling (catch errors, 10% normal)        │
└────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────┐
│ Grafana Stack                                      │
│ ├─ Tempo (traces) ← Elasticsearch (your setup)    │
│ ├─ Loki (logs) ← S3                                │
│ ├─ Mimir (metrics) ← Prometheus                    │
│ └─ Pyroscope (profiling)                           │
└────────────────────────────────────────────────────┘
```

**Your Setup**:
```yaml
Current:
  ✅ OpenTelemetry Collector (DaemonSet) deployed
  ✅ Jaeger backend (Elasticsearch)
  ✅ OTLP endpoints (4317, 4318)
  ❌ No app instrumentation yet!

Best Practice Alignment:
  ├─ ✅ Batch processing (1s, 1024 batch size)
  ├─ ✅ Memory limiter (400MB)
  ├─ ✅ Resource attributes (cluster label)
  └─ ⏳ TODO: Tail sampling (catch errors)

When you instrument apps:
  ├─ Use OpenTelemetry SDK (Python, Node.js)
  ├─ Set semantic attributes (service.name, deployment.environment)
  └─ Traces will flow automatically to Jaeger!
```

---

## 🏗️ **Talos Linux Monitoring**

### 📖 **Community Best Practices**

**Article**: [Talos OS Raspberry PI: Prometheus and Grafana](https://blog.devops.dev/talos-os-raspberry-fc5f327b7026) (2024)

**Talos-Specific Metrics**:
```yaml
Node-Level:
  ├─ Kubelet metrics (cAdvisor)
  ├─ System services (etcd, containerd, kubelet)
  ├─ Disk I/O (Rook-Ceph critical!)
  └─ Network throughput (Cilium)

Control Plane Health:
  ├─ etcd cluster health (quorum)
  ├─ API Server latency
  ├─ Scheduler performance
  └─ Controller Manager lag

Talos API Metrics:
  ├─ Machine config status
  ├─ Upgrade status (version drift)
  └─ Certificate expiration
```

### 📈 **Kube-Prometheus-Stack**

**Your Setup**:
```yaml
Deployed:
  ✅ Kube-Prometheus-Stack (Prometheus Operator)
  ✅ 50+ pre-built dashboards
  ✅ Grafana + Alertmanager
  ✅ ServiceMonitors for auto-discovery

Best Dashboards for Talos:
  ├─ Kubernetes / Compute Resources / Cluster
  ├─ Kubernetes / Compute Resources / Namespace (Pods)
  ├─ Kubernetes / USE Method / Cluster (Utilization, Saturation, Errors)
  └─ etcd (Control Plane Health)

TODO:
  ├─ Review all 50 dashboards (welche sind relevant?)
  ├─ Add custom Talos dashboard (machine config status)
  └─ Alert: etcd cluster health
```

---

## 🗄️ **Rook-Ceph Storage Monitoring**

### 📖 **Rook Documentation**

**Guide**: [Rook Ceph Monitoring](https://rook.io/docs/rook/latest/Storage-Configuration/Monitoring/ceph-monitoring/)

**Critical Metrics**:
```yaml
Cluster Health:
  ├─ HEALTH_OK / HEALTH_WARN / HEALTH_ERR
  ├─ OSDs up/down status (disk failures!)
  ├─ MON quorum (control plane)
  └─ MGR failover events

Performance:
  ├─ Read/Write IOPS per pool
  ├─ Latency (RBD vs CephFS vs RGW)
  ├─ PG (Placement Group) states
  └─ Scrubbing/deep-scrubbing progress

Capacity:
  ├─ Used vs Available (per pool)
  ├─ PVC growth rate (predict exhaustion!)
  └─ Object count (S3 buckets)
```

### 📈 **Ceph Dashboards**

**Dashboard**: [Ceph Cluster](https://grafana.com/grafana/dashboards/2842-ceph-cluster/)

**Alerts**:
```promql
# Ceph cluster not healthy
ceph_health_status != 0

# OSD down
ceph_osd_up == 0

# Disk space < 15%
ceph_cluster_total_bytes - ceph_cluster_total_used_bytes < 0.15 * ceph_cluster_total_bytes
```

**Your Setup**:
```yaml
Current:
  ├─ Rook-Ceph v1.16.0
  ├─ 3 OSDs (NVMe disks)
  ├─ Block (RBD) + Object (RGW) + Filesystem (CephFS)
  └─ 30+ PVCs (PostgreSQL, Redis, etc.)

Monitoring Status:
  ✅ Ceph metrics exposed (Prometheus)
  ❌ Dashboard nicht konfiguriert!
  ❌ Capacity alerts fehlen!

TODO:
  ├─ Deploy Ceph Dashboard (2842)
  ├─ Alert: OSD down, cluster degraded
  └─ Capacity planning (PVC growth rate)
```

---

## 🌐 **Istio Service Mesh Monitoring**

### 📖 **Istio Official Docs**

**Guide**: [Visualizing Your Mesh](https://istio.io/latest/docs/tasks/observability/metrics/querying-metrics/)

**Golden Signals**:
```yaml
Request Rate:
  ├─ istio_requests_total (per service)
  └─ Breakdown: source, destination, response_code

Latency:
  ├─ istio_request_duration_milliseconds (histogram)
  └─ p50, p90, p99 latencies

Error Rate:
  ├─ 4xx errors (client errors)
  ├─ 5xx errors (server errors)
  └─ Connection failures

Saturation:
  ├─ Concurrent connections
  └─ Circuit breaker trips
```

### 📈 **Kiali Dashboard**

**Your Setup**:
```yaml
Deployed:
  ✅ Istio v1.27.1 (3 istiod replicas)
  ✅ Kiali (Service Mesh UI)
  ✅ Sail Operator

Kiali Features:
  ├─ Service graph (visual topology)
  ├─ Traffic flow (request paths)
  ├─ mTLS status (per workload)
  └─ Configuration validation (VirtualService errors)

When you deploy microservices:
  ├─ Namespace label: istio-injection=enabled
  ├─ Services auto-get sidecars
  └─ Metrics flow to Prometheus automatically!
```

---

## 📝 **Summary: Your Monitoring Roadmap**

### ✅ **Already Deployed**

```yaml
Foundation:
  ✅ Prometheus (Kube-Prometheus-Stack)
  ✅ Grafana (50+ dashboards)
  ✅ Alertmanager (3 tiers)
  ✅ OpenTelemetry Collector (DaemonSet)
  ✅ Jaeger (Elasticsearch backend)
  ✅ Kiali (Istio mesh visualization)
```

### ⏳ **Missing / TODO**

```yaml
High Priority:
  ├─ ArgoCD Dashboard + deployment annotations
  ├─ PostgreSQL (CNPG) Dashboard + replication alerts
  ├─ Kafka (Strimzi) Dashboard + consumer lag alerts
  └─ Rook-Ceph Dashboard + capacity alerts

Medium Priority:
  ├─ Custom Talos dashboard (machine config status)
  ├─ OpenTelemetry tail sampling (error-based)
  └─ Istio golden signals (when microservices deployed)

Low Priority:
  ├─ Cleanup unused dashboards (50 ist zu viel!)
  ├─ Dashboard as Code (ArgoCD GitOps)
  └─ Grafana annotations from ArgoCD webhooks
```

### 🎯 **Best Practice Patterns (learned from articles)**

```yaml
1. Unified Observability:
   └─ GitLab Artikel: CI/CD events + app metrics auf EINEM Dashboard!
      Apply to: ArgoCD deploys + N8N performance auf 1 Dashboard

2. Deployment Markers:
   └─ Deployments als Grafana Annotations
      "N8N v2.0 deployed at 14:23" → sehe Performance impact!

3. Event Correlation:
   └─ Correlate: Git commit → ArgoCD sync → Pod restart → Latency spike
      Full story in one view!

4. Structured Logging:
   └─ Treat events as logs (not just metrics)
      ArgoCD sync events → Loki → Grafana queries

5. Proactive Alerts:
   └─ Alert BEFORE failure:
      - Replication lag > 10s (not when broken!)
      - Disk space < 15% (not when full!)
      - Consumer lag growing (not when backlog huge!)
```

---

## 📚 **Full Article List**

### Grafana Official Blog

1. **CI/CD Observability** (2025-10-10)
   https://grafana.com/blog/2025/10/10/a-serverless-approach-to-ci-cd-observability-with-gitlab-and-grafana/

2. **ArgoCD Kubernetes Monitoring** (2023-05-23)
   https://grafana.com/blog/2023/05/23/how-to-use-argo-cd-to-configure-kubernetes-monitoring-in-grafana-cloud/

3. **Grafana Operator & GitOps** (2024-01-25)
   https://grafana.com/blog/2024/01/25/how-to-manage-grafana-instances-within-kubernetes/

4. **OpenTelemetry Best Practices** (2023-12-18)
   https://grafana.com/blog/2023/12/18/opentelemetry-best-practices-a-users-guide-to-getting-started-with-opentelemetry/

5. **OpenTelemetry 2025 Trends** (2025-01-07)
   https://grafana.com/blog/2025/01/07/opentelemetry-and-grafana-labs-whats-new-and-whats-next-in-2025/

6. **Kubernetes + OpenTelemetry** (2024-11-22)
   https://grafana.com/blog/2024/11/22/leveraging-opentelemetry-and-grafana-for-observing-visualizing-and-monitoring-kubernetes-applications/

7. **Kafka + Strimzi (Formula 1)** (2021-02-02)
   https://grafana.com/blog/2021/02/02/real-time-monitoring-of-formula-1-telemetry-data-on-kubernetes-with-grafana-apache-kafka-and-strimzi/

### Community Guides

8. **PostgreSQL CNPG Production** (2 weeks ago)
   https://www.giantswarm.io/blog/making-grafana-remember-our-journey-to-persistence-with-grafana-and-postgresql

9. **Talos OS Monitoring** (2024)
   https://blog.devops.dev/talos-os-raspberry-fc5f327b7026

10. **ArgoCD Grafana Alerts** (2025-09)
    https://medium.com/@nadavshaham/monitoring-argocd-applications-with-grafana-alerts-a-scalable-helm-based-approach-0d6ad814f1d5

---

## 🚀 **Next Steps**

1. **Review dashboards**: Check welche der 50+ Dashboards relevant sind
2. **Deploy missing dashboards**: ArgoCD, CNPG, Kafka, Ceph
3. **Configure alerts**: Replication lag, consumer lag, disk space
4. **GitOps dashboards**: Dashboards as Code via ArgoCD
5. **Deployment annotations**: ArgoCD webhooks → Grafana annotations

---

**Last Updated**: 2025-10-23
**Source**: Grafana Labs Official Blog + Community Best Practices
