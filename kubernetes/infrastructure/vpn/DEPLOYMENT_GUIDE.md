# VPN Infrastructure Deployment Guide

## 🎯 Enterprise Sync Wave Strategy

VPN infrastructure follows a **4-level sync wave hierarchy** for guaranteed dependency resolution.

### **Complete Sync Wave Hierarchy:**

```
📊 LEVEL 1: INFRASTRUCTURE BOOTSTRAP (Wave 0-5)
├── Wave 0: Namespaces (namespaces-app.yaml)
├── Wave 1: Network (network-app.yaml)
│   └── Cilium, Istio, MetalLB, Cloudflared
├── Wave 2: Controllers (controllers-app.yaml)
│   └── ArgoCD, Cert-Manager, Sealed Secrets
├── Wave 3: Storage (storage-app.yaml)
│   └── Rook-Ceph, Velero, CloudNativePG
├── Wave 4: VPN (vpn-app.yaml) ← VPN PARENT APP
│   ├── Coturn (wave 0-2 within VPN)
│   └── Netbird (wave 1 within VPN)
└── Wave 5: Monitoring (monitoring-app.yaml)
    └── Prometheus, Grafana, AlertManager

📊 LEVEL 2: VPN DOMAIN (vpn-app.yaml - Wave 4)
└── Points to: kubernetes/infrastructure/vpn/

📊 LEVEL 3: VPN SERVICES (vpn/kustomization.yaml)
├── Coturn Application (sync-wave: 0)
│   └── STUN/TURN foundation (no dependencies within VPN)
└── Netbird Application (sync-wave: 1)
    └── Depends on Coturn for NAT traversal

📊 LEVEL 4: COTURN COMPONENTS (coturn/kustomization.yaml)
├── Wave 0: Namespace + ConfigMaps
├── Wave 1: Certificate (cert-manager needs time to issue)
└── Wave 2: Deployment + Service (waits for TLS)
```

### **Why Wave 4 for VPN?**

**Dependencies Resolved:**
```
✅ Wave 1 (Network): Cilium CNI + MetalLB LoadBalancer
✅ Wave 2 (Controllers): Cert-Manager for TLS certificates
✅ Wave 3 (Storage): Rook-Ceph for Netbird PostgreSQL PVC
🎯 Wave 4 (VPN): All dependencies ready → Deploy VPN
✅ Wave 5 (Monitoring): Prometheus can scrape VPN metrics
```

---

## 🚀 Deployment Instructions

### **Option 1: Enable Entire VPN Domain (Recommended)**

Uncomment VPN in infrastructure bootstrap:

```bash
# File: kubernetes/infrastructure/kustomization.yaml
resources:
  - controllers-app.yaml
  - network-app.yaml
  - storage-app.yaml
  - vpn-app.yaml                    # ← UNCOMMENT THIS LINE
  - monitoring-app.yaml
```

**Result:**
- ArgoCD deploys VPN parent app (wave 4)
- Discovers child apps: coturn, netbird
- Deploys in order: Coturn (wave 0) → Netbird (wave 1)

---

### **Option 2: Gradual Rollout (Conservative)**

**Step 1** - Enable VPN domain (empty, no services):
```bash
# infrastructure/kustomization.yaml
- vpn-app.yaml  # Uncomment

# infrastructure/vpn/kustomization.yaml
resources:
  # - coturn/application.yaml   # Keep commented
  # - netbird/application.yaml  # Keep commented
```

**Step 2** - Enable Coturn only:
```bash
# infrastructure/vpn/kustomization.yaml
resources:
  - coturn/application.yaml   # Uncomment
  # - netbird/application.yaml  # Keep commented
```

**Step 3** - Enable Netbird (after Coturn is healthy):
```bash
# infrastructure/vpn/kustomization.yaml
resources:
  - coturn/application.yaml
  - netbird/application.yaml  # Uncomment
```

---

## 📋 Pre-Deployment Checklist

Before enabling VPN, verify dependencies:

### **1. Network Layer (Wave 1)**
```bash
# Check CNI is ready
kubectl get pods -n kube-system -l k8s-app=cilium
# Expected: All Running

# Check MetalLB is ready
kubectl get ipaddresspools -n metallb-system
# Expected: IP pool includes 192.168.178.100
```

### **2. Controllers Layer (Wave 2)**
```bash
# Check cert-manager is ready
kubectl get pods -n cert-manager
# Expected: All Running

# Check ClusterIssuer exists
kubectl get clusterissuer letsencrypt-prod
# Expected: Ready = True
```

### **3. Storage Layer (Wave 3)**
```bash
# Check Rook-Ceph is healthy
kubectl get cephcluster -n rook-ceph
# Expected: HEALTH = HEALTH_OK

# Check StorageClass available
kubectl get storageclass rook-ceph-block
# Expected: Exists
```

### **4. DNS Configuration**
```bash
# Verify DNS record points to LoadBalancer IP
dig coturn.timourhomelab.org +short
# Expected: 192.168.178.100 (or your router forwards 0.0.0.0:3478 → 192.168.178.100:3478)
```

---

## 🔍 Post-Deployment Verification

### **1. Check ArgoCD Sync Status**
```bash
# Check VPN parent app
kubectl get application -n argocd vpn
# Expected: HEALTH=Healthy, SYNC=Synced

# Check child apps
kubectl get application -n argocd coturn netbird
# Expected: Both Healthy + Synced
```

### **2. Verify Coturn Deployment**
```bash
# Check pods
kubectl get pods -n coturn
# Expected: 2/2 Running (HA replicas)

# Check LoadBalancer IP assigned
kubectl get svc -n coturn coturn
# Expected: EXTERNAL-IP = 192.168.178.100

# Check certificate
kubectl get certificate -n coturn coturn-tls
# Expected: READY = True

# Check TLS secret exists
kubectl get secret -n coturn coturn-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
# Expected: CN=coturn.timourhomelab.org
```

