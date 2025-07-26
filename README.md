# 🚧 Talos Kubernetes Cluster Playground 🛠️

A fully automated, modular Kubernetes cluster project for homelab and testing, powered by [Talos Linux](https://www.talos.dev/) 🐧, [OpenTofu](https://opentofu.org/) 🌱, and [Proxmox VE](https://www.proxmox.com/) 🖥️.

---

## 📦 Tech Stack

- 🐧 **Talos Linux** – Secure, immutable OS for Kubernetes
- ☸️ **Kubernetes** – Container orchestration
- 🌱 **OpenTofu** – Infrastructure as Code
- 🖥️ **Proxmox VE** – Virtualization platform
- 🦑 **Cilium** – Advanced networking & security

---

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
        <td><a href="https://argo-cd.readthedocs.io/">ArgoCD</a></td>
        <td>Declarative GitOps continuous delivery for Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/web/ui/static/img/prometheus_logo.svg"></td>
        <td><a href="https://prometheus.io/">Prometheus</a></td>
        <td>Monitoring system and time series database for metrics collection</td>
    </tr>
    <tr>
        <td><img width="32" src="https://grafana.com/media/logos/grafana-icon.svg"></td>
        <td><a href="https://grafana.com/">Grafana</a></td>
        <td>Analytics and monitoring platform with rich visualization dashboards</td>
    </tr>
    <tr>
        <td><img width="32" src="https://grafana.com/media/docs/loki/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system designed for cloud-native applications</td>
    </tr>
    <tr>
        <td><img width="32" src="https://bitnami.com/assets/stacks/sealed-secrets/img/sealed-secrets-stack-220x234.png"></td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Kubernetes controller for one-way encrypted secrets</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">cert-manager</a></td>
        <td>Kubernetes certificate management controller</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/13629408?s=200&v=4"></td>
        <td><a href="https://github.com/kubernetes-csi/csi-driver-nfs">Proxmox CSI</a></td>
        <td>Container Storage Interface for Proxmox VE with ZFS backend</td>
    </tr>
</table>

---

> ⚠️ **This repository is a work in progress!**  
> 🏗️ Expect breaking changes, experiments, and lots of learning along the way.  
> Contributions and feedback are welcome!