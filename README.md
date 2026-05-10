<h1 align="center">Homelab 🏡</h1>

Repository for home infrastructure and Kubernetes cluster using GitOps practices.

Held together using Proxmox VE, OpenTofu, Talos Linux, Kubernetes, Argo CD and copious amounts of YAML — with some help from Renovate.

[![Talos](https://img.shields.io/badge/OS-Talos%20Linux-FF7300?style=for-the-badge&logo=linux&logoColor=white)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-844FBA?style=for-the-badge&logo=opentofu&logoColor=white)](https://opentofu.org/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-00D4AA?style=for-the-badge&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Renovate](https://img.shields.io/badge/Deps-Renovate-1F8FFF?style=for-the-badge&logo=renovatebot&logoColor=white)](https://docs.renovatebot.com/)

## 📖 Overview

This repository hosts the IaC (Infrastructure as Code) configuration for a production-grade Kubernetes homelab.

The cluster runs **Talos Linux** on **Proxmox VE** hypervisor nodes, with VMs bootstrapped using **OpenTofu**.
**Argo CD** manages everything declaratively from this repo using the App-of-Apps pattern, layered into:
`security → infrastructure → platform → apps`.

## 🧑‍💻 Getting Started

The cluster is bootstrapped from `tofu/` (Proxmox VMs + Talos config) and then handed off to Argo CD, which reconciles
everything under `kubernetes/`. The full bootstrap order:

1. `tofu apply` → Proxmox VMs provisioned, Talos installed, kubeconfig written.
2. `kubectl apply -k kubernetes/bootstrap/` → installs Argo CD + Sealed Secrets + ApplicationSets.
3. Argo CD takes over and syncs the rest of the repo automatically.

## 🗃️ Folder Structure

```
.
├── 📂 kubernetes                  # All cluster state (managed by Argo CD)
│   │
│   ├── bootstrap                 # App-of-Apps root
│   ├── clusters                  # Cluster registrations
│   ├── projects                  # Argo CD AppProjects
│   ├── applicationsets           # ApplicationSet-based deployment
│   │   ├── tenants               #   per-tenant AppSets
│   │   ├── infrastructure        #   controllers, network, storage, observability
│   │   ├── platform              #   data, identity
│   │   ├── security              #   foundation, compliance
│   │   └── edge                  #   staging cluster
│   ├── components                # Reusable Kustomize components
│   ├── security                  # Network-policies, RBAC, Kyverno, compliance
│   ├── infrastructure            # Cluster-shared services
│   │   ├── controllers           #   Argo CD, cert-manager, sealed-secrets, operators
│   │   ├── network               #   Cilium, Envoy Gateway, Cloudflare Tunnel, CoreDNS
│   │   ├── storage               #   Rook-Ceph, Velero
│   │   ├── observability         #   Prometheus, Loki, Tempo, Jaeger, Grafana, ES, Vector
│   │   └── vpn                   #   Tailscale, NetBird
│   ├── platform                  # Platform services
│   │   ├── identity              #   Keycloak, LLDAP
│   │   ├── data                  #   CNPG Postgres, Redis, CloudBeaver
│   │   ├── messaging             #   Strimzi Kafka
│   │   └── governance/tenants    #   per-tenant RBAC
│   └── apps                      # User-facing applications
│       ├── base                  #   shared manifests
│       └── overlays              #   environment patches
│
├── 🧱 tofu                        # OpenTofu (Terraform fork)
│   ├── bootstrap                 #   Sealed-secrets cert + key
│   ├── talos                     #   Talos machine-configs
│   └── gitlab                    #   GitLab VM
│
└── ⚙️  scripts                     # Operations scripts
    ├── identity                  #   onboard-user, kubeconfig-oidc
    └── upgrades                  #   pre-upgrade, post-upgrade-verify
```

### 🚦 GitOps Pattern

The cluster uses **11 ApplicationSets** for selective multi-cluster deployment:
- **Multi-Cluster-Ready** — new cluster registers with `<tier>.tier=enabled` labels → AppSet auto-generates apps
- **Tenant-Encapsulation** — each tenant (Drova, n8n) managed by **1 AppSet** instead of 4 single Applications
- **Edge-Selective** — Raspberry-Pi staging cluster gets only light-workloads (Cilium + Prom + Grafana), not heavy stuff like Loki/Tempo/Kafka

## 📦 Applications

End-user applications deployed via Argo CD across dev / staging / production overlays:

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://n8n.io/favicon.ico"></td>
        <td><a href="https://n8n.io/">n8n</a></td>
        <td>Secure, AI-native workflow automation (dev + prod)</td>
    </tr>
    <tr>
        <td>🚗</td>
        <td><a href="https://github.com/Tim275/drova-gitops">Drova</a></td>
        <td>Ride-sharing microservices showcase — api-gateway, user, trip, driver, chat, payment services with Kafka, CNPG Postgres, Redis, OpenTelemetry tracing, Cilium-SPIRE mTLS, tiered backups</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://strimzi.io/">Kafka (Strimzi)</a></td>
        <td>Event streaming clusters — KafkaCluster CR, Topics, Users, Schema-Registry. Used by Drova services</td>
    </tr>
    <tr>
        <td><img width="32" src="https://dbeaver.io/wp-content/uploads/2015/09/beaver-head.png"></td>
        <td><a href="https://dbeaver.io/docs/cloudbeaver/">CloudBeaver</a></td>
        <td>Web-based database management UI for Postgres, MongoDB and more</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.audiobookshelf.org/Logo.png"></td>
        <td><a href="https://www.audiobookshelf.org/">Audiobookshelf</a></td>
        <td>Self-hosted audiobook and podcast server</td>
    </tr>
</table>

## 🔧 Kubernetes Operators

Lifecycle, scaling, and HA management for stateful workloads:

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/cilium/cilium/Documentation/images/logo-solo.svg"></td>
        <td><a href="https://cilium.io/">Cilium Operator</a></td>
        <td>eBPF CNI with WireGuard, SPIRE-mTLS, Hubble visibility, L2 announcements</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph Operator</a></td>
        <td>Distributed storage with block (RBD), file (CephFS) and object (RGW S3)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">Cert-Manager</a></td>
        <td>TLS certificate automation with Let's Encrypt</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus-operator.dev/">Prometheus Operator</a></td>
        <td>Manages Prometheus, AlertManager (3-replica HA) and ServiceMonitors</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana-operator.github.io/grafana-operator/">Grafana Operator</a></td>
        <td>Manages Grafana instances, datasources, and 83 dashboards as CRDs</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/docs/latest/operator/">Jaeger Operator</a></td>
        <td>Distributed tracing collectors with Service Performance Monitoring</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html">Elastic Operator (ECK)</a></td>
        <td>Elasticsearch + Kibana with ILM policies and snapshot repository</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/docs/kubernetes/operator/">OpenTelemetry Operator</a></td>
        <td>OTel Collectors as DaemonSet + auto-instrumentation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://strimzi.io/">Strimzi Operator</a></td>
        <td>Kafka cluster management (KafkaCluster, Topics, Users)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/redis/redis-original.svg"></td>
        <td><a href="https://redis-operator.opstree.dev/">Redis Operator</a></td>
        <td>Redis Standalone / Replication / Sentinel / Cluster</td>
    </tr>
    <tr>
        <td><img width="32" src="https://tailscale.com/files/press/tailscale-symbol-color.svg"></td>
        <td><a href="https://tailscale.com/kb/1236/kubernetes-operator">Tailscale Operator</a></td>
        <td>SaaS-coordinated Mesh-VPN for kubectl + cluster-internal access</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/netbirdio/netbird/main/docs/media/logo-full.png"></td>
        <td><a href="https://docs.netbird.io/selfhosted/selfhosted-quickstart">NetBird</a></td>
        <td>Self-hosted Mesh-VPN — coordination in cluster, OIDC via Keycloak</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/argoproj/argo-cd/master/docs/assets/argo.png"></td>
        <td><a href="https://argo-rollouts.readthedocs.io/">Argo Rollouts</a></td>
        <td>Progressive delivery — blue-green and canary deployment strategies</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG Operator</a></td>
        <td>Postgres HA with Barman Cloud Plugin backups + PITR</td>
    </tr>
</table>

## 🛠️ Infrastructure

GitOps, networking, storage, backup and observability core services:

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/argoproj/argo-cd/master/docs/assets/argo.png"></td>
        <td><a href="https://argo-cd.readthedocs.io/">Argo CD</a></td>
        <td>Declarative GitOps continuous delivery with HA Redis backend, ApplicationSets, and OIDC via Keycloak</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/main/site-src/images/logo/logo.svg"></td>
        <td><a href="https://gateway-api.sigs.k8s.io/">Gateway API</a></td>
        <td>Vendor-neutral next-gen ingress — HTTPRoute, BackendTrafficPolicy, ClientTrafficPolicy</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/30125649?s=200&v=4"></td>
        <td><a href="https://gateway.envoyproxy.io/">Envoy Gateway</a></td>
        <td>High-performance Gateway API implementation with TLS termination and global rate limiting (Redis-backed)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/cloudflare/cloudflare-icon.svg"></td>
        <td><a href="https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/">Cloudflare Tunnel</a></td>
        <td>Zero-trust secure tunnel for external access — no port forwarding required</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/cilium/cilium/Documentation/images/logo-solo.svg"></td>
        <td><a href="https://github.com/cilium/hubble">Hubble UI</a></td>
        <td>Network observability — service dependencies and L3-L7 flows visualization</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph</a></td>
        <td>6 OSDs across 6 workers — block storage, CephFS, S3-compatible RGW with auto-cleanup CronJobs</td>
    </tr>
    <tr>
        <td><img width="32" src="https://velero.io/img/velero.svg"></td>
        <td><a href="https://velero.io/">Velero</a></td>
        <td>Cluster backup + DR with Ceph-RGW S3 backend, tiered schedules (hourly/daily/weekly)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus-operator.dev/">Prometheus + Alertmanager</a></td>
        <td>Metrics with 78 custom alerts + 80 default kube-prom rules; AM 3-replica HA, 30d retention</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana-operator.github.io/grafana-operator/">Grafana</a></td>
        <td>83 dashboards (Drova RED, Ceph, K8s, SLO burn-rate, etc.) with Three-Pillar correlation wired</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/loki@main/docs/sources/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation on Ceph-S3 backend (memberlist ring, RF=2, 30d retention)</td>
    </tr>
    <tr>
        <td>🦀</td>
        <td><a href="https://vector.dev/">Vector</a></td>
        <td>Rust-based log pipeline (DaemonSet + Aggregator) — sinks to Loki + Elasticsearch</td>
    </tr>
    <tr>
        <td><img width="32" src="https://grafana.com/static/assets/img/tempo.svg"></td>
        <td><a href="https://grafana.com/oss/tempo/">Tempo</a></td>
        <td>Trace storage on Ceph-S3 — service-graph + span-metrics generator → Prometheus</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/">Jaeger v2</a></td>
        <td>Distributed tracing UI with SPM (Service Performance Monitoring), backed by Elasticsearch</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/">OpenTelemetry Collector</a></td>
        <td>Unified telemetry pipeline (DaemonSet) — traces → Tempo+Jaeger, logs → Loki+ES, metrics → Prom remote-write</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html">Elasticsearch + Kibana</a></td>
        <td>Search and analytics for log analytics + Jaeger trace storage</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/telegram/telegram-icon.svg"></td>
        <td>Telegram + Slack</td>
        <td>Mobile + desktop alerting — all Alertmanager notifications routed by severity (critical/warning/info)</td>
    </tr>
</table>

## 🗄️ Platform Services

Databases, messaging, identity:

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">PostgreSQL (CNPG)</a></td>
        <td>HA Postgres with Barman Cloud plugin backups, PgBouncer pooling — drova, n8n-prod, n8n-dev, keycloak-db</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/5713248?s=200&v=4"></td>
        <td><a href="https://www.influxdata.com/">InfluxDB</a></td>
        <td>Time-series database for high-frequency metrics</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/redis/redis-original.svg"></td>
        <td><a href="https://redis-operator.opstree.dev/">Redis</a></td>
        <td>HA Redis Replication for n8n queues + drova session cache + envoy-gateway rate-limiter backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://strimzi.io/">Kafka</a></td>
        <td>Event streaming with KRaft mode — drova-kafka (tenant-scoped) + main kafka cluster</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/4921466?s=200&v=4"></td>
        <td><a href="https://www.keycloak.org/">Keycloak</a></td>
        <td>Enterprise OIDC / SAML provider with LDAP federation — single sign-on for ArgoCD, Grafana, n8n</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/103038211?s=200&v=4"></td>
        <td><a href="https://github.com/lldap/lldap">LLDAP</a></td>
        <td>Lightweight LDAP server backing Keycloak's user federation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://about.gitlab.com/images/press/logo/png/gitlab-icon-rgb.png"></td>
        <td><a href="https://gitlab.com/">GitLab CE</a></td>
        <td>Self-hosted Git platform with CI/CD — runs as VM on Proxmox (separate from K8s)</td>
    </tr>
</table>

## 🔐 Security

Zero-trust foundation, policy enforcement and compliance:

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/68448710?s=200&v=4"></td>
        <td><a href="https://kyverno.io/">Kyverno</a></td>
        <td>Policy-as-code engine in Enforce mode — restrict-image-registries, disallow-privileged, no-host-namespaces, run-as-non-root, resource-limits</td>
    </tr>
    <tr>
        <td>🔏</td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Bitnami controller for one-way encrypted secrets safe to commit (auto key-rotation 30d)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/65063391?s=200&v=4"></td>
        <td><a href="https://github.com/spiffe/spire">SPIRE</a></td>
        <td>SPIFFE Workload Identity — Cilium-integrated, automatic SVID issuance for Pod-to-Pod mTLS</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/65063391?s=200&v=4"></td>
        <td><a href="https://kubescape.io/">Kubescape</a></td>
        <td>Multi-framework compliance scanner (NSA, MITRE ATT&CK, CIS, ArmoBest)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/12783832?s=200&v=4"></td>
        <td><a href="https://aquasecurity.github.io/kube-bench/">kube-bench</a></td>
        <td>CIS Kubernetes Benchmark scanner (Talos-aware policies-target only)</td>
    </tr>
</table>