### **3. Test STUN Server**
```bash
# From external machine (not in cluster)
npm install -g stun
stun coturn.timourhomelab.org 3478

# Expected output:
# {
#   "address": "YOUR_PUBLIC_IP",
#   "family": "IPv4"
# }
```

### **4. Check Prometheus Metrics**
```bash
# Verify metrics endpoint
kubectl port-forward -n coturn svc/coturn-metrics 9641:9641
curl http://localhost:9641/metrics | grep coturn_

# Expected: Coturn metrics exported
```

---

## 🎛️ Sync Wave Control Examples

### **Normal Operation (Level 3 - Service Control)**
```bash
# Disable Coturn temporarily
# File: infrastructure/vpn/kustomization.yaml
resources:
  # - coturn/application.yaml   # Comment out
  - netbird/application.yaml

# ArgoCD will prune Coturn resources automatically
```

### **Fine-Grained Control (Level 4 - Component Control)**
```bash
# Disable Coturn certificate renewal temporarily
# File: infrastructure/vpn/coturn/kustomization.yaml
resources:
  - ns.yaml
  - deployment.yaml
  - service.yaml
  # - certificate.yaml  # Comment out (uses existing cert)
```

### **Extreme Scenarios (Level 1 - Domain Control)**
```bash
# Testing: Disable entire VPN domain
# File: infrastructure/kustomization.yaml
# - vpn-app.yaml  # Comment out

# Result: ALL VPN services disabled (Coturn + Netbird)
```

---

## 🔐 Security Notes

### **LoadBalancer Exposure**
- Coturn is **publicly exposed** on UDP/TCP 3478 (STUN) and TCP 5349 (TURN/TLS)
- Required for NAT traversal (clients behind firewalls need external access)
- Secured with TLS for TURN (port 5349)
- No authentication needed for STUN (by design)

### **TLS Certificate**
- Managed by cert-manager + Let's Encrypt
- Auto-renewal every 90 days
- Required for TURN over TLS (secure relay)

### **Network Policies (Future)**
- Currently: Open ingress for LoadBalancer
- Recommended: Implement rate limiting for STUN/TURN requests
- Consider: GeoIP filtering if VPN only needed in specific regions

---

## 📊 Monitoring & Alerts

### **Grafana Dashboard (TODO)**
- Coturn metrics: `coturn_allocation_total`, `coturn_traffic_bytes`
- Netbird metrics: Connected peers, ACL violations

### **Prometheus Alerts (TODO)**
```yaml
# Alert when Coturn down
- alert: CoturnDown
  expr: up{job="coturn"} == 0
  for: 5m
  annotations:
    summary: "Coturn STUN/TURN server is down"

# Alert when certificate expires soon
- alert: CoturnCertExpiringSoon
  expr: cert_exporter_cert_expires_in_seconds{cn="coturn.timourhomelab.org"} < 7*24*3600
  annotations:
    summary: "Coturn TLS certificate expires in < 7 days"
```

---

## 🛠️ Troubleshooting

### **Coturn pods stuck in ContainerCreating**
```bash
# Check if certificate is ready
kubectl describe pod -n coturn <pod-name> | grep -A5 Events
# Common issue: TLS secret not found (cert-manager still issuing)

# Wait for certificate
kubectl wait --for=condition=Ready certificate/coturn-tls -n coturn --timeout=300s
```

### **LoadBalancer stuck in Pending**
```bash
# Check MetalLB IP pool
kubectl describe ipaddresspool -n metallb-system
# Verify 192.168.178.100 is in range

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb
```

### **STUN test fails from external network**
```bash
# 1. Check router port forwarding (UDP 3478 → 192.168.178.100:3478)
# 2. Verify firewall allows UDP 3478
# 3. Check Coturn logs
kubectl logs -n coturn -l app=coturn | grep -i stun
```

---

## 📚 Architecture Documentation

See project documentation:
- **VPN_ARCHITECTURE.md** (gitignored) - Complete VPN architecture overview
- **COTURN.md** (gitignored) - Deep dive into Coturn STUN/TURN
- **NETBIRD.md** (gitignored) - Netbird mesh VPN components

**Note:** Markdown docs are gitignored (too large), but available locally for reference.

---

## 🎯 Summary: How to Enable VPN

**Quick Start (Single Command):**
```bash
# 1. Uncomment VPN in infrastructure kustomization
sed -i '' 's/# - vpn-app.yaml/- vpn-app.yaml/' kubernetes/infrastructure/kustomization.yaml

# 2. Uncomment Coturn in VPN kustomization
sed -i '' 's/# - coturn\/application.yaml/- coturn\/application.yaml/' kubernetes/infrastructure/vpn/kustomization.yaml

# 3. Commit and push
git add kubernetes/infrastructure/
git commit -m "feat: enable VPN infrastructure with Coturn STUN/TURN server"
git push

# 4. Watch ArgoCD sync
kubectl get applications -n argocd -w
```

**Expected Timeline:**
- Wave 4 parent app: ~5 seconds (discovers child apps)
- Wave 0 (Coturn namespace/config): ~10 seconds
- Wave 1 (Certificate): ~30-60 seconds (Let's Encrypt ACME challenge)
- Wave 2 (Deployment/Service): ~20 seconds (pods start + LoadBalancer IP)
- **Total: ~2 minutes** from commit to fully operational VPN

---

**Status:** VPN infrastructure ready for deployment with enterprise-grade sync wave orchestration! 🚀
