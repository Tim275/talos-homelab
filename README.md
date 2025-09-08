# 🚧 Talos Kubernetes Cluster Playground 🛠️

A fully automated, modular Kubernetes cluster project for homelab and testing, powered by [Talos Linux](https://www.talos.dev/) 🐧, [OpenTofu](https://opentofu.org/) 🌱, and [Proxmox VE](https://www.proxmox.com/) 🖥️.

------

## Apps
End User Applications

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://docs.n8n.io/assets/images/n8n-logo-bw-48481e14ce16c3b5e9e30842f2f6aa20.png"></td>
        <td><a href="https://n8n.io/">n8n</a></td>
        <td>Secure, AI-native workflow automation</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.audiobookshelf.org/Logo.png"></td>
        <td><a href="https://www.audiobookshelf.org/">Audiobookshelf</a></td>
        <td>Self-hosted audiobook and podcast server</td>
    </tr>
</table>



## Infrastructure

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
        <td><a href="https://argo-cd.readtreadthedocs.io/">ArgoCD</a></td>
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
        <td><img width="32" src="https://strimzi.io/assets/images/strimzi_logo.png"></td>
        <td><a href="https://strimzi.io/">Strimzi Kafka</a></td>
        <td>Apache Kafka platform running on Kubernetes with enterprise-grade streaming and messaging</td>
    </tr>
    <tr>
        <td><img width="32" src="https://landscape.cncf.io/logos/istio.svg"></td>
        <td><a href="https://istio.io/">Istio</a></td>
        <td>Service mesh providing secure, observable and controlled microservice communication</td>
    </tr>
</table>

