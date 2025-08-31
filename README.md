# 🚧 Talos Kubernetes Cluster Playground 🛠️

A fully automated, modular Kubernetes cluster project for homelab and testing, powered by [Talos Linux](https://www.talos.dev/) 🐧, [OpenTofu](https://opentofu.org/) 🌱, and [Proxmox VE](https://www.proxmox.com/) 🖥️.

------

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
</table>



## 🚀 Quick Start

### 1. Deploy Infrastructure
```bash
cd tofu/
tofu apply
```

### 2. **🚨 CRITICAL: Restore SealedSecrets Keys**
```bash
# Set kubeconfig
export KUBECONFIG="$PWD/tofu/output/kube-config.yaml"

# Restore SealedSecrets (REQUIRED after every cluster recreation)
./post-deploy-restore.sh
```

### 3. Bootstrap GitOps
```bash
# Deploy ArgoCD and ApplicationSets
kubectl apply -k kubernetes/bootstrap-infrastructure.yaml
```

### 4. Verify Deployment
```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check critical services
kubectl get pods -n cert-manager
kubectl get pods -n monitoring
```

## 🔐 SealedSecrets Management

**⚠️ CRITICAL:** After every `tofu destroy && tofu apply`, you MUST restore SealedSecrets keys:

```bash
# Automatic restoration
./post-deploy-restore.sh

# Why: Cluster recreation generates new keys, breaking ALL existing SealedSecrets
# (certificates, storage, monitoring, backups)
```

**Detailed documentation:** [tofu/bootstrap/sealed-secrets/README.md](tofu/bootstrap/sealed-secrets/README.md)

> ⚠️ **This repository is a work in progress!**  
> 🏗️ Expect breaking changes, experiments, and lots of learning along the way.  
> Contributions and feedback are welcome!
