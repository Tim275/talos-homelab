# 🌐 Split-Routing Setup: VPN + Cloudflare Tunnel
**Enterprise Pattern für selektiven Service-Zugriff** 🔒

---

## 🎯 **Ziel:**
- ✅ **Grafana**: Nur via Tailscale VPN erreichbar (intern)
- ✅ **N8N**: Via Cloudflare Tunnel erreichbar (öffentlich)
- ✅ **HTTPRoute-basiert**: Kubernetes Gateway API nutzen
- ✅ **Kein Port-Forwarding**: Clean enterprise routing

---

## 📊 **Architektur:**

```
┌─────────────────────────────────────────────────┐
│           EXTERNAL CLIENTS                      │
├─────────────────────────────────────────────────┤
│                                                 │
│  MacBook (Tailscale)                           │
│  100.87.208.54 ──────┐                         │
│                       │                         │
│  Internet Users       │                         │
│  (Public) ────────────┼────────────────┐        │
│                       │                │        │
└───────────────────────┼────────────────┼────────┘
                        │                │
                        │                │
            ┌───────────▼────┐  ┌────────▼─────────┐
            │  TAILSCALE VPN │  │ CLOUDFLARE TUNNEL│
            │  (Private)     │  │  (Public)        │
            └───────────┬────┘  └────────┬─────────┘
                        │                │
            ┌───────────▼─────────────────▼──────────┐
            │      KUBERNETES CLUSTER                │
            ├────────────────────────────────────────┤
            │                                        │
            │  ┌──────────────┐  ┌──────────────┐  │
            │  │   GRAFANA    │  │     N8N      │  │
            │  │ (VPN only)   │  │  (Public)    │  │
            │  │ grafana.     │  │  n8n.        │  │
            │  │ timourhomelab│  │  timourhomelab│ │
            │  │ .org         │  │  .org        │  │
            │  └──────────────┘  └──────────────┘  │
            │                                        │
            └────────────────────────────────────────┘
```

---

## 📋 **Schritt 1: Grafana HTTPRoute für VPN-Only**

### 1.1 Grafana HTTPRoute überprüfen:
```bash
kubectl get httproute -n grafana
```

### 1.2 Grafana HTTPRoute editieren:

**Option A: ClusterIP ohne LoadBalancer/NodePort**
```yaml
# kubernetes/infrastructure/monitoring/grafana/httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: grafana
spec:
  parentRefs:
  - name: cilium-gateway
    namespace: gateway
  hostnames:
  - "grafana.timourhomelab.org"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: grafana-service
      port: 3000
```

**Option B: NetworkPolicy für VPN-only**
```yaml
# kubernetes/infrastructure/monitoring/grafana/network-policy-vpn-only.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: grafana-vpn-only
  namespace: grafana
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: grafana
  ingress:
  # Allow traffic from Tailscale Connector Pods
  - fromEndpoints:
    - matchLabels:
        tailscale.com/parent-resource-type: connector
  # Allow traffic from Tailscale Pod CIDR
  - fromCIDR:
    - 100.64.0.0/10  # Tailscale CGNAT range
  # Allow internal cluster traffic
  - fromEndpoints:
    - {}
```

### 1.3 Apply configuration:
```bash
kubectl apply -f kubernetes/infrastructure/monitoring/grafana/network-policy-vpn-only.yaml
```

**✅ Checkpoint:** Grafana nur via VPN erreichbar

---

## 📋 **Schritt 2: N8N HTTPRoute für Cloudflare Tunnel**

### 2.1 N8N HTTPRoute (bereits vorhanden):
```yaml
# kubernetes/apps/base/n8n/environments/production/httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: n8n-prod
  namespace: n8n-prod
spec:
  parentRefs:
  - name: cilium-gateway
    namespace: gateway
  hostnames:
  - "n8n.timourhomelab.org"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: n8n
      port: 5678
```

### 2.2 Cloudflare Tunnel Configuration:

In deinem Cloudflare Dashboard → Zero Trust → Tunnels:

**Tunnel Name**: `homelab-tunnel`

**Public Hostname**:
```
Domain: n8n.timourhomelab.org
Service: http://cilium-gateway.gateway.svc.cluster.local:80
Additional Headers:
  Host: n8n.timourhomelab.org
```

### 2.3 Cloudflared Deployment (falls noch nicht vorhanden):
```yaml
# kubernetes/infrastructure/network/cloudflared/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config.yaml
        - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
          readOnly: true
      volumes:
      - name: config
        secret:
          secretName: cloudflared-credentials
```

