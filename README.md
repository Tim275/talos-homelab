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
End User Applications

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
        <td>Real-time email notification system consuming Kafka messages and sending welcome emails</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="kubernetes/apps/base/kafka-demo/">Kafka User Producer</a></td>
        <td>Kafka message producer for user registration events with dynamic email routing</td>
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
        <td>CNI networking operator with eBPF dataplane for pod networking, network policies and Hubble observability</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph Operator</a></td>
        <td>Storage orchestration operator managing CephCluster with block, object and file storage backends</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/23534644?s=200&v=4"></td>
        <td><a href="https://istio.io/">Sail Operator</a></td>
        <td>Istio service mesh lifecycle operator managing control plane, gateways and mTLS configuration</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">Cert-Manager</a></td>
        <td>TLS certificate automation operator with Let's Encrypt integration and certificate lifecycle management</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus-operator.dev/">Prometheus Operator</a></td>
        <td>Metrics collection operator managing Prometheus, AlertManager and ServiceMonitor resources</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana-operator.github.io/grafana-operator/">Grafana Operator</a></td>
        <td>Dashboard lifecycle operator managing Grafana instances, dashboards and datasource configuration</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/docs/latest/operator/">Jaeger Operator</a></td>
        <td>Distributed tracing operator managing Jaeger instances, collectors and query services</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html">Elastic Operator</a></td>
        <td>Elasticsearch and Kibana orchestration operator managing clusters, indices and lifecycle policies</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/docs/kubernetes/operator/">OpenTelemetry Operator</a></td>
        <td>Observability data collection operator managing collectors, instrumentation and telemetry pipelines</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://docs.confluent.io/operator/current/overview.html">Confluent Operator</a></td>
        <td>Kafka enterprise operator managing clusters, Connect, Schema Registry and KRaft mode</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/redis/redis-original.svg"></td>
        <td><a href="https://redis-operator.opstree.dev/">Redis Operator</a></td>
        <td>Redis lifecycle operator managing standalone, sentinel and replication instances with automated failover</td>
    </tr>
    <tr>
        <td><img width="32" src="https://tailscale.com/files/press/tailscale-symbol-color.svg"></td>
        <td><a href="https://tailscale.com/kb/1236/kubernetes-operator">Tailscale Operator</a></td>
        <td>VPN connectivity operator managing connectors, subnet routes and secure mesh networking</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG Operator</a></td>
        <td>PostgreSQL HA operator managing clusters, automated backups, poolers and point-in-time recovery</td>
    </tr>
</table>

## ⚙️ Infrastructure

Classic Helm applications deployed without operators:

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
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/loki@main/docs/sources/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system designed for cloud-native applications</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/fluentd/fluentd-icon.svg"></td>
        <td><a href="https://www.fluentd.org/">Fluentd</a></td>
        <td>Data collector for building unified logging layer with flexible routing and transformation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/fluent/fluent-bit/master/fluentbit_logo.png"></td>
        <td><a href="https://fluentbit.io/">Fluent Bit</a></td>
        <td>Lightweight log processor and forwarder optimized for containerized environments</td>
    </tr>
    <tr>
        <td>🦀</td>
        <td><a href="https://vector.dev/">Vector</a></td>
        <td>Rust-based observability data pipeline with intelligent log collection, transformation and routing</td>
    </tr>
    <tr>
        <td>🔒</td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Kubernetes controller for one-way encrypted secrets</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.yuribacciarini.com/content/images/2023/07/image-4.png"></td>
        <td><a href="https://github.com/sergelogvinov/proxmox-csi-plugin">Proxmox CSI</a></td>
        <td>Container Storage Interface for Proxmox VE with ZFS backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/main/site-src/images/logo/logo.svg"></td>
        <td><a href="https://gateway-api.sigs.k8s.io/">Gateway API</a></td>
        <td>Next-generation ingress API for Kubernetes with vendor-neutral traffic routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/30125649?s=200&v=4"></td>
        <td><a href="https://gateway.envoyproxy.io/">Envoy Gateway</a></td>
        <td>High-performance Gateway API implementation powered by Envoy Proxy with TLS termination and advanced routing</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/cloudflare/cloudflare-icon.svg"></td>
        <td><a href="https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/">Cloudflare Tunnel</a></td>
        <td>Zero-Trust secure tunnel for external access without port forwarding</td>
    </tr>
    <tr>
        <td><img width="32" src="https://velero.io/img/velero.svg"></td>
        <td><a href="https://velero.io/">Velero</a></td>
        <td>Kubernetes backup and disaster recovery with Ceph Object Storage backend</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/68448710?s=200&v=4"></td>
        <td><a href="https://kyverno.io/">Kyverno</a></td>
        <td>Kubernetes-native policy engine for security, compliance and governance automation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.authelia.com/images/branding/logo-cropped.png"></td>
        <td><a href="https://www.authelia.com/">Authelia</a></td>
        <td>Single Sign-On and Multi-Factor authentication portal with OIDC provider</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/103038211?s=200&v=4"></td>
        <td><a href="https://github.com/lldap/lldap">LLDAP</a></td>
        <td>Lightweight LDAP server for authentication and user directory services</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/5713248?s=200&v=4"></td>
        <td><a href="https://www.influxdata.com/">InfluxDB</a></td>
        <td>Time series database for high-performance metrics and event storage</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/75224818?s=200&v=4"></td>
        <td><a href="https://docs.robusta.dev/">Robusta</a></td>
        <td>AI-powered alert enrichment with HolmesGPT integration for automated troubleshooting and root cause analysis</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/121251675?s=200&v=4"></td>
        <td><a href="https://www.keephq.dev/">Keep</a></td>
        <td>AIOps platform for alert correlation, centralized alert management and AI-powered incident analysis</td>
    </tr>
</table>

## 🧠 Platform Services

AI and middleware services supporting applications:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/151674099?s=200&v=4"></td>
        <td><a href="https://ollama.com/">Ollama</a></td>
        <td>Self-hosted LLM inference engine for HolmesGPT AI troubleshooting (DSGVO-compliant)</td>
    </tr>
</table>
