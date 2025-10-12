# 🔒 VPN-Only Services Access Guide

**Enterprise Split-Routing Pattern** - Internal services via Tailscale VPN

---

## 🎯 **Architecture:**

```
┌─────────────────────────────────────────────┐
│ VPN-ONLY SERVICES (Internal) 🔒            │
├─────────────────────────────────────────────┤
│ ✅ Hubble UI (Network observability)       │
│ ⏳ Grafana (Monitoring dashboards)         │
│ ⏳ ArgoCD (GitOps management)              │
│ ⏳ CloudBeaver (PostgreSQL Admin)          │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ PUBLIC SERVICES (Cloudflare Tunnel) 🌐     │
├─────────────────────────────────────────────┤
│ ✅ N8N (Webhooks, external integrations)   │
│ ✅ Authelia (OIDC authentication)          │
└─────────────────────────────────────────────┘
```

---

## 🔐 **VPN-Only Services Access:**

### **1️⃣ Hubble UI - Network Observability**

**Status:** ✅ VPN-only configured (HTTPRoute deleted)

**Access via Tailscale VPN:**
```bash
# Get current Pod IP:
kubectl get pods -n kube-system -l k8s-app=hubble-ui -o wide

# Current Pod IP: 10.244.5.61
# Access: http://10.244.5.61:80
```

**Browser Access (with Tailscale connected):**
```
http://10.244.5.61
```

**Features:**
- Real-time network flow visualization
- Service-to-service communication map
- DNS query monitoring
- HTTP/gRPC request tracing
- Network policy enforcement visibility

**Security:**
- ✅ **NO public HTTPRoute** - Not accessible via Internet
- ✅ **Direct Pod IP** - Only reachable via Tailscale VPN (10.244.0.0/16)
- ✅ **No TLS needed** - Internal cluster traffic
- ⚠️ **Pod IP changes on restart** - Use `kubectl get pods` to get new IP

---

### **2️⃣ Grafana - Monitoring Dashboards**

**Status:** ⏳ TODO - Currently public via Cloudflare Tunnel

**Plan:**
1. Disable HTTPRoutes in `kubernetes/infrastructure/monitoring/grafana/kustomization.yaml`
2. Access via Pod IP: `kubectl get pods -n grafana -l app.kubernetes.io/name=grafana -o wide`
3. Browser: `http://<pod-ip>:3000`

---

### **3️⃣ ArgoCD - GitOps Management**

**Status:** ⏳ TODO - Currently public via Cloudflare Tunnel

**Plan:**
1. Remove `argo.timourhomelab.org` from Cloudflare Tunnel config
2. Access via Pod IP: `kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide`
3. Browser: `http://<pod-ip>:8080`

---

## 🚀 **How to Connect via Tailscale VPN:**

### **On macOS/Linux:**
```bash
# Start Tailscale
sudo tailscale up

# Accept subnet routes (enable access to Kubernetes Pod CIDR)
sudo tailscale set --accept-routes=true

# Verify connectivity
tailscale status

# Check routing table (should see 10.244.0.0/16 route)
netstat -rn | grep "10.244"
```

### **On Windows:**
```powershell
# Start Tailscale
tailscale up

# Accept subnet routes
tailscale set --accept-routes=true

# Verify connectivity
tailscale status
```

### **Verify VPN Access:**
```bash
# Ping Tailscale connector Pod
ping 100.69.215.3

# Test Hubble UI access
curl http://10.244.5.61

# Expected: HTML response from Hubble UI
```

---

## 🛡️ **Security Benefits:**

### **vs Public Access:**
- ✅ **Zero public attack surface** - Services not reachable from Internet
- ✅ **Identity-based access** - Tailscale ACL controls WHO can access
- ✅ **Audit logging** - Tailscale logs all VPN connections
- ✅ **Easy revocation** - Remove device from Tailscale = instant access loss
- ✅ **No credential exposure** - No need for public authentication layers

### **Defense in Depth Layers:**
```
🔐 Layer 1: Tailscale VPN (WireGuard encryption)
  → Only authenticated devices can reach cluster

🔐 Layer 2: Kubernetes NetworkPolicy (optional)
  → Pod-level traffic control (CIDR-based)

🔐 Layer 3: Application Auth (Grafana/ArgoCD login)
  → User-level authentication

🔐 Layer 4: Kubernetes RBAC (kubectl)
  → API-level authorization
```

---

## 📊 **Monitoring VPN Access:**

### **Check which services are VPN-only:**
```bash
# List all HTTPRoutes (services with public access)
kubectl get httproute -A

# Services NOT listed = VPN-only ✅
```

### **Hubble Flow Logs (monitor VPN traffic):**
```bash
# Install Hubble CLI
brew install cilium-cli

# Watch Hubble UI traffic
hubble observe --namespace kube-system --pod hubble-ui --verdict FORWARDED

# Check source IPs (should see Tailscale CIDR: 100.64.0.0/10)
hubble observe --namespace kube-system --from-identity 100.64.0.0/10
```

---

## 🔧 **Troubleshooting:**

### **Problem: "Can't reach Pod IP"**
**Solution:**
```bash
# Check Tailscale status
tailscale status

# Verify subnet routes are advertised
tailscale status | grep "10.244\|10.96"

# Re-enable route acceptance
sudo tailscale set --accept-routes=true

# Restart Tailscale daemon (macOS)
sudo launchctl stop com.tailscale.tailscaled
sudo launchctl start com.tailscale.tailscaled
```

### **Problem: "Pod IP changed after restart"**
**Solution:**
```bash
# Get new Pod IP
kubectl get pods -n kube-system -l k8s-app=hubble-ui -o wide

# Update bookmark/script with new IP
```

### **Problem: "Service still accessible from Internet"**
**Check:**
```bash
# Verify HTTPRoute is deleted
kubectl get httproute -A | grep hubble

# Should return empty (no public route)
```

---

## 🎯 **Next Steps:**

### **Phase 1: Core VPN-only Services** ✅
- [x] Hubble UI → VPN-only (Pod IP: 10.244.5.61)
- [ ] Grafana → VPN-only
- [ ] ArgoCD → VPN-only

### **Phase 2: Enterprise NetworkPolicies** (Optional)
- [ ] Create `CiliumNetworkPolicy` for each VPN-only service
- [ ] Restrict ingress to Tailscale CIDR: `100.64.0.0/10`
- [ ] Allow internal cluster traffic (Prometheus scraping, etc.)

### **Phase 3: MagicDNS (Advanced)** (Optional)
- [ ] Configure Tailscale MagicDNS for internal DNS
- [ ] Create DNS records: `hubble.internal → 10.244.5.61`
- [ ] Access via friendly hostname instead of Pod IP

---

## 📚 **References:**

- **Tailscale VPN Setup:** `kubernetes/infrastructure/vpn/TAILSCALE_SETUP.md`
- **Split-Routing Architecture:** `kubernetes/infrastructure/vpn/SPLIT_ROUTING.md`
- **Tailscale Subnet Routing:** https://tailscale.com/kb/1019/subnets
- **Cilium NetworkPolicy:** https://docs.cilium.io/en/stable/security/policy/

---

**Created:** 2025-10-12
**Author:** Tim275 + Claude
**Version:** 1.0.0 (Enterprise VPN-only Pattern)
