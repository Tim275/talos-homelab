# 🌐 Tailscale MagicDNS Setup - Step-by-Step Guide

**Purpose**: Configure Split-Horizon DNS for VPN-only access to Kubernetes services

---

## 📋 What You Will Do

You will configure **Tailscale MagicDNS** to resolve `grafana.timourhomelab.org` to your Envoy Gateway LoadBalancer IP (`192.168.68.152`) **ONLY when connected to Tailscale VPN**.

**Result**:
- ✅ **With VPN**: grafana.timourhomelab.org → 192.168.68.152 (works)
- ❌ **Without VPN**: grafana.timourhomelab.org → No resolution (fails)

---

## 🚀 Step-by-Step Instructions

### **Step 1: Open Tailscale Admin Panel**

1. Open your browser
2. Go to: **https://login.tailscale.com/admin/dns**
3. Log in with your Tailscale account

---

### **Step 2: Enable MagicDNS**

1. Look for the **"MagicDNS"** section at the top
2. If it shows **"Disabled"**, click **"Enable MagicDNS"**
3. If already **"Enabled"**, you're good - proceed to Step 3

**What this does**: Enables Tailscale's DNS server (100.100.100.100) for your VPN network

---

### **Step 3: Add Custom DNS Record**

1. Scroll down to the **"Nameservers"** section
2. Look for **"Custom records"** or **"Add DNS record"**
3. Click **"Add record"** or **"+"** button

4. Fill in the form:
   ```
   Type: A
   Name: grafana.timourhomelab.org
   Address: 192.168.68.152
   ```

5. Click **"Save"** or **"Add"**

---

### **Step 4: Verify DNS Record Added**

You should now see in the "Custom records" list:

```
grafana.timourhomelab.org → 192.168.68.152
```

---

## 🧪 Testing - Verify MagicDNS Works

### **Test 1: DNS Resolution (WITH VPN)**

```bash
# Connect to Tailscale VPN
tailscale up

# Test DNS resolution
nslookup grafana.timourhomelab.org

# Expected output:
# Server: 100.100.100.100
# Address: 100.100.100.100#53
#
# Name: grafana.timourhomelab.org
# Address: 192.168.68.152
```

✅ **Success**: DNS resolves to `192.168.68.152` via Tailscale DNS (100.100.100.100)

---

### **Test 2: DNS Resolution (WITHOUT VPN)**

```bash
# Disconnect from Tailscale VPN
tailscale down

# Test DNS resolution
nslookup grafana.timourhomelab.org

# Expected output:
# Server: 8.8.8.8 (or your ISP DNS)
# Address: <Cloudflare IP or NXDOMAIN>
```

❌ **Success**: DNS does NOT resolve to `192.168.68.152` (public DNS has no record)

---

### **Test 3: HTTP Access (WITH VPN)**

```bash
# Connect to Tailscale VPN
tailscale up

# Test Grafana access
curl -I https://grafana.timourhomelab.org

# Expected output:
# HTTP/2 200 OK
# (Grafana login page)
```

✅ **Success**: Grafana is accessible via VPN

---

### **Test 4: HTTP Access (WITHOUT VPN)**

```bash
# Disconnect from Tailscale VPN
tailscale down

# Test Grafana access
curl -I https://grafana.timourhomelab.org

# Expected output:
# curl: (6) Could not resolve host: grafana.timourhomelab.org
# OR
# curl: (7) Failed to connect: Connection timed out
```

❌ **Success**: Grafana is NOT accessible without VPN

---

## 🎯 Summary - What You Configured

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **MagicDNS** | Enabled | Tailscale becomes DNS server (100.100.100.100) |
| **DNS Record** | grafana.timourhomelab.org → 192.168.68.152 | Private DNS resolution (VPN only) |
| **Gateway IP** | 192.168.68.152 | Envoy Gateway LoadBalancer |
| **Split-Horizon** | Public DNS has no record | Service not resolvable without VPN |