**✅ Checkpoint:** N8N via Cloudflare Tunnel erreichbar

---

## 📋 **Schritt 3: DNS Configuration**

### 3.1 Grafana DNS (internal):
In Tailscale Admin → DNS → MagicDNS:

**Option A: Kubernetes Internal DNS**
```
grafana.timourhomelab.org → CNAME → cilium-gateway.gateway.svc.cluster.local
```

**Option B: Pod IP via MagicDNS**
```bash
# Get Grafana Pod IP
kubectl get pods -n grafana -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.podIP}'

# Add to Tailscale MagicDNS:
grafana.timourhomelab.org → 10.244.x.x
```

### 3.2 N8N DNS (public):
In Cloudflare Dashboard → DNS → Records:

```
Type: CNAME
Name: n8n
Target: <cloudflare-tunnel-id>.cfargotunnel.com
Proxy: Enabled (Orange cloud)
```

**✅ Checkpoint:** DNS konfiguriert für beide Services

---

## 📋 **Schritt 4: Testing**

### 4.1 Test Grafana via VPN:
```bash
# On MacBook with Tailscale connected
curl -v http://10.244.x.x:3000  # Direct Pod IP

# Or via hostname (if MagicDNS configured)
curl -v https://grafana.timourhomelab.org
```

**Expected**: ✅ HTTP 200 - Grafana UI

### 4.2 Test Grafana ohne VPN:
```bash
# Disconnect Tailscale
sudo tailscale down

# Try to access
curl -v https://grafana.timourhomelab.org
```

**Expected**: ❌ Timeout or Connection Refused

### 4.3 Test N8N via Public Internet:
```bash
# Without VPN
curl -v https://n8n.timourhomelab.org
```

**Expected**: ✅ HTTP 200 - N8N UI

**✅ Checkpoint:** Split-routing funktioniert!

---

## 🔒 **Security Best Practices**

### 1. Grafana VPN-Only enforcement:
```yaml
# Add NetworkPolicy für strikte Isolation
kind: CiliumNetworkPolicy
metadata:
  name: grafana-deny-all-except-vpn
  namespace: grafana
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: grafana
  ingress:
  # ONLY allow Tailscale + internal cluster
  - fromCIDR:
    - 100.64.0.0/10  # Tailscale
    - 10.244.0.0/16  # Kubernetes Pods
  egress:
  # Allow all egress (for datasources, etc.)
  - {}
```

### 2. N8N via Cloudflare WAF:
In Cloudflare Dashboard → Security → WAF:

**Rule**: "Block high-risk countries"
```
Expression: (cf.threat_score > 10)
Action: Block
```

### 3. Tailscale ACL für Grafana:
Update Tailscale ACL:
```json
"acls": [
  {
    "action": "accept",
    "src": ["autogroup:admin"],
    "dst": ["tag:k8s:3000"]  // Grafana port
  }
]
```

---

## 🎯 **Advanced: Gateway-Level Split**

### Option: Multiple Gateways

**VPN Gateway** (internal):
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: vpn-gateway
  namespace: gateway
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 8080
    allowedRoutes:
      namespaces:
        from: All
```

**Public Gateway** (for Cloudflare):
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: public-gateway
  namespace: gateway
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
```

**Grafana HTTPRoute** → `vpn-gateway`
**N8N HTTPRoute** → `public-gateway`

---

## 📊 **Monitoring**

### Check Traffic Sources:
```bash
# Hubble Flow logs
hubble observe --namespace grafana --verdict FORWARDED
hubble observe --namespace n8n-prod --verdict FORWARDED

# Check source IPs
kubectl logs -n grafana -l app.kubernetes.io/name=grafana | grep "source_ip"
```

---

## 🎉 **Erfolg!**

### ✅ **Was du jetzt hast:**
- ✅ **Grafana**: Sicher via VPN, nicht öffentlich
- ✅ **N8N**: Öffentlich via Cloudflare Tunnel
- ✅ **Network Policies**: Strikte Isolation
- ✅ **Enterprise Pattern**: Gateway API + NetworkPolicy

---

## 📚 **Referenzen**

- **Tailscale Split DNS**: https://tailscale.com/kb/1054/dns/
- **Cilium NetworkPolicy**: https://docs.cilium.io/en/stable/security/policy/
- **Kubernetes Gateway API**: https://gateway-api.sigs.k8s.io/
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

---

**Erstellt**: 2025-10-12
**Autor**: Tim275 + Claude
**Version**: 1.0.0
