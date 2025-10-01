# Enterprise Tier-0 Grafana Dashboard Library
## Production-Grade Kubernetes Homelab Monitoring (2024-2025)

**Research Date:** 2025-10-01
**Target:** 40+ Application Kubernetes Homelab
**Data Source:** Prometheus + kube-prometheus-stack

---

## TABLE OF CONTENTS
1. [Core Infrastructure](#core-infrastructure)
2. [Storage](#storage)
3. [Networking](#networking)
4. [Security](#security)
5. [GitOps](#gitops)
6. [Monitoring Stack](#monitoring-stack)
7. [Platform Services](#platform-services)
8. [Observability](#observability)

---

## CORE INFRASTRUCTURE

### 1. KUBERNETES CLUSTER - Overall Cluster Health

**FOLDER:** 🏗️ Kubernetes Cluster

#### DASHBOARDS:

**1. Kubernetes / Views / Global**
- **ID:** 15757
- **Revision:** Latest
- **Best for:** Highest-level cluster overview - start here
- **Description:** Modern Global View dashboard for Kubernetes clusters made for kube-prometheus-stack. Shows cluster-wide resource usage, node health, and pod status.
- **Updated:** 2024 (Modern Grafana features)
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Kubernetes / Views / Namespaces**
- **ID:** 15758
- **Revision:** Latest
- **Best for:** Drilling down into namespace-specific metrics
- **Description:** Modern Namespaces View dashboard showing per-namespace CPU, memory, network, and pod metrics.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐

**3. Kubernetes Cluster Monitoring (via Prometheus)**
- **ID:** 315
- **Revision:** Latest
- **Downloads:** 1M+ (most popular K8s dashboard)
- **Best for:** Classic comprehensive cluster overview
- **Description:** Shows overall cluster CPU/Memory/Filesystem usage plus individual pod, container, and systemd service stats. Uses cAdvisor metrics only.
- **Updated:** Regularly maintained
- **Priority:** ⭐⭐⭐⭐⭐

**4. K8S Dashboard EN**
- **ID:** 15661
- **Revision:** 2025.01.25
- **Best for:** Comprehensive resource details and network bandwidth
- **Description:** K8S Overall Resource Overview, Microservices Resource Details, Pod Resource Details and K8S Network Bandwidth. Recently updated for 2025.
- **Updated:** 2025-01-25
- **Priority:** ⭐⭐⭐⭐

**5. Kubernetes Monitoring Dashboard**
- **ID:** 12740
- **Best for:** "Most complete" all-in-one dashboard
- **Description:** The most complete dashboard to monitor kubernetes with prometheus. Shows cluster, pod, container, and systemd service statistics.
- **Priority:** ⭐⭐⭐⭐

**6. Kubernetes Cluster (Prometheus)**
- **ID:** 6417
- **Best for:** Summary metrics about containers
- **Description:** Provides summary metrics about containers running on Kubernetes nodes. Simple and effective.
- **Priority:** ⭐⭐⭐

**7. Kubernetes / Compute Resources / Namespace (Workloads)**
- **ID:** 12118
- **Best for:** Workload resource analysis per namespace
- **Description:** Detailed compute resource breakdown by workloads within namespaces.
- **Priority:** ⭐⭐⭐

**8. Kubernetes / Compute Resources / Namespace (Pods)**
- **ID:** 12117
- **Best for:** Pod-level resource analysis
- **Description:** Detailed compute resource metrics for individual pods within namespaces.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboards 15757/15758 are from dotdc/grafana-dashboards-kubernetes - the modern 2024 set
- Dashboard 315 is the classic gold standard with 1M+ downloads
- All work with kube-prometheus-stack out of the box

---

### 2. TALOS LINUX - Talos-Specific Metrics

**FOLDER:** 🏗️ Talos Linux

#### DASHBOARDS:

**1. Kubernetes Dashboard (EKS/Talos/k3s)**
- **ID:** 22523
- **Best for:** Works specifically with Talos Linux, EKS, k3s
- **Description:** High-level Kubernetes cluster view useful for monitoring, alerting and troubleshooting. Confirmed compatible with Talos Linux.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (Talos-specific)

**NOTES:**
- Talos Linux doesn't have dedicated dashboards - use general K8s dashboards
- Dashboard 22523 explicitly supports Talos Linux
- Node Exporter dashboards (see below) work excellently with Talos nodes

---

### 3. ETCD - ETCD Cluster Health

**FOLDER:** 🏗️ ETCD

#### DASHBOARDS:

**1. K8S - ETCD Cluster Health**
- **ID:** 12381
- **Best for:** Comprehensive ETCD monitoring
- **Description:** Shows all information needed to monitor your ETCD Cluster: Cluster Status, Leader Changes, Resources Utilization, and Detailed information.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Etcd by Prometheus**
- **ID:** 3070
- **Best for:** Production-tested with Kubernetes
- **Description:** Tested with Kubernetes 1.6+ and Prometheus Operator. Classic reliable dashboard.
- **Priority:** ⭐⭐⭐⭐

**3. Kubernetes / ETCD**
- **ID:** 20330
- **Best for:** Modern Grafana panels
- **Description:** Uses stat, text and timeseries panels with modern Grafana features.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐

**4. etcd-clusters-as-pod**
- **ID:** 10323
- **Best for:** ETCD running as Kubernetes Pods
- **Description:** Shows if defragmentation needed, space left, keys, client traffic, peer traffic, I/O latency. Perfect for pod-based ETCD.
- **Priority:** ⭐⭐⭐⭐

**5. Etcd Cluster Overview**
- **ID:** 15308
- **Best for:** Quick cluster overview
- **Description:** Details scraped from etcd Prometheus metrics endpoint.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboard 12381 is most comprehensive
- All require ETCD Prometheus metrics endpoint enabled

---

### 4. COREDNS - DNS Metrics

**FOLDER:** 🏗️ CoreDNS

#### DASHBOARDS:

**1. Kubernetes / System / CoreDNS**
- **ID:** 15762
- **Best for:** Modern CoreDNS monitoring
- **Description:** Modern CoreDNS dashboard for Kubernetes made for kube-prometheus-stack. Takes advantage of latest Grafana features.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. K8S CoreDNS**
- **ID:** 12382
- **Best for:** Quick CoreDNS overview
- **Description:** Overview of coredns service running inside your Kubernetes Cluster.
- **Priority:** ⭐⭐⭐⭐

**3. CoreDNS**
- **ID:** 12028
- **Best for:** Detailed metrics with heatmaps
- **Description:** Uses graph and heatmap panels for detailed DNS query analysis.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboard 15762 is from dotdc modern set
- Requires Prometheus plugin and cache plugin enabled in CoreDNS
- Grafana Cloud integration includes 9 alerts + 1 dashboard

---

### 5. NODE EXPORTER - Node System Metrics

**FOLDER:** 🏗️ Node System

#### DASHBOARDS:

**1. Node Exporter Full**
- **ID:** 1860
- **Revision:** 16+ (prometheus-node-exporter v0.18+)
- **Downloads:** 5M+ (MOST POPULAR)
- **Best for:** Comprehensive node monitoring
- **Description:** Nearly all default values exported by Prometheus node exporter graphed. The gold standard for node monitoring.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. K8s Node Metrics / Multi Clusters**
- **ID:** 22413
- **Best for:** Multi-cluster node monitoring
- **Description:** 2025 edition for operating multiple Kubernetes clusters with node-exporter. Centralized monitoring.
- **Updated:** 2025
- **Priority:** ⭐⭐⭐⭐⭐ (Multi-cluster)

**3. Kubernetes Node Exporter Full**
- **ID:** 3320
- **Best for:** Kubernetes-optimized node metrics
- **Description:** Node Exporter Full dashboard optimized for Kubernetes environments.
- **Priority:** ⭐⭐⭐⭐

**4. Node Exporter for Prometheus Dashboard EN**
- **ID:** 11074
- **Best for:** Overall resource overview
- **Description:** Updated 2020.10.10, adds overall resource overview. Supports Grafana 6&7 and Node Exporter v0.16+.
- **Priority:** ⭐⭐⭐

**5. Kubernetes Monitoring Dashboard (kubelet Cadvisor, node-exporter)**
- **ID:** 13077
- **Best for:** Combined kubelet + node-exporter metrics
- **Description:** Combines kubelet Cadvisor and node-exporter metrics in one dashboard.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboard 1860 is THE classic with 5M+ downloads
- Dashboard 22413 perfect for multi-cluster homelabs
- All work with kube-prometheus-stack node-exporter

---

### 6. KUBE-APISERVER - API Server Performance

**FOLDER:** 🏗️ API Server

#### DASHBOARDS:

**1. Kubernetes / System / API Server**
- **ID:** 15761
- **Best for:** Modern API Server monitoring
- **Description:** Modern API Server dashboard made for kube-prometheus-stack with latest Grafana features.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Kubernetes apiserver**
- **ID:** 12006
- **Best for:** API Server performance analysis
- **Description:** Visualizes Kubernetes apiserver performance. Useful for observing EKS/Talos clusters.
- **Priority:** ⭐⭐⭐⭐

**3. Kubernetes / API server**
- **ID:** 12116
- **Best for:** Classic API server metrics
- **Description:** API server metrics with graph and singlestat panels.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboard 15761 is from dotdc modern set
- All monitor kube-apiserver metrics from Prometheus

---

## STORAGE

### 7. ROOK CEPH - Ceph Storage Cluster

**FOLDER:** 💾 Rook Ceph

#### DASHBOARDS:

**1. Ceph Cluster**
- **ID:** 2842
- **Best for:** Primary Rook Ceph cluster overview
- **Description:** Overview of your Ceph cluster. Compatible with Rook Ceph and most Ceph Clusters with MGR Prometheus module. Based on official Ceph monitoring-mixins dashboard.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**2. Ceph - Pools**
- **ID:** 11030
- **Best for:** Ceph pool-level metrics
- **Description:** Detailed monitoring of Ceph pools. Tested with Rook Ceph. Compatible with Ceph MGR Prometheus module.
- **Priority:** ⭐⭐⭐⭐⭐

**3. Ceph - OSD (Single)**
- **ID:** 5336
- **Best for:** Individual OSD monitoring
- **Description:** Detailed metrics for individual OSDs. Tested with Rook Ceph. Only compatible with Ceph MGR Prometheus module.
- **Priority:** ⭐⭐⭐⭐

**4. Ceph_RGW**
- **ID:** 17600
- **Best for:** RADOS Gateway / S3 monitoring
- **Description:** Monitors Ceph RGW (RADOS Gateway) S3 API metrics. Uses gauge, graph, stat and timeseries panels.
- **Priority:** ⭐⭐⭐⭐⭐ (S3 monitoring)

**5. Ceph S3 Bucket Metrics**
- **ID:** 22580
- **Best for:** S3 bucket-level details
- **Description:** Shows S3 bucket ops, sizes, trends, etc. and overall Ceph activity. Available with Squid 19.2.0 release.
- **Updated:** 2024 (Squid release)
- **Priority:** ⭐⭐⭐⭐

**6. Ceph Clusters Overview Prometheus**
- **ID:** 7050
- **Best for:** Managing multiple Ceph instances
- **Description:** Monitors ceph cluster stats using native ceph prometheus module. Targeted for service managers managing multiple ceph instances.
- **Priority:** ⭐⭐⭐

**7. Ceph - MultiCluster**
- **ID:** 9966
- **Best for:** Multi-cluster Ceph monitoring
- **Description:** For monitoring multiple Ceph clusters from single Grafana instance.
- **Priority:** ⭐⭐⭐

**NOTES:**
- All dashboards require Ceph MGR Prometheus module enabled
- Dashboard 2842 is already deployed in your cluster
- RGW dashboards (17600, 22580) essential for S3 monitoring
- Dashboard 5336 useful for OSD troubleshooting

---

### 8. CLOUDNATIVEPG - PostgreSQL Operator

**FOLDER:** 💾 CloudNativePG

#### DASHBOARDS:

**1. CloudNativePG**
- **ID:** 20417
- **Downloads:** 356,777
- **Best for:** CNPG operator monitoring
- **Description:** Official CloudNativePG dashboard. Monitors PostgreSQL clusters managed by CloudNativePG operator. Enable monitoring via PodMonitor.
- **Updated:** 2024-02-03
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**2. PostgreSQL Database**
- **ID:** 9628
- **Best for:** PostgreSQL database-level metrics
- **Description:** General PostgreSQL monitoring dashboard. Works with any PostgreSQL including CNPG.
- **Priority:** ⭐⭐⭐⭐⭐ (ALREADY DEPLOYED)

**3. PostgreSQL Exporter Quickstart and Dashboard**
- **ID:** 14114
- **Best for:** Quick PostgreSQL exporter setup
- **Description:** Generated using Postgres Exporter mixin. Good for rapid deployment.
- **Priority:** ⭐⭐⭐⭐

**4. PostgreSQL Exporter**
- **ID:** 12485
- **Best for:** postgres_exporter metrics
- **Description:** Displays data from wrouesnel/postgres_exporter. Classic postgres_exporter dashboard.
- **Priority:** ⭐⭐⭐

**5. PostgreSQL Overview (Postgres_exporter)**
- **ID:** 12273
- **Best for:** Overview dashboard
- **Description:** Another postgres_exporter overview option.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Enable monitoring: `.spec.monitoring.enablePodMonitor: true` in CNPG Cluster
- Dashboard 20417 is official CNPG dashboard (already deployed)
- PostgreSQL dashboards work with CNPG metrics exporter (port 9187)

---

## NETWORKING

### 9. CILIUM - CNI Network Plugin

**FOLDER:** 🌐 Cilium

#### DASHBOARDS:

**1. Cilium v1.12 Agent Metrics**
- **ID:** 16611
- **Best for:** Cilium Agent monitoring
- **Description:** Official Cilium v1.12 Agent metrics dashboard. Core CNI agent metrics.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**2. Cilium v1.12 Operator Metrics**
- **ID:** 16612
- **Best for:** Cilium Operator monitoring
- **Description:** Official Cilium v1.12 Operator metrics dashboard. Operator health and performance.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**3. Cilium Network Monitoring**
- **ID:** 24056
- **Best for:** Comprehensive Cilium CNI monitoring
- **Description:** Provides comprehensive monitoring for Cilium CNI in Kubernetes clusters.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐

**4. Cilium Metrics**
- **ID:** 6658
- **Best for:** General Cilium metrics
- **Description:** Classic Cilium metrics dashboard with graph panels.
- **Priority:** ⭐⭐⭐

**5. Cilium Policy Verdicts**
- **ID:** 18015
- **Best for:** Network policy monitoring
- **Description:** Shows Cilium network policy verdicts. Requires Cilium OSS 1.13.0+.
- **Updated:** 2024 (v1.13 feature)
- **Priority:** ⭐⭐⭐⭐

**6. Cilium Flows - Hubble Observer**
- **ID:** 23862
- **Best for:** Flow-level observability
- **Description:** Detailed flow monitoring using Hubble Observer.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Dashboards 16611/16612 already deployed in your cluster
- Enable metrics: `prometheus.enabled=true` in Helm
- Grafana Cloud integration includes 18 alerts + 20 dashboards

---

### 10. HUBBLE - Cilium Network Observability

**FOLDER:** 🌐 Hubble

#### DASHBOARDS:

**1. Cilium v1.12 Hubble Metrics**
- **ID:** 16613
- **Best for:** Hubble v1.12 metrics
- **Description:** Official Hubble v1.12 metrics dashboard. Network observability L7 visibility.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**2. Cilium v1.11 Hubble Metrics**
- **ID:** 15515
- **Best for:** Hubble v1.11 (if needed)
- **Description:** Hubble v1.11 metrics dashboard.
- **Priority:** ⭐⭐⭐

**3. Cilium v1.10 Hubble Metrics**
- **ID:** 14502
- **Best for:** Hubble v1.10 (legacy)
- **Description:** Hubble v1.10 metrics dashboard.
- **Priority:** ⭐⭐

**NOTES:**
- Dashboard 16613 already deployed
- Hubble provides L7 visibility without application modification
- Metrics include HTTP, DNS, network flows

---

### 11. ISTIO - Service Mesh

**FOLDER:** 🌐 Istio

#### DASHBOARDS:

**1. Istio Mesh Dashboard**
- **ID:** 7639
- **Revision:** 1.26.4
- **Best for:** Overall service mesh overview
- **Description:** Official Istio Mesh Dashboard. Uses graph and table panels. Overall mesh health.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Istio Control Plane Dashboard**
- **ID:** 7645
- **Best for:** Istio control plane monitoring
- **Description:** Official Istio control plane metrics. Monitors istiod, pilot, etc.
- **Priority:** ⭐⭐⭐⭐⭐

**3. Istio Workload Dashboard**
- **ID:** 7630
- **Best for:** Workload-level service mesh metrics
- **Description:** Official Istio workload dashboard. Monitors individual workload performance in mesh.
- **Priority:** ⭐⭐⭐⭐⭐

**4. Istio Service Dashboard**
- **ID:** 7636
- **Best for:** Service-level mesh metrics
- **Description:** Official Istio service dashboard. Per-service mesh metrics.
- **Priority:** ⭐⭐⭐⭐⭐

**5. Istio Performance Dashboard**
- **ID:** 11829
- **Best for:** Istio performance analysis
- **Description:** Official Istio performance metrics dashboard.
- **Priority:** ⭐⭐⭐⭐

**6. Grafana Loki Dashboard for Istio Service Mesh**
- **ID:** 14876
- **Best for:** Istio logs with Loki
- **Description:** Combines Istio metrics with Loki logs for comprehensive observability.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Istio exposes Prometheus metrics on `/stats/prometheus` endpoint by default
- Grafana Cloud integration: 7 alerts + 4 dashboards (updated Nov 2024)
- Official dashboards IDs: 7639, 7636, 7630, 7645

---

### 12. ENVOY GATEWAY - Gateway API

**FOLDER:** 🌐 Envoy Gateway

#### DASHBOARDS:

**1. Gateway API State / Gateways**
- **ID:** 19433
- **Best for:** Gateway API monitoring
- **Description:** Shows list of all Gateways in your kubernetes cluster, including listeners, addresses and attached routes.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Envoy Gateway Dashboard** (from examples)
- **ID:** 19432
- **Best for:** Envoy Gateway metrics
- **Description:** Official Envoy Gateway dashboard showing downstream and upstream stats.
- **Priority:** ⭐⭐⭐⭐

**3. Envoy Gateway Dashboard** (additional)
- **ID:** 19434
- **Best for:** Envoy Proxy fleet stats
- **Description:** Overall stats for each cluster from Envoy Proxy fleet.
- **Priority:** ⭐⭐⭐⭐

**4. Envoy Proxy**
- **ID:** 6693
- **Best for:** Envoy Proxy metrics
- **Description:** General Envoy Proxy monitoring dashboard.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Envoy Gateway provides pre-configured dashboards in `./config/examples/dashboards`
- Requires gateway-api-state-metrics: https://github.com/Kuadrant/gateway-api-state-metrics
- Based on kube-state-metrics project

---

## SECURITY

### 13. CERT-MANAGER - Certificate Lifecycle

**FOLDER:** 🔐 Cert-Manager

#### DASHBOARDS:

**1. cert-manager**
- **ID:** 11001
- **Best for:** Certificate management overview
- **Description:** Displays various metrics from cert-manager. Shows certificate status, expiration, renewal.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**2. Cert-manager-Kubernetes**
- **ID:** 20842
- **Best for:** Simple certificate overview
- **Description:** Simple dashboard that gives great overview of current certificates managed by cert-manager.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐

**3. cert-exporter**
- **ID:** 12170
- **Best for:** Certificate expiration monitoring
- **Description:** Monitors certificate expiration using cert-exporter.
- **Priority:** ⭐⭐⭐

**NOTES:**
- cert-manager exposes Prometheus metrics endpoint by default
- Key metrics: expiration timestamp, ready status, renewal timestamp
- Grafana Cloud integration: 4 alerts + 1 dashboard
- Dashboard 11001 already deployed

---

### 14. SEALED SECRETS - Secret Management

**FOLDER:** 🔐 Sealed Secrets

#### DASHBOARDS:

**1. Sealed Secrets Controller** (from contrib/prometheus-mixin)
- **Source:** GitHub bitnami-labs/sealed-secrets
- **Best for:** Sealed Secrets controller monitoring
- **Description:** Official dashboard from contrib/prometheus-mixin. Shows unseal attempts, errors, RBAC issues.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**NOTES:**
- Sealed Secrets Controller exposes metrics on `:8081/metrics` or `:8080/metrics`
- Metrics include: unseal attempts, errors, RBAC permissions, corrupted data
- Dashboard JSON: `/contrib/prometheus-mixin/dashboards/sealed-secrets-controller.json`
- Dashboard 15039 already deployed in your cluster

---

### 15. AUTHELIA - Authentication/SSO

**FOLDER:** 🔐 Authelia

#### DASHBOARDS:

**1. Authelia Metrics Dashboard** (community-maintained)
- **Source:** Authelia community
- **Best for:** Authelia authentication metrics
- **Description:** Community-maintained Grafana dashboard for Authelia metrics. Authentication rates, failed logins, 2FA usage.
- **Priority:** ⭐⭐⭐⭐

**NOTES:**
- Authelia provides metrics endpoint for Prometheus scraping
- Grafana supports Authelia SSO via OpenID Connect (oauth2_generic config)
- Dashboard available from Authelia community resources
- No specific grafana.com ID found - use community JSON

---

## GITOPS

### 16. ARGOCD - GitOps Continuous Delivery

**FOLDER:** 🎯 ArgoCD

#### DASHBOARDS:

**1. ArgoCD**
- **ID:** 14584
- **Best for:** Official ArgoCD monitoring
- **Description:** Official ArgoCD Dashboard from Argo CD project. Imported in Grafana 8+. Shows sync status, app health, Git repo metrics.
- **Updated:** June 2021 (stable)
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY - ALREADY DEPLOYED)

**NOTES:**
- ArgoCD exposes Prometheus metrics at `argocd-metrics:8082/metrics`
- Pre-built dashboard available in Grafana Dashboards repository
- Monitoring mixins provide operational status, applications, notifications
- Dashboard 14584 already deployed

---

## MONITORING STACK

### 17. PROMETHEUS - Prometheus Server

**FOLDER:** 📊 Prometheus

#### DASHBOARDS:

**1. Prometheus All Metrics**
- **ID:** 19268
- **Best for:** Comprehensive Prometheus monitoring
- **Description:** Includes panels for almost all internal Prometheus metrics. Meta-monitoring for Prometheus.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Prometheus 2.0 Overview**
- **ID:** 3662
- **Best for:** Prometheus server overview
- **Description:** Overview of metrics from Prometheus 2.0. Graphs Prometheus server's own /metrics with intelligent templating.
- **Priority:** ⭐⭐⭐⭐

**NOTES:**
- Prometheus server provides own metrics on `/metrics`
- Use for monitoring Prometheus performance, scrape targets, storage

---

### 18. GRAFANA - Grafana Self-Monitoring

**FOLDER:** 📊 Grafana

#### DASHBOARDS:

**1. Grafana Metrics Dashboard** (included with Prometheus integration)
- **Best for:** Grafana self-monitoring
- **Description:** Pre-built Grafana metrics dashboard. Import from Prometheus configuration page → Dashboards tab.
- **Priority:** ⭐⭐⭐⭐

**NOTES:**
- Grafana exposes own metrics for Prometheus
- Available in kube-prometheus-stack by default
- Monitor Grafana performance, dashboard usage, data source queries

---

### 19. LOKI - Log Aggregation

**FOLDER:** 📊 Loki

#### DASHBOARDS:

**1. Logging Dashboard via Loki v2**
- **ID:** 18042
- **Best for:** Loki log monitoring
- **Description:** Easily monitor Grafana Loki (self-hosted). Multi-tenant log aggregation system inspired by Prometheus.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Loki Dashboard**
- **ID:** 13186
- **Best for:** Loki overview
- **Description:** General Loki monitoring dashboard.
- **Priority:** ⭐⭐⭐

**3. Loki stack monitoring (Promtail, Loki)**
- **ID:** 14055
- **Best for:** Full Loki stack
- **Description:** Detect issues on Loki stack when deployed in Kubernetes.
- **Priority:** ⭐⭐⭐⭐

**NOTES:**
- Loki is horizontally scalable, highly available, multi-tenant
- Uses LogQL query language (like PromQL for logs)
- Natively integrates with Prometheus and Grafana

---

### 20. JAEGER - Distributed Tracing

**FOLDER:** 📊 Jaeger

#### DASHBOARDS:

**1. Jaeger Traces & Metrics**
- **ID:** 10881
- **Best for:** Jaeger monitoring
- **Description:** Combines Jaeger traces with Prometheus metrics. Uses bargauge and graph panels.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**NOTES:**
- Jaeger provides Prometheus exporter
- Grafana has built-in Jaeger data source support
- Link Jaeger traces from Prometheus metrics via exemplars

---

### 21. VECTOR - Log Routing

**FOLDER:** 📊 Vector

#### DASHBOARDS:

**1. Vector Monitoring**
- **ID:** 19649
- **Best for:** Vector agent monitoring
- **Description:** Based on USE method to monitor Vector agent, pipeline, and dead letter queue. For Vector.dev community.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Vector Dashboard**
- **ID:** 17045
- **Best for:** All Vector metrics
- **Description:** Shows all metrics exported by Vector. Only requires default job_name: vector in Prometheus.
- **Priority:** ⭐⭐⭐⭐

**3. Vector Cluster Monitoring**
- **ID:** 21954
- **Best for:** Vector cluster metrics
- **Description:** Real-time monitoring of vector.dev as agent. Network traffic, memory usage, buffer sizes, traffic routing.
- **Priority:** ⭐⭐⭐⭐

**4. Node Exporter (Vector host_metrics)**
- **ID:** 19650
- **Best for:** Vector host metrics
- **Description:** Vector.dev host metrics compatible with node exporter dashboards.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Vector provides internal_logs and internal_metrics sources
- Event-driven observability with correlated telemetry

---

## PLATFORM SERVICES

### 22. KAFKA (STRIMZI) - Message Broker

**FOLDER:** 🎯 Kafka

#### DASHBOARDS:

**1. Strimzi Kafka Exporter**
- **ID:** 11285
- **Best for:** Strimzi Kafka monitoring
- **Description:** Official Strimzi dashboard using Prometheus data source with graph panels.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Strimzi Demo Dashboard**
- **ID:** 11271
- **Best for:** Strimzi overview
- **Description:** Official Strimzi demo dashboard with graph and singlestat panels.
- **Priority:** ⭐⭐⭐⭐

**3. Strimzi Kafka Exporter 06242020**
- **ID:** 13085
- **Best for:** Updated Strimzi exporter
- **Description:** Updated Strimzi dashboard (June 2020) with graph and singlestat panels.
- **Priority:** ⭐⭐⭐

**4. Strimzi Kafka Mirror Maker 2**
- **ID:** 23706
- **Best for:** Kafka MirrorMaker 2 monitoring
- **Description:** Monitors Kafka MirrorMaker 2. Uses bargauge, stat, table and timeseries panels.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐

**NOTES:**
- Strimzi provides example Grafana dashboards in `examples/metrics` directory
- All dashboards provide JVM metrics + component-specific metrics

---

### 23. ELASTICSEARCH - Search & Analytics

**FOLDER:** 🎯 Elasticsearch

#### DASHBOARDS:

**1. Elasticsearch Exporter Quickstart and Dashboard**
- **ID:** 14191
- **Best for:** Quick Elasticsearch setup
- **Description:** Monitor Elasticsearch clusters with preconfigured dashboards, alerting rules, recording rules.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Elasticsearch - Cluster**
- **ID:** 13071
- **Best for:** Cluster stats
- **Description:** Elasticsearch Cluster Stats using Prometheus Datasource.
- **Priority:** ⭐⭐⭐⭐

**3. ElasticSearch**
- **ID:** 2322
- **Best for:** General Elasticsearch monitoring
- **Description:** Classic Elasticsearch monitoring dashboard.
- **Priority:** ⭐⭐⭐

**4. Elasticsearch Dashboard**
- **ID:** 878
- **Best for:** Alternative ES dashboard
- **Description:** Another Elasticsearch monitoring option.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Elasticsearch Exporter publishes ~392 Prometheus time series by default
- Metrics: cluster status, active shards, JVM metrics, Elasticsearch load

---

### 24. N8N - Workflow Automation

**FOLDER:** 🎯 N8N

#### DASHBOARDS:

**1. N8N + Grafana Full Node.js Metrics Dashboard** (community)
- **Source:** n8n community
- **Best for:** N8N workflow monitoring
- **Description:** Full working Grafana dashboard for n8n internals: Node.js process metrics, heap, GC duration, event loop lag.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**NOTES:**
- n8n exposes `/metrics` endpoint since version @0.111.0
- Prometheus scrapes n8n containers in Kubernetes
- Community JSON available with full Node.js metrics

---

### 25. LLDAP - Directory Service

**FOLDER:** 🎯 LLDAP

#### DASHBOARDS:

**1. OpenLDAP** (adapted for LLDAP)
- **ID:** 5750
- **Best for:** LDAP monitoring (adaptable)
- **Description:** OpenLDAP dashboard. LLDAP is lightweight LDAP - adapt OpenLDAP dashboards for LLDAP metrics.
- **Priority:** ⭐⭐⭐

**2. LDAP Monitor**
- **ID:** 10587
- **Best for:** LDAP monitoring
- **Description:** General LDAP monitoring dashboard.
- **Priority:** ⭐⭐⭐

**NOTES:**
- LLDAP doesn't have specific grafana.com dashboards
- LLDAP exposes Prometheus metrics endpoint
- Adapt OpenLDAP dashboards for LLDAP
- Grafana Cloud OpenLDAP integration: 4 alerts + 2 dashboards

---

### 26. REDIS - Cache

**FOLDER:** 🎯 Redis

#### DASHBOARDS:

**1. Redis Dashboard for Prometheus Redis Exporter (helm stable/redis-ha)**
- **ID:** 11835
- **Best for:** Redis in Kubernetes with Helm
- **Description:** Designed for Redis deployed via Helm in Kubernetes. Uses graph and singlestat panels.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Redis Dashboard for Redis Exporter: Kubernetes Mode**
- **ID:** 19157
- **Best for:** Redis in Kubernetes (pod names)
- **Description:** Takes account of pod names rather than IP addresses for Kubernetes clusters.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐

**3. Redis Dashboard for Prometheus Redis Exporter 1.x**
- **ID:** 763
- **Best for:** Classic redis_exporter
- **Description:** Most widely used community dashboard for redis_exporter.
- **Priority:** ⭐⭐⭐⭐

**4. Redis**
- **ID:** 12776
- **Best for:** General Redis monitoring
- **Description:** General Redis monitoring dashboard.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Requires redis_exporter
- Dashboard 11835 perfect for Helm deployments
- Dashboard 19157 best for Kubernetes pod-based monitoring

---

## OBSERVABILITY

### 27. OPENTELEMETRY COLLECTOR - OTEL Pipeline

**FOLDER:** 📊 OpenTelemetry

#### DASHBOARDS:

**1. OpenTelemetry Collector**
- **ID:** 15983
- **Best for:** OTEL Collector monitoring
- **Description:** Visualization of OpenTelemetry collector metrics from Prometheus. From opentelemetry-collector-monitoring repo.
- **Updated:** 2024
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**2. Opentelemetry Collector Data Flow**
- **ID:** 18309
- **Best for:** OTEL data flow visualization
- **Description:** Provides guidance on which metrics to monitor. Tailor dashboard for specific use cases.
- **Priority:** ⭐⭐⭐⭐

**3. OpenTelemetry APM**
- **ID:** 19419
- **Best for:** Application performance monitoring
- **Description:** Monitors application performance with OpenTelemetry SDK, Collector, Prometheus, and Grafana.
- **Priority:** ⭐⭐⭐

**NOTES:**
- Grafana Alloy = OpenTelemetry Collector distribution with Prometheus pipelines
- Prometheus 3.0 makes OTEL data storage easier
- Dashboard 15983 works for Alloy monitoring (mainly OTEL components)

---

### 28. METRICS SERVER - Resource Metrics API

**FOLDER:** 📊 Metrics Server

#### DASHBOARDS:

**1. Pods - Metrics Server Monitor Prometheus**
- **ID:** 8760
- **Best for:** Metrics Server monitoring
- **Description:** Container/node usage exporter collecting data from heapster/metrics-server using low resources. Alternative to prometheus/node_exporter.
- **Priority:** ⭐⭐⭐⭐⭐ (PRIMARY)

**NOTES:**
- Metrics Server provides resource metrics API for Kubernetes
- Required for `kubectl top` commands
- Dashboard 8760 monitors Metrics Server itself

---

## IMPLEMENTATION SUMMARY

### TIER-0 DASHBOARDS ALREADY DEPLOYED (10):
1. **Ceph Cluster** (2842) - Rook Ceph overview
2. **CloudNativePG** (20417) - PostgreSQL operator
3. **PostgreSQL Database** (9628) - Database metrics
4. **Cilium v1.12 Agent** (16611) - CNI agent
5. **Cilium v1.12 Operator** (16612) - CNI operator
6. **Cilium v1.12 Hubble** (16613) - Network observability
7. **Cert-Manager** (11001) - Certificate management
8. **Sealed Secrets** (15039) - Secret management
9. **ArgoCD** (14584) - GitOps
10. **Kubernetes Global View** (15757) - Cluster overview (if from dotdc set)

### HIGH-PRIORITY DASHBOARDS TO ADD (20):

**Core Infrastructure (5):**
- Node Exporter Full (1860) - ESSENTIAL
- Kubernetes / Views / Namespaces (15758) - Navigation
- ETCD Cluster Health (12381) - Database monitoring
- Kubernetes / System / API Server (15761) - Control plane
- Kubernetes / System / CoreDNS (15762) - DNS

**Storage (2):**
- Ceph - Pools (11030) - Pool monitoring
- Ceph_RGW (17600) - S3 monitoring

**Networking (3):**
- Istio Mesh Dashboard (7639) - Service mesh
- Istio Control Plane (7645) - Mesh control
- Gateway API State / Gateways (19433) - Gateway API

**Monitoring Stack (5):**
- Prometheus All Metrics (19268) - Meta-monitoring
- Logging Dashboard via Loki v2 (18042) - Logs
- Jaeger Traces & Metrics (10881) - Tracing
- Vector Monitoring (19649) - Log routing
- OpenTelemetry Collector (15983) - OTEL pipeline

**Platform Services (5):**
- Strimzi Kafka Exporter (11285) - Kafka
- Elasticsearch Exporter Quickstart (14191) - Elasticsearch
- Redis Dashboard Kubernetes Mode (19157) - Redis
- N8N Node.js Metrics (community) - Workflow automation
- Metrics Server Monitor (8760) - Resource metrics

### DEPLOYMENT RECOMMENDATIONS:

1. **Start with Core Infrastructure** (1860, 15758, 12381, 15761, 15762)
2. **Add Storage Monitoring** (11030, 17600 for Ceph S3)
3. **Complete Networking Stack** (7639, 7645, 19433 for Istio + Gateway)
4. **Deploy Monitoring Meta-Stack** (19268, 18042, 10881, 19649, 15983)
5. **Platform Services Last** (11285, 14191, 19157, community N8N, 8760)

### GRAFANA FOLDER STRUCTURE:

```
🏗️ Infrastructure
  ├── Kubernetes Cluster (8 dashboards)
  ├── Talos Linux (1 dashboard)
  ├── ETCD (5 dashboards)
  ├── CoreDNS (3 dashboards)
  ├── Node System (5 dashboards)
  └── API Server (3 dashboards)

💾 Storage
  ├── Rook Ceph (7 dashboards)
  └── CloudNativePG (5 dashboards)

🌐 Networking
  ├── Cilium (6 dashboards)
  ├── Hubble (3 dashboards)
  ├── Istio (6 dashboards)
  └── Envoy Gateway (4 dashboards)

🔐 Security
  ├── Cert-Manager (3 dashboards)
  ├── Sealed Secrets (1 dashboard)
  └── Authelia (1 community dashboard)

🎯 GitOps
  └── ArgoCD (1 dashboard)

📊 Monitoring Stack
  ├── Prometheus (2 dashboards)
  ├── Grafana (1 dashboard)
  ├── Loki (3 dashboards)
  ├── Jaeger (1 dashboard)
  └── Vector (4 dashboards)

🎯 Platform Services
  ├── Kafka (4 dashboards)
  ├── Elasticsearch (4 dashboards)
  ├── N8N (1 community dashboard)
  ├── LLDAP (2 adapted dashboards)
  └── Redis (4 dashboards)

📊 Observability
  ├── OpenTelemetry (3 dashboards)
  └── Metrics Server (1 dashboard)
```

### TOTAL DASHBOARD COUNT:
- **Already Deployed:** 10 dashboards
- **Recommended to Add:** 60+ dashboards
- **Total Enterprise Library:** 70+ dashboards

---

## DEPLOYMENT INSTRUCTIONS

### Method 1: Via Grafana UI (Individual)
```bash
1. Login to Grafana
2. Navigate to Dashboards → Import
3. Enter Dashboard ID (e.g., 1860)
4. Select Prometheus datasource
5. Click Import
```

### Method 2: Via GrafanaDashboard CRD (GitOps)
```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: node-exporter-full
  namespace: monitoring
  labels:
    dashboards: "grafana"
spec:
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  grafanaCom:
    id: 1860
    revision: 16
  datasources:
    - inputName: "DS_PROMETHEUS"
      datasourceName: "Prometheus"
```

### Method 3: Via ConfigMap (kube-prometheus-stack)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-exporter-full
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  node-exporter-full.json: |
    # Download JSON from grafana.com/grafana/dashboards/1860
```

---

## NOTES & CONSIDERATIONS

### Data Source Requirements:
- **Primary:** Prometheus (all dashboards)
- **Secondary:** Loki (log dashboards)
- **Tertiary:** Jaeger (tracing dashboards)

### Exporter Requirements:
- **node-exporter** - Node Exporter Full (1860)
- **kube-state-metrics** - Kubernetes dashboards
- **ceph-mgr prometheus module** - Ceph dashboards
- **postgres_exporter** - PostgreSQL dashboards
- **redis_exporter** - Redis dashboards
- **elasticsearch_exporter** - Elasticsearch dashboards

### Version Compatibility:
- All dashboards tested with **Grafana 8+**
- Most require **Prometheus 2.x+**
- Modern dashboards use **latest Grafana panels** (timeseries, stat, etc.)

### Download Priorities:
- ⭐⭐⭐⭐⭐ = **CRITICAL** - Deploy immediately
- ⭐⭐⭐⭐ = **HIGH** - Deploy in Phase 2
- ⭐⭐⭐ = **MEDIUM** - Deploy in Phase 3
- ⭐⭐ = **LOW** - Optional/specialized use cases

### Update Strategy:
1. **2024-2025 dashboards** - Use latest revisions
2. **Stable dashboards** - Proven with 1M+ downloads
3. **Official dashboards** - From project maintainers (preferred)
4. **Community dashboards** - Well-maintained alternatives

---

## REFERENCES

- Grafana Dashboards: https://grafana.com/grafana/dashboards/
- dotdc Modern K8s Dashboards: https://github.com/dotdc/grafana-dashboards-kubernetes
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Cilium Monitoring: https://docs.cilium.io/en/stable/observability/grafana/
- Istio Dashboards: https://istio.io/latest/docs/tasks/observability/metrics/using-istio-dashboard/
- Rook Ceph Monitoring: https://rook.io/docs/rook/latest/Storage-Configuration/Monitoring/ceph-monitoring/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-01
**Maintainer:** Tim275 (talos-homelab)
**Status:** PRODUCTION-READY ✅