---

## 🏗️ Architecture - How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      WITHOUT TAILSCALE VPN                       │
│                                                                  │
│  User → Public DNS (8.8.8.8) → No record for grafana.          │
│         timourhomelab.org → DNS FAIL ❌                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       WITH TAILSCALE VPN                         │
│                                                                  │
│  User → Tailscale DNS (100.100.100.100)                         │
│       → MagicDNS resolves grafana.timourhomelab.org             │
│       → Returns 192.168.68.152 (Gateway LoadBalancer)           │
│       → Envoy Gateway routes to Grafana Pod                     │
│       → SUCCESS ✅                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Benefits

**What You Achieved**:

1. ✅ **Network Isolation**: Grafana not accessible from public internet
2. ✅ **Device Authentication**: Only Tailscale-authorized devices can access
3. ✅ **Split-Horizon DNS**: Same domain, different resolution based on context
4. ✅ **Zero Port Forwarding**: No firewall rules, no open ports
5. ✅ **Enterprise Pattern**: Same as Google BeyondCorp, Netflix internal tools

**Defense Layers**:
- 🔒 **Layer 1**: Tailscale VPN (WireGuard encryption + device auth)
- 🔒 **Layer 2**: Authelia OIDC + 2FA (coming in Phase 2)

---

## 🛠️ Troubleshooting

### Issue 1: DNS Resolves to Wrong IP

**Problem**: `nslookup grafana.timourhomelab.org` returns Cloudflare IP, not 192.168.68.152

**Cause**: MagicDNS not enabled, or VPN not connected

**Fix**:
```bash
# Verify VPN connected
tailscale status

# If not connected:
tailscale up

# Verify MagicDNS enabled
tailscale status | grep -i dns

# Expected: "DNS: 100.100.100.100"
```

---

### Issue 2: DNS Resolves But Connection Fails

**Problem**: `nslookup` works (returns 192.168.68.152) but `curl` times out

**Cause**: Gateway LoadBalancer not routing traffic, or HTTPRoute missing

**Fix**:
```bash
# Check Gateway status
kubectl get gateway envoy-gateway -n gateway

# Expected: ADDRESS=192.168.68.152, PROGRAMMED=True

# Check if LoadBalancer service exists
kubectl get svc -n envoy-gateway-system envoy-gateway-envoy-gateway-ee418b6e

# Expected: EXTERNAL-IP=192.168.68.152, PORTS=443:xxx/TCP,80:xxx/TCP
```

---

### Issue 3: Certificate Error (HTTPS)

**Problem**: `curl` returns SSL certificate error

**Cause**: Let's Encrypt certificate not trusted, or self-signed cert

**Fix**:
```bash
# Check certificate
curl -vvv https://grafana.timourhomelab.org 2>&1 | grep -i certificate

# If self-signed, use -k to skip verification (testing only):
curl -k https://grafana.timourhomelab.org

# For production: Ensure Let's Encrypt cert is issued
kubectl get certificate -n gateway timourhomelab-wildcard-tls
```

---

## 📚 Next Steps

After MagicDNS is configured and tested:

1. ✅ **Phase 1 Complete**: VPN-only access working
2. 🔒 **Phase 2 Ready**: Enable Authelia SecurityPolicy for Zero Trust
3. 🚀 **Phase 2 Activation**: Uncomment SecurityPolicy in gateway/kustomization.yaml
4. 🧪 **Phase 2 Testing**: Login required at https://auth.timourhomelab.org

---

## 🏆 Status

- ✅ **Tailscale VPN**: Running (Pod in tailscale namespace)
- ✅ **Gateway LoadBalancer**: 192.168.68.152 active
- ⏳ **MagicDNS**: Waiting for your configuration
- ⏸️ **Authelia SecurityPolicy**: Ready to enable (Phase 2)

**Current Task**: Configure MagicDNS + Test access → Report back results! 🚀
