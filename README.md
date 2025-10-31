# 🚀 Enterprise Kubernetes Homelab

[![Talos](https://img.shields.io/badge/OS-Talos%20Linux-FF7300?style=for-the-badge&logo=linux&logoColor=white)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33.2-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-844FBA?style=for-the-badge&logo=opentofu&logoColor=white)](https://opentofu.org/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-00D4AA?style=for-the-badge&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)

## 🏠 Welcome to my Homelab

This repository contains the complete configuration and documentation of my enterprise-grade Kubernetes homelab.

## 🗂️ Repository Structure
```
.
├── 📂 kubernetes/          # All Kubernetes manifests
│   ├── 📂 sets/           # App-of-Apps bootstrap
│   ├── 📂 security/       # Zero-trust foundation & RBAC
│   ├── 📂 infrastructure/ # Core cluster services & operators
│   ├── 📂 platform/       # Databases & middleware services
│   └── 📂 apps/          # End-user applications
├── 📂 tofu/               # OpenTofu infrastructure
│   ├── 📂 talos/         # Talos configuration
│   └── 📂 bootstrap/     # Initial setup
└── 📂 renovate.json      # Dependency automation
```

---

## 📱 Applications

End-user applications deployed in dev, staging, and production environments:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://n8n.io/favicon.ico"></td>
        <td><a href="https://n8n.io/">n8n</a></td>
        <td>Secure, AI-native workflow automation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.audiobookshelf.org/Logo.png"></td>
        <td><a href="https://www.audiobookshelf.org/">Audiobookshelf</a></td>
        <td>Self-hosted audiobook and podcast server</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="kubernetes/apps/base/kafka-demo/">Kafka Email Consumer</a></td>
        <td>Real-time email notification system consuming Kafka messages</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="kubernetes/apps/base/kafka-demo/">Kafka User Producer</a></td>
        <td>Kafka message producer for user registration events</td>
    </tr>
</table>

## 🎛️ Kubernetes Operators

Enterprise operators managing lifecycle, scaling, and HA for complex stateful workloads:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/cilium/cilium/Documentation/images/logo-solo.svg"></td>
        <td><a href="https://cilium.io/">Cilium Operator</a></td>
        <td>CNI networking operator with eBPF dataplane for pod networking and Hubble observability</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph Operator</a></td>
        <td>Storage orchestration operator managing CephCluster with block, object and file storage</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/23534644?s=200&v=4"></td>
        <td><a href="https://istio.io/">Sail Operator</a></td>
        <td>Istio service mesh lifecycle operator managing control plane, gateways and mTLS</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">Cert-Manager</a></td>
        <td>TLS certificate automation operator with Let's Encrypt integration</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus-operator.dev/">Prometheus Operator</a></td>
        <td>Metrics collection operator managing Prometheus, AlertManager and ServiceMonitors</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana-operator.github.io/grafana-operator/">Grafana Operator</a></td>
        <td>Dashboard lifecycle operator managing Grafana instances and datasources</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/docs/latest/operator/">Jaeger Operator</a></td>
        <td>Distributed tracing operator managing Jaeger instances and collectors</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html">Elastic Operator</a></td>
        <td>Elasticsearch and Kibana orchestration operator managing clusters and indices</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/docs/kubernetes/operator/">OpenTelemetry Operator</a></td>
        <td>Observability data collection operator managing collectors and instrumentation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://docs.confluent.io/operator/current/overview.html">Confluent Operator</a></td>
        <td>Kafka enterprise operator managing clusters, Connect and Schema Registry</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/redis/redis-original.svg"></td>
        <td><a href="https://redis-operator.opstree.dev/">Redis Operator</a></td>
        <td>Redis lifecycle operator managing standalone, sentinel and replication instances</td>
    </tr>
    <tr>
        <td><img width="32" src="https://tailscale.com/files/press/tailscale-symbol-color.svg"></td>
        <td><a href="https://tailscale.com/kb/1236/kubernetes-operator">Tailscale Operator</a></td>
        <td>VPN connectivity operator managing connectors and subnet routes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG Operator</a></td>
        <td>PostgreSQL HA operator managing clusters, backups and point-in-time recovery</td>
    </tr>
</table>

## ⚙️ Infrastructure

Core cluster services including GitOps, networking, storage, backup, and observability:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/argoproj/argo-cd/master/docs/assets/argo.png"></td>
        <td><a href="https://argo-cd.readthedocs.io/">ArgoCD</a></td>
        <td>Declarative GitOps continuous delivery for Kubernetes with HA Redis backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/main/site-src/images/logo/logo.svg"></td>
        <td><a href="https://gateway-api.sigs.k8s.io/">Gateway API</a></td>
        <td>Next-generation ingress API for Kubernetes with vendor-neutral traffic routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/30125649?s=200&v=4"></td>
        <td><a href="https://gateway.envoyproxy.io/">Envoy Gateway</a></td>
        <td>High-performance Gateway API implementation with TLS termination and advanced routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/cloudflare/cloudflare-icon.svg"></td>
        <td><a href="https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/">Cloudflare Tunnel</a></td>
        <td>Zero-Trust secure tunnel for external access without port forwarding</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph</a></td>
        <td>Distributed storage with block, object and file storage (Rook Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.yuribacciarini.com/content/images/2023/07/image-4.png"></td>
        <td><a href="https://github.com/sergelogvinov/proxmox-csi-plugin">Proxmox CSI</a></td>
        <td>Container Storage Interface for Proxmox VE with ZFS backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://velero.io/img/velero.svg"></td>
        <td><a href="https://velero.io/">Velero</a></td>
        <td>Kubernetes backup and disaster recovery with Ceph Object Storage backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus-operator.dev/">Prometheus</a></td>
        <td>Metrics collection with AlertManager and ServiceMonitor resources (Prometheus Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana-operator.github.io/grafana-operator/">Grafana</a></td>
        <td>Visualization platform with dashboards and datasources (Grafana Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/loki@main/docs/sources/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system designed for cloud-native applications</td>
    </tr>
    <tr>
        <td>🦀</td>
        <td><a href="https://vector.dev/">Vector</a></td>
        <td>Rust-based observability data pipeline with intelligent log collection and routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/fluentd/fluentd-icon.svg"></td>
        <td><a href="https://www.fluentd.org/">Fluentd</a></td>
        <td>Data collector for unified logging layer with flexible routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/fluent/fluent-bit/master/fluentbit_logo.png"></td>
        <td><a href="https://fluentbit.io/">Fluent Bit</a></td>
        <td>Lightweight log processor optimized for containerized environments</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/docs/latest/operator/">Jaeger</a></td>
        <td>Distributed tracing with collectors and query services (Jaeger Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html">Elasticsearch</a></td>
        <td>Search and analytics engine with Kibana (Elastic Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/docs/kubernetes/operator/">OpenTelemetry</a></td>
        <td>Observability data collection with collectors and instrumentation (OTel Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/75224818?s=200&v=4"></td>
        <td><a href="https://docs.robusta.dev/">Robusta</a></td>
        <td>AI-powered alert enrichment with automated troubleshooting and root cause analysis</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/121251675?s=200&v=4"></td>
        <td><a href="https://www.keephq.dev/">Keep</a></td>
        <td>AIOps platform for alert correlation and centralized incident management</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/151674099?s=200&v=4"></td>
        <td><a href="https://ollama.com/">Ollama</a></td>
        <td>Self-hosted LLM inference engine for AI troubleshooting (DSGVO-compliant)</td>
    </tr>
</table>

## 🗄️ Platform Services

Databases, messaging platforms, and identity management:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">PostgreSQL</a></td>
        <td>High-availability PostgreSQL with automated backups and PITR (CloudNativePG Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/5713248?s=200&v=4"></td>
        <td><a href="https://www.influxdata.com/">InfluxDB</a></td>
        <td>Time series database for high-performance metrics and event storage</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/redis/redis-original.svg"></td>
        <td><a href="https://redis-operator.opstree.dev/">Redis</a></td>
        <td>In-memory data store with sentinel and replication (Redis Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://docs.confluent.io/operator/current/overview.html">Kafka</a></td>
        <td>Event streaming platform with Connect and Schema Registry (Confluent Operator)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/4921466?s=200&v=4"></td>
        <td><a href="https://www.keycloak.org/">Keycloak</a></td>
        <td>Enterprise identity and access management with OIDC and SAML provider</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/103038211?s=200&v=4"></td>
        <td><a href="https://github.com/lldap/lldap">LLDAP</a></td>
        <td>Lightweight LDAP server for authentication and user directory services</td>
    </tr>
</table>

## 🔐 Security

Zero Trust foundation and policy enforcement:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/68448710?s=200&v=4"></td>
        <td><a href="https://kyverno.io/">Kyverno</a></td>
        <td>Kubernetes-native policy engine for security, compliance and governance automation</td>
    </tr>
    <tr>
        <td>🔒</td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Kubernetes controller for one-way encrypted secrets in Git</td>
    </tr>
</table>

---

## 🎯 Cluster Resilience & 99.9% Uptime

### Current Resilience Status

**Estimated Uptime:** ~95-96% (current configuration)

**Target:** 99.9% (43.8 minutes downtime/month, 8.76 hours/year)

### Uptime SLA Reference

| SLA Level | Downtime/Year | Downtime/Month | Downtime/Week | Status |
|-----------|---------------|----------------|---------------|--------|
| 99%       | 3.65 days     | 7.2 hours      | 1.68 hours    | Basic |
| 99.5%     | 1.83 days     | 3.6 hours      | 50.4 minutes  | Standard |
| **99.9%** | **8.76 hours** | **43.8 minutes** | **10.1 minutes** | **Production Target** |
| 99.95%    | 4.38 hours    | 21.9 minutes   | 5.04 minutes  | Enterprise |
| 99.99%    | 52.6 minutes  | 4.38 minutes   | 1.01 minutes  | Mission Critical |

### Infrastructure Health Dashboard

```
Cluster Configuration:
├── Control Plane: 1 node (ctrl-0)          [SINGLE POINT OF FAILURE]
├── Worker Nodes:  6 nodes (worker-1 to 6)  [RESILIENT]
├── Total Nodes:   7 nodes
└── Kubernetes:    v1.33.2 on Talos v1.10.6
```

### Storage Resilience

```
Ceph Storage:
├── OSDs:           6 active (across 6 workers)
├── Replication:    3x (triple redundancy)
├── Failure Domain: host-level
├── Monitors:       3x (worker-1, worker-3, worker-6) [HA]
├── CephFS:         3x metadata pool replicas
├── Object Store:   3x replicas (S3-compatible)
└── Status:         HEALTHY - Can survive 2 OSD failures
```

### High Availability Analysis

#### Components with HA (Resilient)

| Component | Replicas | Anti-Affinity | PDB | Backup | Status |
|-----------|----------|---------------|-----|--------|--------|
| Istio Control Plane | 3 | Yes | Yes | N/A | RESILIENT |
| Ceph Monitors | 3 | Yes | Yes | N/A | RESILIENT |
| Ceph OSDs | 6 (3x replication) | Host-level | Yes | N/A | RESILIENT |
| ArgoCD Redis HA | 3 HAProxy + 3 Redis | Yes | No | Redis AOF | RESILIENT |
| N8N PostgreSQL | 2 instances | Default | Yes | FAILED | PARTIAL |
| N8N Webhook | 2 replicas | No | No | N/A | RESILIENT |
| Elasticsearch | 3 data nodes | Default | Yes | Snapshots | RESILIENT |
| Kafka | 3 brokers | Zone | Yes | N/A | RESILIENT |

#### Single Points of Failure (CRITICAL)

| Component | Current | Required | Impact | Priority |
|-----------|---------|----------|--------|----------|
| Control Plane | 1 node | 3 nodes | Complete cluster failure | P0 |
| Envoy Gateway | 1 replica | 2+ replicas | No ingress traffic | P0 |
| ArgoCD Server | 1 replica | 2+ replicas | No GitOps UI/API | P1 |
| ArgoCD Repo Server | 1 replica | 2+ replicas | No Git sync | P1 |
| Prometheus | 1 replica | 2+ replicas | No metrics collection | P1 |
| Alertmanager | 1 replica | 3+ replicas | No alert routing | P1 |
| Velero | 1 replica | 2+ replicas | No cluster backups | P1 |
| N8N Main | 1 replica | 2+ replicas | No workflow UI | P2 |
| N8N Worker | 1 replica | 2+ replicas | No workflow execution | P2 |

### Backup & Disaster Recovery

#### Current Backup Status

| Workload | Backup Method | Schedule | Retention | Last Backup | Status |
|----------|---------------|----------|-----------|-------------|--------|
| N8N PostgreSQL | CloudNativePG Barman | Daily 04:00 | 7 days | Failed | BROKEN |
| Velero Cluster | None | None | N/A | Never | NOT CONFIGURED |
| Ceph RGW | Manual | None | N/A | N/A | MANUAL ONLY |
| ArgoCD Config | GitOps | Continuous | Infinite | Git | PROTECTED |
| Grafana Dashboards | GrafanaDashboard CRDs | Continuous | Infinite | Git | PROTECTED |

#### Critical Issues

1. N8N PostgreSQL Backups Failing (3+ days)
   - Error: "no barmanObjectStore section defined"
   - Impact: NO DATABASE BACKUPS - Data loss risk!
   - Fix Required: Configure Ceph RGW S3 backend

2. Velero Not Configured
   - No cluster-level backup schedules
   - No disaster recovery capability
   - Fix Required: Create Velero schedules for all namespaces

### Roadmap to 99.9% Uptime

#### Phase 1: Eliminate Critical SPOFs (P0)

1. **Expand Control Plane to 3 Nodes**
   ```bash
   # Add ctrl-1 and ctrl-2 via Terraform
   # Estimated downtime: 0 minutes (rolling)
   # Cost: 2 additional VMs
   ```
   - Current: 1 node (SPOF)
   - Target: 3 nodes (etcd quorum, can survive 1 failure)
   - Impact: Prevents complete cluster failure

2. **Scale Envoy Gateway to 2+ Replicas**
   ```bash
   kubectl scale deployment envoy-gateway -n envoy-gateway-system --replicas=2
   # Add podAntiAffinity to ensure node distribution
   ```
   - Current: 1 replica (SPOF)
   - Target: 2-3 replicas with anti-affinity
   - Impact: Zero-downtime ingress during node failures

#### Phase 2: High Availability for Core Services (P1)

3. **Scale ArgoCD Components**
   ```bash
   # Update ArgoCD Helm values:
   server.replicas: 2
   repoServer.replicas: 2
   # Already HA: Redis (3 HAProxy + 3 Redis)
   ```
   - Target: 2 replicas for server and repo-server
   - Impact: GitOps continues during node failures

4. **Enable Prometheus HA**
   ```bash
   # Update kube-prometheus-stack Helm values:
   prometheus.prometheusSpec.replicas: 2
   prometheus.prometheusSpec.retention: 30d
   alertmanager.alertmanagerSpec.replicas: 3
   ```
   - Target: 2 Prometheus replicas, 3 Alertmanager replicas
   - Impact: Continuous metrics and alerting

5. **Configure Velero Backups**
   ```bash
   # Create Velero schedules:
   - Daily full cluster backup (retain 7 days)
   - Weekly full cluster backup (retain 4 weeks)
   - Monthly full cluster backup (retain 12 months)
   ```
   - Target: Automated cluster backups to Ceph RGW
   - Impact: Disaster recovery capability (RTO: 1 hour, RPO: 24 hours)

#### Phase 3: Application-Level Resilience (P2)

6. **Fix N8N PostgreSQL Backups**
   ```bash
   # Configure barmanObjectStore in CloudNativePG Cluster
   # Point to Ceph RGW S3 endpoint
   # Enable continuous WAL archiving
   ```
   - Target: Daily backups + continuous WAL archiving
   - Impact: Point-in-time recovery (PITR)

7. **Scale N8N Components**
   ```bash
   # Scale N8N main and worker:
   kubectl scale deployment n8n-main -n n8n-prod --replicas=2
   kubectl scale deployment n8n-worker -n n8n-prod --replicas=2
   ```
   - Target: 2 replicas for main and worker
   - Impact: Zero-downtime workflow execution

8. **Add Pod Disruption Budgets**
   ```yaml
   # Create PDBs for all critical workloads
   minAvailable: 1  # For 2-replica deployments
   minAvailable: 2  # For 3+ replica deployments
   ```
   - Target: PDBs for all deployments with 2+ replicas
   - Impact: Prevents simultaneous pod evictions

#### Phase 4: Advanced Resilience Features

9. **Topology Spread Constraints**
   ```yaml
   topologySpreadConstraints:
     - maxSkew: 1
       topologyKey: kubernetes.io/hostname
       whenUnsatisfiable: DoNotSchedule
   ```
   - Target: Even pod distribution across nodes
   - Impact: Better fault tolerance

10. **Health Checks for All Workloads**
    ```yaml
    livenessProbe:  # Auto-restart unhealthy pods
    readinessProbe: # Route traffic only to ready pods
    startupProbe:   # Allow slow-starting apps
    ```
    - Current: 112 pods without liveness probes
    - Target: All pods have proper health checks
    - Impact: Automatic failure detection and recovery

11. **Resource Requests and Limits**
    ```yaml
    resources:
      requests: # Guaranteed resources
        cpu: 100m
        memory: 128Mi
      limits: # Maximum resources
        cpu: 500m
        memory: 512Mi
    ```
    - Target: All pods have requests/limits
    - Impact: Prevents resource contention, enables HPA

### Monitoring & Alerting

#### Critical Alerts Configured

- AllNodesNotReady
- ArgoCDApplicationOutOfSync
- ArgoCDSyncFailed
- CNPGLastFailedArchiveTime
- CertificateExpiresIn24Hours
- CephClusterErrorState
- PrometheusTargetDown

#### Alert Routing

- Slack Integration: BROKEN (webhook 404)
- Fix Required: Regenerate Slack webhook and update sealed secret

### Expected Uptime After Full Implementation

| Phase | Estimated Uptime | Downtime/Month | Notes |
|-------|------------------|----------------|-------|
| Current (Phase 0) | 95-96% | ~30 hours | Multiple SPOFs present |
| Phase 1 Complete | 99.5% | ~3.6 hours | Critical SPOFs eliminated |
| Phase 2 Complete | 99.9% | ~43 minutes | Core services HA |
| Phase 3 Complete | 99.95% | ~22 minutes | Application-level resilience |
| Phase 4 Complete | 99.99% | ~4 minutes | Enterprise-grade (theoretical max for single DC) |

### Implementation Timeline

| Phase | Effort | Risk | Downtime | Priority |
|-------|--------|------|----------|----------|
| Phase 1 | 2-4 hours | Medium | 0 min (rolling) | P0 - Critical |
| Phase 2 | 4-6 hours | Low | 0 min (rolling) | P1 - High |
| Phase 3 | 2-3 hours | Low | 0 min | P2 - Medium |
| Phase 4 | 8-12 hours | Low | 0 min | P3 - Nice to have |
| **Total** | **16-25 hours** | - | **0 min** | - |

### Cost Analysis

| Change | Hardware Cost | Operational Impact |
|--------|---------------|-------------------|
| Add 2 control plane nodes | 2x VMs (~same as worker) | +30% CPU/memory for etcd |
| Scale Envoy Gateway (2x) | $0 | +50 MB memory |
| Scale ArgoCD (2x) | $0 | +200 MB memory |
| Scale Prometheus (2x) | $0 | +4 GB memory (metrics storage) |
| Scale N8N (2x) | $0 | +500 MB memory |
| Total | 2x VMs | +5-6 GB cluster memory |

---

## 🏗️ How to Build This Cluster from Scratch

This section provides a complete blueprint for building a production-ready Kubernetes homelab with 99.9% uptime from the ground up.

### Prerequisites

**Hardware Requirements:**
- Proxmox VE hypervisor (or similar)
- Minimum 7 VMs:
  - 3x Control Plane nodes (4 vCPU, 8 GB RAM each)
  - 4x Worker nodes (8 vCPU, 16 GB RAM each - expandable to 6)
- Storage: 500 GB+ total (for Ceph distributed storage)
- Network: Static IPs or DHCP reservations

**Software Requirements:**
- Domain name (e.g., timourhomelab.org)
- Cloudflare account (for DNS and optional Tunnel)
- GitHub account (for GitOps repository)

### Build Timeline

**Total Time:** 8-12 hours for complete implementation

| Phase | Duration | Complexity |
|-------|----------|------------|
| Infrastructure Setup | 2-3 hours | Medium |
| Core Services | 3-4 hours | High |
| Platform Services | 2-3 hours | Medium |
| Applications & Hardening | 1-2 hours | Low |

---

## Phase 0: Infrastructure Foundation (2-3 hours)

### Step 1: Bootstrap Talos Kubernetes Cluster

**1.1 Prepare OpenTofu Configuration**

```bash
# Clone repository template
git clone https://github.com/yourusername/talos-homelab.git
cd talos-homelab/tofu

# Configure Proxmox provider
cat > proxmox.auto.tfvars <<EOF
proxmox_api_url      = "https://proxmox.local:8006/api2/json"
proxmox_api_token_id = "root@pam!terraform"
proxmox_api_token_secret = "your-secret-here"
EOF

# Configure cluster
cat > cluster.auto.tfvars <<EOF
control_plane_count = 3  # High Availability
worker_count        = 4  # Start with 4, expand to 6 later
cluster_name        = "homelab"
cluster_endpoint    = "192.168.68.100"  # Virtual IP
EOF
```

**1.2 Deploy Talos Cluster**

```bash
# Initialize and apply
tofu init
tofu plan
tofu apply

# Export kubeconfig
export KUBECONFIG=$(pwd)/output/kube-config.yaml
kubectl get nodes
# Expected: 3 control-plane + 4 workers = 7 nodes
```

**Architecture:**
```
Control Plane (HA):
├── ctrl-0: 192.168.68.101 (etcd + kube-apiserver)
├── ctrl-1: 192.168.68.102 (etcd + kube-apiserver)
└── ctrl-2: 192.168.68.106 (etcd + kube-apiserver)

Workers (Compute + Storage):
├── worker-1: 192.168.68.103
├── worker-2: 192.168.68.104
├── worker-3: 192.168.68.105
└── worker-4: 192.168.68.107

Virtual IP: 192.168.68.100 (kube-apiserver endpoint)
```

**Key Decisions:**
- 3 control plane nodes for etcd quorum (can survive 1 failure)
- Even number of workers for Ceph distribution
- Virtual IP for HA API server access

### Step 2: Install ArgoCD (GitOps Engine)

**2.1 Install ArgoCD with HA Redis**

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD with Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.0.0 \
  --set redis-ha.enabled=true \
  --set redis-ha.haproxy.replicas=3 \
  --set server.replicas=2 \
  --set repoServer.replicas=2 \
  --set applicationSet.replicas=2

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**2.2 Configure GitHub Repository**

```bash
# Add repository to ArgoCD
argocd repo add https://github.com/yourusername/talos-homelab.git \
  --username your-github-username \
  --password ghp_your_github_token
```

**Why ArgoCD First?**
- All subsequent resources deployed via GitOps
- Declarative infrastructure management
- Automatic sync from Git
- Audit trail of all changes

### Step 3: Deploy App-of-Apps Pattern

**3.1 Bootstrap ApplicationSets**

```bash
# Apply root ApplicationSet
kubectl apply -f kubernetes/sets/root-applicationset.yaml

# This creates ApplicationSets for:
# - Security (Kyverno, Sealed Secrets)
# - Infrastructure (Networking, Storage, Monitoring)
# - Platform (Databases, Identity)
# - Applications (N8N, Audiobookshelf)
```

**App-of-Apps Architecture:**
```
argocd (root)
├── security/
│   ├── kyverno
│   └── sealed-secrets
├── infrastructure/
│   ├── network (Cilium, Envoy Gateway, Istio)
│   ├── storage (Rook-Ceph, Velero)
│   └── monitoring (Prometheus, Grafana, Loki, Tempo, Jaeger)
├── platform/
│   ├── databases (PostgreSQL, Redis, Kafka)
│   └── identity (Keycloak, LLDAP, Authelia)
└── apps/
    ├── n8n (dev, staging, prod)
    └── audiobookshelf
```

---

## Phase 1: Core Infrastructure (3-4 hours)

### Step 4: Network Layer

**4.1 CNI: Cilium with eBPF**

```bash
# Already installed via ArgoCD
kubectl get pods -n kube-system -l k8s-app=cilium

# Enable Hubble observability
cilium hubble enable --ui
```

**Features:**
- eBPF dataplane (30% faster than iptables)
- Network policies (Zero Trust)
- Hubble observability (flow visualization)
- Gateway API support

**4.2 Gateway API + Envoy Gateway**

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

# Deploy Envoy Gateway (via ArgoCD)
# Scale to 2 replicas for HA
kubectl scale deployment envoy-gateway \
  -n envoy-gateway-system --replicas=2
```

**4.3 Istio Service Mesh (via Sail Operator)**

```bash
# Deploy Istio control plane with 3 replicas (HA)
kubectl apply -f kubernetes/infrastructure/network/istio-control-plane/

# Verify
kubectl get pods -n istio-system
# istiod: 3/3 Running
```

**4.4 Cloudflare Tunnel (Zero Trust Access)**

```bash
# Create Cloudflare API token with DNS:Edit permissions
# Seal the secret
echo -n "your-cloudflare-token" | kubeseal --raw \
  --scope cluster-wide \
  --from-file=/dev/stdin > cloudflare-token-sealed.yaml

# Deploy Cloudflared
kubectl apply -f kubernetes/infrastructure/network/cloudflared/
```

**Traffic Flow:**
```
Internet
  ↓ (HTTPS)
Cloudflare Edge
  ↓ (Cloudflare Tunnel - encrypted)
Cloudflared Pod
  ↓ (Internal)
Envoy Gateway (LoadBalancer)
  ↓ (HTTPRoute)
Istio Ingress Gateway
  ↓ (VirtualService)
Service
  ↓
Pod
```

### Step 5: Storage Layer

**5.1 Rook-Ceph Distributed Storage**

```bash
# Deploy Rook Operator
kubectl apply -f kubernetes/infrastructure/storage/rook-ceph/operator/

# Create CephCluster (6 OSDs, 3x replication)
kubectl apply -f kubernetes/infrastructure/storage/rook-ceph/cluster/

# Wait for cluster to be healthy (5-10 minutes)
kubectl -n rook-ceph get cephcluster
# STATUS: HEALTH_OK

# Create storage classes
kubectl apply -f kubernetes/infrastructure/storage/rook-ceph/storageclass/
```

**Ceph Pools:**
- Block Storage: `ssd-pool` (3x replication, SSD-optimized)
- Object Storage: `homelab-objectstore` (S3-compatible, 3x replication)
- File Storage: `myfs-enterprise` (CephFS, 3x metadata replication)

**5.2 Velero Backup System**

```bash
# Deploy Velero with Ceph RGW backend
kubectl apply -f kubernetes/infrastructure/storage/velero/

# Create backup schedules
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-cluster-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    includedNamespaces:
    - '*'
    ttl: 168h  # 7 days retention
EOF
```

### Step 6: Observability Stack

**6.1 Prometheus + Grafana (Metrics)**

```bash
# Deploy kube-prometheus-stack with HA
kubectl apply -f kubernetes/infrastructure/monitoring/kube-prometheus-stack/

# Scale Prometheus and Alertmanager for HA
kubectl patch prometheusspec kube-prometheus-stack-prometheus \
  --type merge -p '{"spec":{"replicas":2}}'

kubectl patch alertmanagerspec kube-prometheus-stack-alertmanager \
  --type merge -p '{"spec":{"replicas":3}}'
```

**6.2 Loki (Logs)**

```bash
# Deploy Loki with Ceph Object Storage backend
kubectl apply -f kubernetes/infrastructure/monitoring/loki/

# Deploy Vector (log collector - Rust-based, 10x faster than Fluentd)
kubectl apply -f kubernetes/infrastructure/monitoring/vector/
```

**6.3 Tempo (Distributed Tracing)**

```bash
# Deploy Tempo with Ceph Object Storage
kubectl apply -f kubernetes/infrastructure/monitoring/tempo/

# Enable tracing in applications (OpenTelemetry)
```

**6.4 Jaeger (Trace Visualization)**

```bash
# Deploy Jaeger Operator
kubectl apply -f kubernetes/infrastructure/monitoring/jaeger/
```

**6.5 Grafana Dashboards (via Operator)**

```bash
# Deploy 64 enterprise dashboards as GrafanaDashboard CRDs
kubectl apply -f kubernetes/infrastructure/monitoring/grafana/enterprise-dashboards/

# Access Grafana
kubectl get secret -n grafana grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
```

**Pre-configured Dashboards:**
- Kubernetes Global View
- Prometheus Targets & Health
- Certificate Manager Status
- Node System Overview
- Ceph Cluster Monitoring
- PostgreSQL Database Stats
- N8N Workflow Metrics
- Istio Service Mesh

---

## Phase 2: Platform Services (2-3 hours)

### Step 7: Identity & Access Management

**7.1 LLDAP (Lightweight LDAP)**

```bash
# Deploy LLDAP
kubectl apply -f kubernetes/platform/identity/lldap/

# Default admin user: admin
# Create users and groups for SSO
```

**7.2 Keycloak (Enterprise IAM)**

```bash
# Deploy Keycloak with PostgreSQL HA backend
kubectl apply -f kubernetes/platform/identity/keycloak/

# Access: https://iam.timourhomelab.org
# Configure LDAP federation to LLDAP
# Create OIDC clients for apps
```

**7.3 Authelia (2FA & SSO)**

```bash
# Deploy Authelia
kubectl apply -f kubernetes/platform/identity/authelia/

# Configure OIDC to Keycloak
# Enable MFA (TOTP, WebAuthn)
```

**SSO Flow:**
```
User → App → Authelia (2FA) → Keycloak (OIDC) → LLDAP (Users) → Access Granted
```

### Step 8: Databases

**8.1 CloudNativePG (PostgreSQL Operator)**

```bash
# Deploy CloudNativePG Operator
kubectl apply -f kubernetes/infrastructure/controllers/cloudnative-pg/

# Create PostgreSQL clusters for apps
kubectl apply -f kubernetes/platform/databases/postgres/
```

**8.2 Redis (Cache & Sessions)**

```bash
# Deploy Redis Operator
kubectl apply -f kubernetes/platform/databases/redis/
```

**8.3 Kafka (Event Streaming)**

```bash
# Deploy Confluent Operator
kubectl apply -f kubernetes/platform/databases/kafka/

# Create Kafka cluster with 3 brokers
```

---

## Phase 3: Applications (1-2 hours)

### Step 9: Deploy N8N (Workflow Automation)

**9.1 N8N Production with HA**

```bash
# Deploy N8N with:
# - 2x PostgreSQL instances (HA)
# - 2x Webhook processors (HA)
# - 1x Main instance
# - 1x Worker instance
kubectl apply -f kubernetes/apps/base/n8n/environments/production/

# Access: https://n8n.timourhomelab.org
```

**9.2 Configure Backups**

```bash
# PostgreSQL backup to Ceph RGW
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: n8n-postgres-daily-backup
  namespace: n8n-prod
spec:
  schedule: "0 4 * * *"  # 4 AM daily
  backupOwnerReference: self
  cluster:
    name: n8n-postgres
  method: barmanObjectStore
  target: prefer-standby
EOF
```

### Step 10: Deploy Audiobookshelf

```bash
kubectl apply -f kubernetes/apps/base/audiobookshelf/

# Access: https://audiobooks.timourhomelab.org
```

---

## Phase 4: Security & Hardening (1 hour)

### Step 11: Network Policies (Zero Trust)

```bash
# Deploy Cilium Network Policies for all namespaces
kubectl apply -f kubernetes/security/foundation/network-policies/

# Default: Deny all traffic except explicitly allowed
```

**Example Policy (N8N Production):**
```yaml
# Allow N8N to access PostgreSQL only
# Deny all other traffic
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: n8n-prod-network-policy
  namespace: n8n-prod
spec:
  endpointSelector:
    matchLabels:
      app: n8n
  egress:
  - toEndpoints:
    - matchLabels:
        cnpg.io/cluster: n8n-postgres
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
```

### Step 12: Pod Security Standards

```bash
# Deploy Kyverno policies
kubectl apply -f kubernetes/security/policies/

# Enforce:
# - No privileged containers
# - Read-only root filesystem
# - Drop all capabilities
# - Non-root user required
```

### Step 13: Secret Management

```bash
# All secrets stored as SealedSecrets in Git
# Example: Seal a new secret
echo -n "my-secret-value" | kubeseal --raw \
  --name my-secret \
  --namespace my-namespace \
  --from-file=/dev/stdin > my-sealed-secret.yaml

# Commit to Git - safe!
git add my-sealed-secret.yaml
git commit -m "feat: add new sealed secret"
```

---

## Verification & Testing

### Health Checks

```bash
# 1. All nodes ready
kubectl get nodes
# Expected: 7/7 Ready

# 2. All ArgoCD apps synced
kubectl get application -n argocd
# Expected: All "Synced" and "Healthy"

# 3. Ceph cluster healthy
kubectl -n rook-ceph get cephcluster
# Expected: HEALTH_OK

# 4. All pods running
kubectl get pods -A | grep -vE "Running|Completed"
# Expected: Empty (no failed pods)

# 5. Certificate validation
kubectl get certificate -A
# Expected: All "True" in READY column

# 6. Ingress traffic working
curl -k https://grafana.timourhomelab.org
# Expected: HTTP 200
```

### Performance Benchmarks

```bash
# Network throughput (eBPF)
kubectl run -it --rm netperf --image=networkstatic/iperf3 \
  -- iperf3 -c worker-2 -t 30
# Expected: 10+ Gbps on local network

# Storage IOPS (Ceph)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-test
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ssd-pool
  resources:
    requests:
      storage: 10Gi
EOF

kubectl run -it --rm fio \
  --image=nixery.dev/shell/fio \
  --overrides='{"spec":{"volumes":[{"name":"fio","persistentVolumeClaim":{"claimName":"fio-test"}}],"containers":[{"name":"fio","image":"nixery.dev/shell/fio","volumeMounts":[{"name":"fio","mountPath":"/mnt"}],"command":["fio","--name=test","--directory=/mnt","--size=1G","--bs=4k","--rw=randrw","--ioengine=libaio","--direct=1","--numjobs=4","--runtime=60","--group_reporting"]}]}}' \
  -- /bin/true
# Expected: 10k+ IOPS
```

---

## 🎓 Key Lessons & Best Practices

### 1. Always Use GitOps
- Every change goes through Git
- ArgoCD auto-syncs from main branch
- Rollback is just a git revert
- Audit trail for compliance

### 2. High Availability by Default
- 3 control plane nodes (etcd quorum)
- 2+ replicas for stateless apps
- 3+ replicas for stateful apps (Prometheus, Kafka)
- PodDisruptionBudgets for critical workloads

### 3. Observability is Non-Negotiable
- Metrics: Prometheus (2 replicas)
- Logs: Loki + Vector
- Traces: Tempo + Jaeger
- Dashboards: Grafana (64 pre-configured dashboards)
- Alerts: Alertmanager (3 replicas)

### 4. Security Layers
- Network: Cilium Network Policies (Zero Trust)
- Secrets: SealedSecrets (encrypted in Git)
- Policies: Kyverno (Pod Security Standards)
- Identity: Keycloak + Authelia (SSO + 2FA)
- Mesh: Istio (mTLS between services)

### 5. Backup Everything
- Cluster: Velero (daily backups to Ceph RGW)
- Databases: CloudNativePG (continuous WAL archiving)
- Config: Git (all manifests version-controlled)
- RTO: 1 hour, RPO: 24 hours

---

## Common Pitfalls & Solutions

### Issue 1: Ceph OSDs Won't Start
**Symptom:** OSDs stuck in `CrashLoopBackOff`

**Solution:**
```bash
# Check OSD logs
kubectl logs -n rook-ceph <osd-pod>

# Common causes:
# - Disk already has partitions (clean with wipefs)
# - Insufficient permissions (check securityContext)
# - Wrong device path (verify in cluster.yaml)
```

### Issue 2: PostgreSQL Backups Failing
**Symptom:** `no barmanObjectStore section defined`

**Solution:**
```bash
# Add barmanObjectStore to Cluster spec
kubectl edit cluster -n n8n-prod n8n-postgres

# Add:
spec:
  backup:
    barmanObjectStore:
      destinationPath: s3://homelab-objectstore/n8n-prod/
      s3Credentials:
        accessKeyId:
          name: ceph-s3-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: ceph-s3-credentials
          key: SECRET_ACCESS_KEY
      endpointURL: http://rook-ceph-rgw-homelab-objectstore.rook-ceph:80
```

### Issue 3: Certificates Not Renewing
**Symptom:** `Certificate expires in 24 hours` alert

**Solution:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Force renewal
kubectl delete certificate <cert-name> -n <namespace>
# ArgoCD will recreate it automatically
```

---

## Next Steps: Achieving 99.9% Uptime

After completing all phases, implement the resilience improvements from the **Cluster Resilience & 99.9% Uptime** section above:

1. Phase 1 (P0): Already done by following this guide!
2. Phase 2 (P1): Configure Velero schedules + scale monitoring
3. Phase 3 (P2): Add PDBs + health checks
4. Phase 4 (P3): Topology spread + resource quotas

**Estimated Current Uptime:** 99.5% (following this guide)
**Target Uptime:** 99.9% (after Phase 2 improvements)

---
