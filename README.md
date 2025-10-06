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



## ⚙️ Infrastructure

Everything needed to run my cluster & deploy my applications:

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/cilium/cilium/Documentation/images/logo-solo.svg"></td>
        <td><a href="https://cilium.io/">Cilium</a></td>
        <td>eBPF-based networking, observability and security for Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/argoproj/argo-cd/master/docs/assets/argo.png"></td>
        <td><a href="https://argo-cd.readthedocs.io/">ArgoCD</a></td>
        <td>Declarative GitOps continuous delivery for Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus.io/">Prometheus</a></td>
        <td>Monitoring system and time series database for metrics collection</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana.com/">Grafana</a></td>
        <td>Analytics and monitoring platform with rich visualization dashboards</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/loki@main/docs/sources/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system designed for cloud-native applications</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/elasticsearch/elasticsearch-original.svg"></td>
        <td><a href="https://www.elastic.co/elasticsearch/">Elasticsearch</a></td>
        <td>Distributed search and analytics engine for centralized log storage and analysis</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/kibana/kibana-original.svg"></td>
        <td><a href="https://www.elastic.co/kibana/">Kibana</a></td>
        <td>Data visualization and exploration platform for Elasticsearch with dashboards and analytics</td>
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
        <td>Rust-based observability data pipeline with intelligent log collection, transformation and routing to Elasticsearch</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ceph.io/assets/favicons/favicon-32x32.png"></td>
        <td><a href="https://rook.io/">Rook Ceph</a></td>
        <td>Cloud-native storage orchestrator with distributed Ceph backend for block, object and file storage</td>
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
        <td>🚨</td>
        <td><a href="https://prometheus.io/docs/alerting/latest/alertmanager/">Alertmanager</a></td>
        <td>Alert routing and notification system with Slack integration</td>
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
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">cert-manager</a></td>
        <td>Automatic SSL certificate management with Let's Encrypt integration</td>
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
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/postgresql.svg"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG (CNPG)</a></td>
        <td>PostgreSQL database with automated backups, high availability and cloud-native operations</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.mongodb.com/assets/images/global/favicon.ico"></td>
        <td><a href="https://github.com/mongodb/mongodb-kubernetes-operator">MongoDB Operator</a></td>
        <td>MongoDB database with replica sets, sharding and automated management in Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/apache_kafka/apache_kafka-icon.svg"></td>
        <td><a href="https://kafka.apache.org/">Kafka</a></td>
        <td>Apache Kafka platform running on Kubernetes with enterprise-grade streaming and messaging</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/23534644?s=200&v=4"></td>
        <td><a href="https://istio.io/">Istio</a></td>
        <td>Service mesh providing secure, observable and controlled microservice communication</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.jaegertracing.io/img/jaeger-icon-color.png"></td>
        <td><a href="https://www.jaegertracing.io/">Jaeger</a></td>
        <td>Distributed tracing system for monitoring and troubleshooting microservices-based applications</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/42351474?s=200&v=4"></td>
        <td><a href="https://kiali.io/">Kiali</a></td>
        <td>Observability console for Istio with service mesh topology, metrics and traffic visualization</td>
    </tr>
    <tr>
        <td><img width="32" src="https://redis.io/wp-content/uploads/2024/04/Logotype.svg?auto=webp&quality=85,75&width=120"></td>
        <td><a href="https://redis.io/">Redis</a></td>
        <td>In-memory data store used for caching, message queuing and session storage</td>
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
        <td><img width="32" src="https://avatars.githubusercontent.com/u/65666196?s=200&v=4"></td>
        <td><a href="https://redpanda.com/">Redpanda Console</a></td>
        <td>Web UI for Kafka management with topic browsing, consumer groups and schema registry</td>
    </tr>
    <tr>
        <td><img width="32" src="https://kubernetes.io/images/favicon.png"></td>
        <td><a href="https://kubernetes.io/docs/concepts/cluster-administration/addons/#metrics-server">Metrics Server</a></td>
        <td>Cluster-wide aggregator of resource usage data for HPA and kubectl top</td>
    </tr>
</table>
