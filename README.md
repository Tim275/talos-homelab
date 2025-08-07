# 🚧 Talos Kubernetes Cluster Playground 🛠️

A fully automated, enterprise-grade Kubernetes cluster project for homelab and testing, powered by [Talos Linux](https://www.talos.dev/) 🐧, [OpenTofu](https://opentofu.org/) 🌱, [ArgoCD](https://argo-cd.readthedocs.io/) 🚀, and [Proxmox VE](https://www.proxmox.com/) 🖥️.

Features **Enterprise Matrix Generator Pattern** used by Netflix, Google, and AWS for automatic application discovery and multi-cluster deployments! 🌟

---

## 📦 Tech Stack

- 🐧 **Talos Linux** – Secure, immutable OS for Kubernetes
- ☸️ **Kubernetes** – Container orchestration platform  
- 🌱 **OpenTofu** – Infrastructure as Code provisioning
- 🖥️ **Proxmox VE** – Virtualization platform
- 🦑 **Cilium** – Advanced networking & security with eBPF
- 🚀 **ArgoCD** – GitOps continuous delivery engine
- 📊 **Matrix Generator** – Enterprise auto-discovery pattern

---

## 🏗️ Architecture

This homelab implements **enterprise-grade patterns** used by major tech companies:

### **GitOps with Matrix Generator**
- **Auto-Discovery**: New apps are automatically discovered by folder structure
- **Multi-Cluster Ready**: Single configuration deploys to multiple clusters  
- **Zero Maintenance**: No manual app registry updates needed
- **Team Self-Service**: Developers create folders, apps appear automatically

### **Infrastructure Layers**
```
┌─────────────────────────────────────────────┐
│                ArgoCD GitOps                │  ← Layer 4: Automation
├─────────────────────────────────────────────┤
│  Apps: Prometheus │ Grafana │ cert-manager │  ← Layer 3: Applications  
├─────────────────────────────────────────────┤
│     Storage: Proxmox-CSI │ Sealed-Secrets  │  ← Layer 2: Platform Services
├─────────────────────────────────────────────┤
│         Network: Cilium │ Gateway API      │  ← Layer 1: Foundation
└─────────────────────────────────────────────┘
```

---

## 🚀 Quick Deployment

### **Prerequisites**
- Talos cluster running (6 nodes: 3 control-plane, 3 workers)
- `kubectl` and `kustomize` installed
- `KUBECONFIG` pointing to your cluster

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

---

## 📁 Repository Structure

### **Enterprise Matrix Generator Pattern**
```
kubernetes/
├── infra-v2/                    # 🎯 Auto-discovered by Matrix Generator
│   ├── controllers/
│   │   ├── argocd/              # ✅ GitOps engine
│   │   ├── cert-manager/        # ✅ SSL certificates  
│   │   └── sealed-secrets/      # ✅ Encrypted secrets
│   ├── monitoring/
│   │   ├── prometheus/          # ✅ Metrics collection
│   │   ├── grafana/             # ✅ Dashboards
│   │   └── loki/                # ✅ Log aggregation
│   ├── network/
│   │   ├── cilium/              # ✅ CNI + LoadBalancer
│   │   ├── gateway/             # ✅ Gateway API + TLS
│   │   └── cloudflared/         # ✅ Cloudflare tunnel
│   └── storage/
│       └── proxmox-csi/         # ✅ Proxmox storage
├── sets/
│   └── infrastructure.yaml     # 🤖 Matrix Generator ApplicationSet
└── infra/                      # 📦 Legacy bootstrap structure
```

### **How Matrix Generator Works**
1. **Scans**: `kubernetes/infra-v2/*/*` for any folder containing `kustomization.yaml`
2. **Creates**: ArgoCD Application for each discovered path automatically
3. **Deploys**: Applications across all registered clusters
4. **Scales**: From 10 to 10,000+ applications without configuration changes

---

## 🎯 Infrastructure Components

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
        <th>Purpose</th>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/cilium/cilium/Documentation/images/logo-solo.svg"></td>
        <td><a href="https://cilium.io/">Cilium</a></td>
        <td>eBPF-based networking, observability and security</td>
        <td>CNI, LoadBalancer, Gateway API, Network Policies</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/argoproj/argo-cd/master/docs/assets/argo.png"></td>
        <td><a href="https://argo-cd.readthedocs.io/">ArgoCD</a></td>
        <td>Declarative GitOps continuous delivery</td>
        <td>GitOps engine with Matrix Generator pattern</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"></td>
        <td><a href="https://prometheus.io/">Prometheus</a></td>
        <td>Monitoring system and time series database</td>
        <td>Metrics collection, alerting, service discovery</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/grafana@main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana.com/">Grafana</a></td>
        <td>Analytics and monitoring platform</td>
        <td>Dashboards, visualization, multi-datasource queries</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/grafana/loki@main/docs/sources/logo_and_name.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system for cloud-native apps</td>
        <td>Centralized logging, log correlation with metrics</td>
    </tr>
    <tr>
        <td>🔒</td>
        <td><a href="https://sealed-secrets.netlify.app/">Sealed Secrets</a></td>
        <td>Kubernetes controller for one-way encrypted secrets</td>
        <td>GitOps-safe secret management, public key encryption</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.yuribacciarini.com/content/images/2023/07/image-4.png"></td>
        <td><a href="https://github.com/kubernetes-csi/csi-driver-nfs">Proxmox CSI</a></td>
        <td>Container Storage Interface for Proxmox VE</td>
        <td>Dynamic PV provisioning, ZFS backend integration</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/main/site-src/images/logo/logo.svg"></td>
        <td><a href="https://gateway-api.sigs.k8s.io/">Gateway API</a></td>
        <td>Next-generation ingress API for Kubernetes</td>
        <td>Traffic routing, TLS termination, vendor-neutral</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cert-manager/cert-manager/master/logo/logo.svg"></td>
        <td><a href="https://cert-manager.io/">cert-manager</a></td>
        <td>Automatic SSL certificate management</td>
        <td>Let's Encrypt integration, automatic renewal</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.vectorlogo.zone/logos/cloudflare/cloudflare-icon.svg"></td>
        <td><a href="https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/">Cloudflare Tunnel</a></td>
        <td>Zero-Trust secure tunnel for external access</td>
        <td>No port forwarding, DDoS protection, global CDN</td>
    </tr>
</table>

---

## 🎯 Enterprise Features

### **Matrix Generator Benefits**
- ✅ **Auto-Discovery**: New applications appear automatically  
- ✅ **Zero Maintenance**: No manual configuration updates
- ✅ **Multi-Cluster**: Deploy to 1 or 1000+ clusters with same config
- ✅ **Team Self-Service**: Developers create folders, ops team manages clusters
- ✅ **Netflix/Google Pattern**: Industry-standard enterprise approach

### **Adding New Applications**
```bash
# 1. Create application directory
mkdir -p kubernetes/infra-v2/my-category/my-new-app

# 2. Add kustomization.yaml
cat > kubernetes/infra-v2/my-category/my-new-app/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF

# 3. Git push
git add . && git commit -m "feat: Add my-new-app" && git push

# 4. ✨ Magic! App appears in ArgoCD automatically!
```

### **Multi-Cluster Deployment**
Register additional clusters in ArgoCD, and Matrix Generator automatically deploys all infrastructure to every cluster! 🌍

---

## 🔧 Development

### **Prerequisites for Infrastructure Development**
- Proxmox VE cluster
- OpenTofu/Terraform installed
- kubectl, kustomize, helm, jq installed
- ArgoCD CLI (optional)

### **Infrastructure Deployment from Scratch**
```bash
# 1. Deploy Talos cluster with OpenTofu
cd tofu/
tofu init && tofu apply

# 2. Bootstrap in dependency order (see Quick Deployment above)

# 3. Enjoy your enterprise-grade homelab! 🎉
```

---

## 🤝 Contributing

This is a learning playground, but contributions and feedback are welcome!

- 🐛 **Bug Reports**: Open an issue with reproduction steps
- 💡 **Feature Requests**: Describe your use case and proposed solution  
- 🔄 **Pull Requests**: Follow the Matrix Generator pattern for new apps
- 📚 **Documentation**: Help improve setup guides and explanations

---

## ⚠️ Disclaimer

> **This repository is a work in progress!**  
> 🏗️ Expect breaking changes, experiments, and lots of learning along the way.  
> Perfect for homelab experimentation, not recommended for production without thorough testing.

---

**Built with ❤️ for learning Kubernetes, GitOps, and enterprise patterns**

🎯 **Enterprise-ready** • 🚀 **Auto-scaling** • 🔒 **Security-first** • 🌟 **Production-patterns**