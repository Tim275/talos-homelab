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

## 🚀 Deployment Commands

### **Bootstrap Order (Dependencies Matter!)**

```bash
# 1. 🌐 NETWORK FOUNDATION
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -
# ↳ CNI + LoadBalancer + Gateway API CRDs

# 2. 🔐 SECURITY FOUNDATION  
kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -
# ↳ SealedSecret CRDs for encrypted secrets

# 3. 💾 STORAGE FOUNDATION
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A
# ↳ Storage classes and persistent volume support

# 4. 🚀 GITOPS ENGINE
kustomize build --enable-helm kubernetes/infra/controllers/argocd | kubectl apply -f -
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
# ↳ ArgoCD GitOps platform

# 5. ⚡ TRIGGER CHAIN REACTION (Matrix Generator Magic!)
kubectl apply -k kubernetes/infra  # Deploy remaining infrastructure
kubectl apply -k kubernetes/sets   # Deploy ApplicationSets → Auto-discovers ALL apps!
```

### **Access ArgoCD UI**
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
# 🌐 URL: http://localhost:8080
# 👤 Username: admin  
# 🔑 Password: [from command above]
```

### **Individual Components (if needed)**
```bash
# Cilium
kubectl kustomize --enable-helm kubernetes/infra/network/cilium | kubectl apply -f -

# Sealed-secrets
kustomize build --enable-helm kubernetes/infra/controllers/sealed-secrets | kubectl apply -f -

# Proxmox CSI Plugin
kustomize build --enable-helm kubernetes/infra/storage/proxmox-csi | kubectl apply -f -
kubectl get csistoragecapacities -ocustom-columns=CLASS:.storageClassName,AVAIL:.capacity,ZONE:.nodeTopology.matchLabels -A
```

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
        <td>🔒</td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Kubernetes controller for one-way encrypted secrets</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.yuribacciarini.com/content/images/2023/07/image-4.png"></td>
        <td><a href="https://github.com/kubernetes-csi/csi-driver-nfs">Proxmox CSI</a></td>
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
</table>

---

## 🎯 Enterprise Matrix Generator

This homelab implements the **Enterprise Matrix Generator Pattern** used by Netflix, Google, and AWS:

### **How it works:**
- **Auto-Discovery**: Apps in `kubernetes/infra-v2/*/*` are automatically found
- **Zero Maintenance**: No manual app registry updates needed  
- **Multi-Cluster Ready**: Deploy to 1000+ clusters with same config
- **Team Self-Service**: Create folder → App appears in ArgoCD

### **Adding New Apps:**
```bash
mkdir -p kubernetes/infra-v2/my-category/my-app
# Add kustomization.yaml
git push
# ✨ App appears automatically in ArgoCD!
```

---

> ⚠️ **This repository is a work in progress!**  
> 🏗️ Expect breaking changes, experiments, and lots of learning along the way.  
> Contributions and feedback are welcome!