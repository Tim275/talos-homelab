# 🚪 Gateway API v1.3.0 - Complete Guide

> **Production Gateway API with Envoy Gateway, cert-manager, Cloudflare Tunnel**
>
> *Following Vegard S. Hagen's Best Practices (Stonegarden Blog)*

## 📑 Table of Contents

1. [What is Gateway API?](#what-is-gateway-api)
2. [Prerequisites](#prerequisites)
3. [Role-Oriented Architecture](#role-oriented-architecture)
4. [Full Architecture Overview](#full-architecture-overview)
5. [Installation (60-90 Minutes)](#installation-60-90-minutes)
6. [How cert-manager Works (DNS-01)](#how-cert-manager-works-dns-01)
7. [Switching Gateway Implementations](#switching-gateway-implementations)
8. [HTTPRoute Examples](#httproute-examples)
9. [Troubleshooting](#troubleshooting)

---

## 🎯 What is Gateway API?

Gateway API is the **next-generation** Kubernetes routing API - the official successor to Ingress.

**Quote from Gateway API SIG:**
> "If you're familiar with the older Ingress API, you can think of the Gateway API as analogous to a more-expressive next-generation version of that API."

**Key Improvements:**
- ✅ **More Expressive** - Rich routing rules (headers, weights, traffic splitting)
- ✅ **Portable** - Switch implementations without changing HTTPRoutes
- ✅ **Role-Oriented** - Clear separation: Infrastructure vs App teams
- ✅ **Type-Safe** - No magic annotations, everything is validated

**Why v1.3.0?**
- Latest stable release (Jul 2024)
- Envoy Gateway v1.2.4 supports it
- Includes TLSRoute (experimental) support
- Graduate features from experimental to stable

**Our Stack:**
```
Gateway API v1.3.0
    ↓
Envoy Gateway v1.2.4 (implementation)
    ↓
cert-manager v1.16.0 (TLS certificates)
    ↓
Cloudflare Tunnel (Zero Trust ingress)
```

---

## 📋 Prerequisites

### 1. Kubernetes Cluster Requirements

```bash
✅ Kubernetes v1.29+ (we use v1.33.2)
✅ MetalLB or similar (for LoadBalancer Services)
✅ kubectl access
✅ Cloudflare account + domain (optional, for Tunnel)
```

---

### 2. Install Gateway API CRDs

**Why needed:** Kubernetes doesn't ship with Gateway API CRDs by default (unlike Ingress).

**Install Standard CRDs:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
```

**This installs:**
- `GatewayClass` - Defines which implementation to use
- `Gateway` - LoadBalancer + Listeners (like Ingress, but more powerful)
- `HTTPRoute` - HTTP routing rules
- `GRPCRoute` - gRPC routing rules
- `ReferenceGrant` - Cross-namespace permissions

**Install Experimental TLSRoute (optional):**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

**TLSRoute** allows TCP routing based on SNI (Server Name Indication) - useful for non-HTTP protocols.

**Verify Installation:**
```bash
kubectl get crd | grep gateway
# Should show:
# gatewayclasses.gateway.networking.k8s.io
# gateways.gateway.networking.k8s.io
# httproutes.gateway.networking.k8s.io
# grpcroutes.gateway.networking.k8s.io
# tlsroutes.gateway.networking.k8s.io
```

---

## 🏛️ Role-Oriented Architecture

Gateway API separates concerns between 3 roles:

```
┌─────────────────────────────────────────────────────────────────┐
│                  ROLE-ORIENTED DESIGN                            │
│                  (Vegard S. Hagen Style)                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  👷 INFRASTRUCTURE PROVIDER                                      │
│  (Platform Team / Cloud Provider)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Provides: GatewayClass                                         │
│                                                                  │
│  apiVersion: gateway.networking.k8s.io/v1                       │
│  kind: GatewayClass                                              │
│  metadata:                                                       │
│    name: envoy-gateway                                          │
│  spec:                                                           │
│    controllerName: gateway.envoyproxy.io/gatewayclass-controller│
│                                                                  │
│  ↓ This defines WHICH implementation to use                     │
│  ↓ Examples: Envoy, Cilium, Istio, NGINX, Traefik             │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ Infrastructure team provisions
┌─────────────────────────────────────────────────────────────────┐
│  🔧 CLUSTER OPERATOR                                            │
│  (DevOps / SRE Team)                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Manages: Gateway + Certificates                                │
│                                                                  │
│  apiVersion: gateway.networking.k8s.io/v1                       │
│  kind: Gateway                                                   │
│  metadata:                                                       │
│    name: envoy-gateway                                          │
│    namespace: gateway                                           │
│  spec:                                                           │
│    gatewayClassName: envoy-gateway  ← References GatewayClass  │
│    addresses:                                                    │
│    - type: IPAddress                                            │
│      value: 192.168.68.152                                      │
│    listeners:                                                    │
│    - name: https                                                │
│      protocol: HTTPS                                             │
│      port: 443                                                   │
│      tls:                                                        │
│        certificateRefs:                                          │
│        - name: wildcard-tls                                     │
│                                                                  │
│  ↓ This creates LoadBalancer Service                            │
│  ↓ Handles TLS termination                                      │
│  ↓ Exposes infrastructure to app teams                          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ App teams can attach to Gateway
┌─────────────────────────────────────────────────────────────────┐
│  👨‍💻 APPLICATION DEVELOPER                                        │
│  (Dev Team)                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Creates: HTTPRoute                                             │
│                                                                  │
│  apiVersion: gateway.networking.k8s.io/v1                       │
│  kind: HTTPRoute                                                 │
│  metadata:                                                       │
│    name: my-app                                                 │
│    namespace: my-app-namespace                                  │
│  spec:                                                           │
│    parentRefs:                                                   │
│    - name: envoy-gateway  ← References Gateway                 │
│      namespace: gateway                                         │
│    hostnames:                                                    │
│    - "app.timourhomelab.org"                                   │
│    rules:                                                        │
│    - backendRefs:                                                │
│      - name: my-service                                         │
│        port: 80                                                  │
│                                                                  │
│  ↓ No infrastructure knowledge needed                           │
│  ↓ Just hostname + service                                      │
│  ↓ Gateway handles TLS, load balancing, etc.                   │
└─────────────────────────────────────────────────────────────────┘
```

**Why This Separation?**

| Role | Responsibility | Can't Break |
|------|----------------|-------------|
| **Infrastructure Provider** | Provides Gateway implementations | Can't change how Gateways work |
| **Cluster Operator** | Configures Gateways, certificates, IPs | Can't affect individual apps |
| **App Developer** | Routes traffic to their services | Can't access other namespaces without permission |

**Contrast with Ingress:**
```
Ingress API (Old Way):
Everything in one resource = no role separation

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    # Infrastructure concerns mixed with app concerns
    nginx.ingress.kubernetes.io/rewrite: "/"
    cert-manager.io/cluster-issuer: "letsencrypt"
spec:
  # App developer has to know about infrastructure
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: app
            port:
              number: 80
```

---

## 🎯 Full Architecture Overview

### Full Traffic Flow

```
┌────────────────────────────────────────────────────────────────┐
│                         🌐 INTERNET                             │
│                    User: https://n8n.timourhomelab.org         │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ DNS Query
┌────────────────────────────────────────────────────────────────┐
│                    ☁️  CLOUDFLARE DNS                           │
│                                                                 │
│  Query: n8n.timourhomelab.org                                  │
│  Match: CNAME * → b5f4258e-xxxx.cfargotunnel.com              │
│  Return: 104.21.76.30, 172.67.186.29 (Cloudflare Edge IPs)   │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ HTTPS Request
┌────────────────────────────────────────────────────────────────┐
│                    ☁️  CLOUDFLARE EDGE                          │
│                    (104.21.76.30)                              │
│                                                                 │
│  1. TLS Handshake (SNI: n8n.timourhomelab.org)                │
│  2. WAF/DDoS Protection                                        │
│  3. Route to Tunnel                                            │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ Encrypted WireGuard Tunnel
┌────────────────────────────────────────────────────────────────┐
│              🔐 CLOUDFLARE TUNNEL (DaemonSet)                   │
│              6 pods across worker nodes                         │
│                                                                 │
│  Config:                                                        │
│  • service: https://envoy-gateway:443                          │
│  • originServerName: *.timourhomelab.org                       │
│  • noTLSVerify: true                                           │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ Forward to Gateway (HTTPS:443)
┌────────────────────────────────────────────────────────────────┐
│         🚪 ENVOY GATEWAY (192.168.68.152)                      │
│         LoadBalancer Service                                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────┐         │
│  │  🔒 TLS TERMINATION                              │         │
│  │                                                    │         │
│  │  Certificate: *.timourhomelab.org                │         │
│  │  Issuer: Let's Encrypt (via cert-manager)        │         │
│  │  Valid: 90 days (auto-renewed at day 60)         │         │
│  │                                                    │         │
│  │  1. Decrypt TLS                                   │         │
│  │  2. Extract SNI: n8n.timourhomelab.org           │         │
│  └──────────────────────────────────────────────────┘         │
│                                                                 │
│  ┌──────────────────────────────────────────────────┐         │
│  │  📝 HTTPROUTE MATCHING                           │         │
│  │                                                    │         │
│  │  Find HTTPRoute with:                             │         │
│  │  • hostname: n8n.timourhomelab.org               │         │
│  │  • path: /webhook* → n8n-webhook:5678           │         │
│  │  • path: / → n8n:5678                            │         │
│  └──────────────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ HTTP (plaintext) to backend
┌────────────────────────────────────────────────────────────────┐
│              ⚓ SERVICE: n8n-webhook                            │
│              ClusterIP: 10.98.123.45                           │
│                                                                 │
│  Load-balance to Pods:                                         │
│  • n8n-webhook-0: 10.244.3.12:5678                            │
│  • n8n-webhook-1: 10.244.5.67:5678                            │
└────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ Forward to Pod
┌────────────────────────────────────────────────────────────────┐
│              📦 POD: n8n-webhook-0                             │
│              IP: 10.244.3.12                                   │
│                                                                 │
│  Container listens on :5678                                    │
│  Processes webhook request                                     │
│  Returns HTTP 200 OK                                           │
└────────────────────────────────────────────────────────────────┘
                                 │
                    ◀────────────┘
                    Response flows back through:
                    Gateway → Tunnel → Edge → User
```

### Why Gateway API vs Ingress

```
┌─────────────────────────────────────────────────────────────────┐
│                    INGRESS (Old Way)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  apiVersion: networking.k8s.io/v1                               │
│  kind: Ingress                                                   │
│  metadata:                                                       │
│    annotations:                                                  │
│      nginx.ingress.kubernetes.io/rewrite: "/"  ← Implementation │
│      cert-manager.io/cluster-issuer: prod      ← specific       │
│  spec:                                                           │
│    rules:                                                        │
│    - host: app.example.com                                      │
│      http:                                                       │
│        paths:                                                    │
│        - path: /                                                │
│          backend:                                                │
│            service: app                                          │
│                                                                  │
│  ❌ Monolithic (everything in one resource)                     │
│  ❌ Annotations (untyped, implementation-specific)              │
│  ❌ Limited routing (path only)                                 │
│  ❌ Not portable (nginx ≠ traefik ≠ istio)                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   GATEWAY API (New Way)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GatewayClass (infra team)                                      │
│  ↓                                                               │
│  Gateway (infra team)                                           │
│  ↓                                                               │
│  HTTPRoute (app team)                                           │
│                                                                  │
│  apiVersion: gateway.networking.k8s.io/v1                       │
│  kind: HTTPRoute                                                 │
│  metadata:                                                       │
│    name: app                                                     │
│  spec:                                                           │
│    parentRefs:                                                   │
│    - name: envoy-gateway          ← Switch to cilium-gateway   │
│      namespace: gateway            (HTTPRoute stays same!)      │
│    hostnames:                                                    │
│    - "app.example.com"                                          │
│    rules:                                                        │
│    - matches:                                                    │
│      - path: {type: PathPrefix, value: "/"}                    │
│      - headers: [{name: X-Version, value: v2}]  ← Rich!        │
│      backendRefs:                                                │
│      - name: app-v2                                             │
│        weight: 90                  ← Traffic split!             │
│      - name: app-v1                                             │
│        weight: 10                                                │
│                                                                  │
│  ✅ Role-oriented (infra vs app separation)                     │
│  ✅ Type-safe (no magic annotations)                            │
│  ✅ Rich routing (headers, weights, mirrors)                    │
│  ✅ Portable (works with ANY Gateway implementation)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Installation (60 Minutes)

### Overview

```
Phase 1: cert-manager (15 min)
    ↓
Phase 2: Envoy Gateway (20 min)
    ↓
Phase 3: Cloudflare Tunnel (15 min)
    ↓
Phase 4: Test HTTPRoute (10 min)
```

---

### Phase 1: cert-manager (15 minutes)

**Why cert-manager?**
- Automates TLS certificate issuance and renewal
- Supports Let's Encrypt (free wildcard certificates)
- Gateway API integration (automatic Certificate creation)

**Install (Method 1: Basic - YAML):**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.0/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
```

**⚠️ IMPORTANT:** This basic installation doesn't include Gateway API support!

**Install (Method 2: Helm - WITH Gateway API support):**
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --version v1.16.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set "extraArgs={--enable-gateway-api}"
```

**The `--enable-gateway-api` flag enables:**
1. **Automatic Certificate creation** from Gateway annotations
2. **Gateway integration** - cert-manager watches Gateway resources
3. **TLS Secret management** - auto-creates secrets referenced by Gateway

**Without this flag:**
- You must manually create Certificate resources
- Gateway annotations like `cert-manager.io/issuer` are ignored
- More manual work, less automation

**Example - How it works:**
```yaml
# With --enable-gateway-api flag:
# ✅ cert-manager sees this annotation and auto-creates Certificate
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  namespace: gateway
  annotations:
    cert-manager.io/issuer: cloudflare-issuer  # ← Magic!
spec:
  listeners:
  - name: https
    tls:
      certificateRefs:
      - name: wildcard-tls  # ← cert-manager creates this Secret!

# Without flag:
# ❌ You must manually create this:
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-certificate
  namespace: gateway
spec:
  secretName: wildcard-tls
  issuerRef:
    name: cloudflare-issuer
  dnsNames:
  - "*.timourhomelab.org"
```

**Verify cert-manager is running:**
```bash
kubectl get pods -n cert-manager
# NAME                                       READY   STATUS
# cert-manager-xxxxx                         1/1     Running
# cert-manager-cainjector-xxxxx              1/1     Running
# cert-manager-webhook-xxxxx                 1/1     Running
```

---

**Create Cloudflare API Token:**
```
Cloudflare Dashboard → My Profile → API Tokens → Create Token
Template: Edit Zone DNS
Permissions: Zone / DNS / Edit
Zone: timourhomelab.org
```

**Create ClusterIssuer:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

**✅ Checkpoint:** `kubectl get clusterissuer` → READY: True

---

### Phase 2: Envoy Gateway (20 minutes)

**Why Envoy Gateway?**
- Official CNCF Gateway API implementation
- Based on Envoy Proxy (industry standard)
- Full Gateway API v1.3.0 conformance
- Production-ready (used by AWS, Google, etc.)

**Install:**
```bash
helm repo add envoyproxy https://github.com/envoyproxy/gateway/releases/download/latest/helm-chart.tgz
helm repo update

helm install envoy-gateway envoyproxy/gateway \
  --version v1.2.4 \
  --namespace envoy-gateway-system \
  --create-namespace \
  --wait
```

**What gets installed:**
- **Envoy Gateway Controller** - Reconciles Gateway/HTTPRoute resources
- **Envoy Proxy DaemonSet** - Handles actual traffic (deployed per-node)
- **GatewayClass** - Automatically created (infrastructure provider role)

**Verify Installation:**
```bash
# Check pods are running
kubectl get pods -n envoy-gateway-system
# NAME                             READY   STATUS
# envoy-gateway-xxxxx              1/1     Running
# envoy-xxxxx-proxy-yyyyy          1/1     Running

# Check GatewayClass was created
kubectl get gatewayclass
# NAME             CONTROLLER                                      AGE
# envoy-gateway    gateway.envoyproxy.io/gatewayclass-controller   30s

# Describe GatewayClass to see supported features
kubectl describe gatewayclass envoy-gateway
```

**GatewayClass Output Explained:**
```yaml
Name:         envoy-gateway
Namespace:
API Version:  gateway.networking.k8s.io/v1
Kind:         GatewayClass
Spec:
  Controller Name:  gateway.envoyproxy.io/gatewayclass-controller
Status:
  Conditions:
    Status:  True
    Type:    Accepted
  Supported Features:
    Gateway:
    - Gateway
    - GatewayPort8080
    - GatewayStaticAddresses
    HTTPRoute:
    - HTTPRoute
    - HTTPRouteDestinationPortMatching
    - HTTPRouteHeaderMatching
    - HTTPRouteHostRewrite
    - HTTPRouteMethodMatching
    - HTTPRoutePathRedirect
    - HTTPRoutePathRewrite
    - HTTPRoutePortRedirect
    - HTTPRouteQueryParamMatching
    - HTTPRouteRequestMirror
    - HTTPRouteResponseHeaderModification
    - HTTPRouteSchemeRedirect
```

**Key Points:**
- ✅ **Automatic GatewayClass creation** - No manual YAML needed (unlike Cilium)
- ✅ **Controller watches for Gateways** - When you create Gateway resource, Envoy Gateway picks it up
- ✅ **Supported Features** - Shows which Gateway API features work

**✅ Checkpoint 1:** GatewayClass exists and is Accepted

---

**Create Gateway + Certificate:**
```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: gateway
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  dnsNames:
  - "*.timourhomelab.org"
  - "timourhomelab.org"
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  namespace: gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.timourhomelab.org"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: wildcard-tls
    allowedRoutes:
      namespaces:
        from: All
```

```bash
kubectl create namespace gateway
kubectl apply -f gateway.yaml

# Wait for certificate (60-90 seconds)
kubectl get certificate -n gateway wildcard-tls -w
# READY: True ✅

# Check Gateway
kubectl get gateway -n gateway
# PROGRAMMED: True, ADDRESS: 192.168.68.152 ✅
```

---

### Phase 3: Cloudflare Tunnel (15 minutes)

**Create Tunnel:**
```bash
cloudflared tunnel login
cloudflared tunnel create talos-homelab
cloudflared tunnel route dns talos-homelab "*.timourhomelab.org"
```

**Config (Vegard Style):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflared
data:
  config.yaml: |
    tunnel: YOUR_TUNNEL_ID
    credentials-file: /etc/cloudflared/credentials/credentials.json

    ingress:
      # ALL traffic via Gateway (HTTPS)
      - hostname: "*.timourhomelab.org"
        service: https://envoy-gateway-SERVICE_NAME.envoy-gateway-system.svc:443
        originRequest:
          originServerName: "*.timourhomelab.org"
          noTLSVerify: true

      - service: http_status:404
```

**Deploy DaemonSet:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
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
        image: cloudflare/cloudflared:2024.10.0
        args: ["tunnel", "--config", "/etc/cloudflared/config/config.yaml", "run"]
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config
        - name: credentials
          mountPath: /etc/cloudflared/credentials
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: credentials
        secret:
          secretName: tunnel-credentials
```

**✅ Checkpoint:** Cloudflare Dashboard → Tunnels → Status: HEALTHY

---

### Phase 4: Test HTTPRoute (10 minutes)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: test
  namespace: default
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
    sectionName: https
  hostnames:
  - "test.timourhomelab.org"
  rules:
  - backendRefs:
    - name: nginx
      port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

```bash
kubectl apply -f test.yaml
curl https://test.timourhomelab.org
# ✅ Should return nginx welcome page
```

---

## 🔐 How cert-manager Works (DNS-01)

### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: You create Certificate                                 │
│                                                                  │
│  apiVersion: cert-manager.io/v1                                 │
│  kind: Certificate                                               │
│  spec:                                                           │
│    dnsNames: ["*.timourhomelab.org"]                           │
│    issuerRef: {name: letsencrypt-production}                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: cert-manager creates Order                             │
│                                                                  │
│  Order tells Let's Encrypt:                                     │
│  "I want a certificate for *.timourhomelab.org"                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: Let's Encrypt responds with Challenge                  │
│                                                                  │
│  "Prove you own timourhomelab.org by creating TXT record:"     │
│  _acme-challenge.timourhomelab.org = "X7eP9kQ2mN5rT8wY..."     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: cert-manager calls Cloudflare API                      │
│                                                                  │
│  POST https://api.cloudflare.com/zones/ZONE_ID/dns_records     │
│  {                                                               │
│    "type": "TXT",                                               │
│    "name": "_acme-challenge.timourhomelab.org",                │
│    "content": "X7eP9kQ2mN5rT8wY...",                           │
│    "ttl": 120                                                    │
│  }                                                               │
│                                                                  │
│  ✅ TXT record created!                                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ Wait 60 seconds (DNS propagation)
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: Let's Encrypt verifies TXT record                      │
│                                                                  │
│  dig TXT _acme-challenge.timourhomelab.org                      │
│  → Returns: "X7eP9kQ2mN5rT8wY..."                              │
│                                                                  │
│  ✅ Domain ownership verified!                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 6: Let's Encrypt issues certificate                       │
│                                                                  │
│  Certificate:                                                    │
│  • Subject: *.timourhomelab.org                                │
│  • Issuer: Let's Encrypt                                        │
│  • Valid: 90 days                                               │
│  • Type: RSA 2048-bit                                           │
│                                                                  │
│  Signed by Let's Encrypt CA                                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 7: cert-manager stores certificate in Secret              │
│                                                                  │
│  apiVersion: v1                                                  │
│  kind: Secret                                                    │
│  metadata:                                                       │
│    name: wildcard-tls                                           │
│  data:                                                           │
│    tls.crt: BASE64_ENCODED_CERTIFICATE                          │
│    tls.key: BASE64_ENCODED_PRIVATE_KEY                          │
│    ca.crt: BASE64_ENCODED_CA_CHAIN                              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 8: Gateway references Secret                              │
│                                                                  │
│  Gateway:                                                        │
│    tls:                                                          │
│      certificateRefs:                                            │
│      - name: wildcard-tls  ← Uses this Secret                  │
│                                                                  │
│  Gateway automatically reloads when Secret updates!             │
└─────────────────────────────────────────────────────────────────┘
```

### Auto-Renewal

```
Day 0                Day 30               Day 60               Day 90
│                    │                    │                    │
│ Certificate        │                    │ cert-manager       │ Certificate
│ issued             │                    │ starts renewal     │ expires
│                    │                    │ (automatic)        │
▼                    ▼                    ▼                    ▼
────────────────────────────────────────────────────────────────►
        Valid                  Renewal Zone (30 days)         Expire

How it works:
1. cert-manager checks certificates every 12 hours
2. If < 30 days remaining → trigger renewal
3. Renewal uses same DNS-01 challenge flow
4. New certificate → Update Secret
5. Gateway hot-reloads (no downtime!)
```

**Key Points:**
- ✅ Fully automated (no manual work)
- ✅ 30-day renewal window (safety margin)
- ✅ Zero downtime (hot-reload)
- ✅ DNS-01 required for wildcard certs

---

## 🔄 Switching Gateway Implementations

### Why Switch?

```
Reasons to migrate Gateway implementations:
────────────────────────────────────────────
🐛 Bugs/Instability    → Implementation has critical issues
🚀 Performance         → Need better throughput/latency
🔧 Features            → Different implementation has features you need
💰 Cost               → Resource usage differences
🏢 Company Policy     → Standardization requirements
```

### Our Journey (Real Story)

```
Oct 2024: Cilium Gateway v1.14
    ↓
    Problems:
    • Rate limit errors (429)
    • TLS handshake failures
    • Gateway stuck PROGRAMMED: False
    ↓
Nov 2024: Migrated to Envoy Gateway v1.2.4
    ↓
    Result: Rock solid! ✅
```

### Migration Strategy (Zero Downtime)

```
┌─────────────────────────────────────────────────────────────────┐
│                    BLUE-GREEN MIGRATION                          │
└─────────────────────────────────────────────────────────────────┘

Step 1: Install new Gateway (parallel to old)
──────────────────────────────────────────────

    OLD                          NEW
┌──────────────┐            ┌──────────────┐
│ Cilium       │            │ Envoy        │
│ Gateway      │            │ Gateway      │
│              │            │              │
│ 192.168.68   │            │ 192.168.68   │
│ .152         │            │ .153         │
│              │            │              │
│ HTTPRoutes → │            │ (empty)      │
└──────────────┘            └──────────────┘
    ▲
    │ ALL traffic here
    100% of users


Step 2: Test new Gateway with single HTTPRoute
──────────────────────────────────────────────

    OLD                          NEW
┌──────────────┐            ┌──────────────┐
│ Cilium       │            │ Envoy        │
│ Gateway      │            │ Gateway      │
│              │            │              │
│ 99% traffic  │            │ 1% traffic   │
│              │            │ (test only)  │
│ HTTPRoutes → │            │ test-route → │
└──────────────┘            └──────────────┘


Step 3: Gradually move HTTPRoutes (5-10 at a time)
──────────────────────────────────────────────────

    OLD                          NEW
┌──────────────┐            ┌──────────────┐
│ Cilium       │            │ Envoy        │
│ Gateway      │            │ Gateway      │
│              │            │              │
│ 50% traffic  │            │ 50% traffic  │
│              │            │              │
│ HTTPRoutes   │            │ HTTPRoutes   │
│ (half)    →  │            │ (half)    →  │
└──────────────┘            └──────────────┘


Step 4: Complete migration
──────────────────────────────────────────────

    OLD                          NEW
┌──────────────┐            ┌──────────────┐
│ Cilium       │            │ Envoy        │
│ Gateway      │            │ Gateway      │
│              │            │              │
│ (empty)      │            │ 100% traffic │
│              │            │              │
│ (delete)     │            │ HTTPRoutes → │
└──────────────┘            └──────────────┘
                                 ▲
                                 │
                            ALL traffic here
```

### What Changes (Minimal!)

**HTTPRoute stays IDENTICAL** - only `parentRef` changes:

```yaml
# Before (Cilium)
spec:
  parentRefs:
  - name: cilium-gateway
    namespace: gateway
    sectionName: https-gateway

# After (Envoy)
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
    sectionName: https
```

**Everything else stays the same:**
- ✅ Hostnames unchanged
- ✅ Path matching unchanged
- ✅ Backend services unchanged
- ✅ TLS certificates unchanged (reused!)

---

## 📝 HTTPRoute Examples

### Example 1: Simple Service

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
    sectionName: https
  hostnames:
  - "argo.timourhomelab.org"
  rules:
  - backendRefs:
    - name: argocd-server
      port: 80
```

### Example 2: Path-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: n8n
  namespace: n8n-prod
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
    sectionName: https
  hostnames:
  - "n8n.timourhomelab.org"
  rules:
  # Webhooks → HA processors
  - matches:
    - path: {type: PathPrefix, value: "/webhook"}
    - path: {type: PathPrefix, value: "/webhook-test"}
    backendRefs:
    - name: n8n-webhook
      port: 5678

  # Everything else → main UI
  - matches:
    - path: {type: PathPrefix, value: "/"}
    backendRefs:
    - name: n8n
      port: 5678
```

### Example 3: Traffic Split (Canary)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
  hostnames:
  - "app.example.com"
  rules:
  - backendRefs:
    - name: app-v2
      port: 80
      weight: 10    # 10% traffic to new version
    - name: app-v1
      port: 80
      weight: 90    # 90% traffic to stable version
```

### Example 4: Header-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api
spec:
  parentRefs:
  - name: envoy-gateway
    namespace: gateway
  hostnames:
  - "api.example.com"
  rules:
  # Beta users (header: X-Beta-User: true) → v2
  - matches:
    - headers:
      - name: X-Beta-User
        value: "true"
    backendRefs:
    - name: api-v2
      port: 8080

  # Everyone else → v1
  - backendRefs:
    - name: api-v1
      port: 8080
```

---

## 🔧 Troubleshooting

### Issue 1: Service Not Accessible (502)

**Symptom:** `curl https://n8n.timourhomelab.org` → HTTP/2 502

**Debug Flow:**
```
1. Check Gateway
   kubectl get gateway -n gateway envoy-gateway
   → Should be: PROGRAMMED: True, ADDRESS: 192.168.68.152

2. Check Certificate
   kubectl get certificate -n gateway wildcard-tls
   → Should be: READY: True

3. Check HTTPRoute
   kubectl get httproute -n n8n-prod n8n
   → Should be: ACCEPTED: True

4. Check Service
   kubectl get svc -n n8n-prod n8n
   → Should have ENDPOINTS

5. Check Pod
   kubectl get pods -n n8n-prod
   → Should be Running

6. Check Gateway logs
   kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=50
```

**Common Fixes:**
- ❌ Service name typo → Fix `backendRefs`
- ❌ Wrong namespace → Add namespace to `backendRef`
- ❌ Pod not running → Check pod logs

---

### Issue 2: DNS Resolves to Wrong IP

**Symptom:** `dig n8n.timourhomelab.org` → 192.168.68.152 (LAN IP)

**Why:** Specific A record overrides wildcard CNAME

**DNS Priority:**
```
1. A record (n8n → 192.168.68.152)     ← Highest priority
2. CNAME (n8n → tunnel)
3. CNAME (* → tunnel)                   ← Lowest priority
```

**Fix:**
1. Delete specific A record in Cloudflare Dashboard
2. Keep only: `CNAME * → TUNNEL_ID.cfargotunnel.com`
3. Wait 60s, test: `dig n8n.timourhomelab.org` → Should return Cloudflare Edge IPs

---

### Issue 3: Certificate Not Issuing

**Symptom:** Certificate stuck in READY: False

**Debug:**
```bash
kubectl describe certificate -n gateway wildcard-tls
kubectl get order -n gateway
kubectl describe order -n gateway ORDER_NAME
kubectl get challenge -n gateway
kubectl describe challenge -n gateway CHALLENGE_NAME
kubectl logs -n cert-manager deployment/cert-manager --tail=100
```

**Common Issues:**
- ❌ Invalid Cloudflare API token → Recreate with `Zone DNS Edit` permission
- ❌ Rate limit → Wait 1 hour (Let's Encrypt: 50 certs/week/domain)
- ❌ DNS propagation slow → Wait 2-3 minutes

---

### Issue 4: Cloudflare Tunnel Not Connecting

**Symptom:** `kubectl get pods -n cloudflared` → CrashLoopBackOff

**Debug:**
```bash
kubectl logs -n cloudflared cloudflared-xxx
# Look for: "failed to authenticate tunnel"

# Check credentials
kubectl get secret -n cloudflared tunnel-credentials -o jsonpath='{.data.credentials\.json}' | base64 -d | jq .

# Verify tunnel exists in Cloudflare Dashboard
# → Zero Trust → Tunnels → Should see talos-homelab
```

**Fix:** Recreate tunnel credentials if secret is corrupted

---

### Issue 5: HTTPRoute Not Working After Gateway Switch

**Symptom:** Changed Gateway, HTTPRoute not accessible

**Fix:** Update `parentRefs` in HTTPRoute

```bash
# Bulk update all HTTPRoutes
find . -name "*.yaml" -type f -exec grep -l "kind: HTTPRoute" {} \; | \
  xargs sed -i '' 's/name: cilium-gateway/name: envoy-gateway/g'
```

---

## 📊 Monitoring Commands

```bash
# Gateway status
kubectl get gateway -A

# All HTTPRoutes
kubectl get httproutes -A

# Certificate expiry
kubectl get certificate -A

# Tunnel health
kubectl get pods -n cloudflared
kubectl logs -n cloudflared -l app=cloudflared --tail=20

# Gateway logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway -f

# Watch events
kubectl get events -n gateway --watch
```

---

## 🎓 Key Concepts Summary

**Gateway API Resources:**
```
GatewayClass     → Which implementation (Envoy, Cilium, Istio)
    ↓
Gateway          → LoadBalancer + Listeners (HTTP:80, HTTPS:443)
    ↓
HTTPRoute        → Routing rules (hostname + path → service)
    ↓
Service          → Kubernetes Service
    ↓
Pods             → Application containers
```

**cert-manager:**
- ✅ Automates Let's Encrypt certificates
- ✅ DNS-01 challenge for wildcard certs
- ✅ Auto-renewal every 60 days (expires at 90)
- ✅ Zero-downtime hot-reload

**Cloudflare Tunnel:**
- ✅ Zero Trust (no inbound firewall ports)
- ✅ Encrypted WireGuard tunnel
- ✅ DDoS protection at Edge
- ✅ Global CDN

---

## 🌐 Production Alternatives to Cloudflare Tunnel

> **Different ways to expose your Gateway to the internet - from simple to enterprise**

This guide uses **Cloudflare Tunnel** (free, Zero Trust, no open ports), but here are production alternatives based on your requirements.

---

### Comparison Table

| Solution | Cost | Complexity | Zero Trust | Open Ports | Use Case |
|----------|------|------------|------------|------------|----------|
| **Cloudflare Tunnel** | Free | Medium | ✅ Yes | ❌ None | Homelab, CGNAT, dynamic IP |
| **Direct LoadBalancer** | Free* | Low | ❌ No | ✅ Yes | Static IP, simple setup |
| **Tailscale** | Free/Paid | Low | ✅ Yes | ❌ None | Private access, mesh network |
| **Inlets** | Self-hosted | Medium | ⚠️ Optional | ❌ None | Self-hosted tunnel, no SaaS |
| **Gloo Gateway (Solo.io)** | Paid | High | ✅ Yes | ✅ Optional | Enterprise, API Gateway + ZTNA |
| **Appgate SDP** | Enterprise | High | ✅ Yes | ❌ None | Enterprise ZTNA, compliance |
| **Ngrok** | Free/Paid | Low | ⚠️ Paid | ❌ None | Development, quick testing |

**Cost notes:**
- Free* = No software cost, but may require cloud provider LoadBalancer ($$$)
- Self-hosted = Infrastructure cost only
- Paid = Subscription required for production features

---

### Option 1: Direct LoadBalancer Exposure (Simplest)

**Best for:** Static public IP, no CGNAT, simple setup

```
┌─────────────────────────────────────────────────────────────┐
│                      🌐 INTERNET                             │
│                  Public IP: 203.0.113.45                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ Port 443
┌─────────────────────────────────────────────────────────────┐
│              🏠 YOUR ROUTER/FIREWALL                         │
│              Port Forward: 443 → 192.168.68.152             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           🚪 ENVOY GATEWAY (LoadBalancer Service)           │
│           IP: 192.168.68.152                                │
│           Port: 443 (HTTPS)                                 │
└─────────────────────────────────────────────────────────────┘
```

**Setup:**
```bash
# 1. Gateway is already exposed via LoadBalancer Service
kubectl get svc -n envoy-gateway-system
# NAME                    TYPE           EXTERNAL-IP       PORT(S)
# envoy-gateway-service   LoadBalancer   192.168.68.152    443:30443/TCP

# 2. Configure port forwarding in your router
# Router: Forward port 443 → 192.168.68.152:443

# 3. Point DNS to your public IP
# DNS: A *.timourhomelab.org → 203.0.113.45
```

**Pros:**
- ✅ Simple setup (just port forward)
- ✅ Low latency (direct connection)
- ✅ No third-party dependencies
- ✅ Free (no subscription)

**Cons:**
- ❌ Requires static public IP
- ❌ Doesn't work behind CGNAT
- ❌ Open firewall ports (security risk)
- ❌ No DDoS protection
- ❌ Exposes your home IP address

---

### Option 2: Tailscale Funnel (Private + Public Hybrid)

**Best for:** Private access + selective public exposure

```
┌─────────────────────────────────────────────────────────────┐
│                     🌐 INTERNET                              │
└─────────────────────────────────────────────────────────────┘
         │                                    │
         ▼ Public (Funnel)                   ▼ Private (VPN)
┌───────────────────┐              ┌─────────────────────┐
│  Tailscale        │              │  Your Laptop        │
│  DERP Relay       │              │  (Tailscale Client) │
│  (global edge)    │              └─────────────────────┘
└───────────────────┘                        │
         │                                    │
         └──────────────┬─────────────────────┘
                        ▼ Encrypted WireGuard
┌─────────────────────────────────────────────────────────────┐
│              🚪 ENVOY GATEWAY                                │
│              Exposed via Tailscale                          │
└─────────────────────────────────────────────────────────────┘
```

**Setup:**
```bash
# 1. Install Tailscale Operator
kubectl apply -f https://github.com/tailscale/tailscale/releases/latest/download/operator.yaml

# 2. Create Tailscale AuthKey (one-time setup)
# https://login.tailscale.com/admin/settings/keys

# 3. Store AuthKey as Secret
kubectl create secret generic tailscale-auth \
  --from-literal=TS_AUTHKEY=tskey-xxx \
  --namespace=tailscale

# 4. Expose Gateway via Tailscale
kubectl annotate gateway envoy-gateway \
  tailscale.com/expose=true \
  tailscale.com/hostname=gateway \
  -n gateway

# 5. Enable Funnel (public HTTPS access)
tailscale funnel --bg 443
```

**Tailscale Pricing:**
- **Free Plan**: Up to 100 devices, community support
- **Personal Pro**: $48/year - 1 user, unlimited devices
- **Starter**: $6/user/month - Teams, SSO
- **Premium**: $18/user/month - Enterprise features

**Pros:**
- ✅ Zero Trust networking
- ✅ No open firewall ports
- ✅ Works behind CGNAT
- ✅ Automatic mesh networking
- ✅ Private access + public Funnel option
- ✅ ACLs for fine-grained access control

**Cons:**
- ❌ Not free for production teams
- ❌ Funnel requires paid plan for custom domains
- ❌ Adds latency (relay)
- ❌ Limited to Layer 4 (not optimized for web apps)

**Resources:**
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale Funnel](https://tailscale.com/kb/1223/funnel)

---

### Option 3: Inlets (Self-Hosted Tunnel)

**Best for:** Self-hosted alternative to Cloudflare Tunnel, no SaaS dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                      🌐 INTERNET                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│               ☁️  INLETS EXIT SERVER                         │
│               (VPS with public IP)                          │
│               Example: DigitalOcean Droplet $6/mo           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ Encrypted Tunnel
┌─────────────────────────────────────────────────────────────┐
│              🏠 INLETS CLIENT (in Kubernetes)               │
│              Connects to exit server                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              🚪 ENVOY GATEWAY                                │
└─────────────────────────────────────────────────────────────┘
```

**Setup:**
```bash
# 1. Create VPS (exit server) - DigitalOcean, Hetzner, etc.
# Ubuntu 22.04, 1GB RAM, Public IP

# 2. Install inlets on exit server
curl -sLS https://get.inlets.dev | sh
inlets server --token=YOUR_SECRET_TOKEN

# 3. Install inlets operator in Kubernetes
kubectl apply -f https://raw.githubusercontent.com/inlets/inlets-operator/master/artifacts/operator.yaml

# 4. Create IngressController resource
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway-public
  namespace: envoy-gateway-system
  annotations:
    inlets.dev/upstream: "gateway.envoy-gateway-system.svc.cluster.local:443"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 443
```

**Pricing:**
- **Inlets OSS**: Free (Apache 2.0 license)
- **Inlets Pro**: $50/month - TCP/HTTPS tunnels, production support
- **VPS Cost**: $5-10/month (DigitalOcean, Hetzner, Linode)

**Pros:**
- ✅ Self-hosted (you own the infrastructure)
- ✅ No SaaS vendor lock-in
- ✅ Works behind CGNAT/dynamic IP
- ✅ Supports any Ingress Controller
- ✅ TCP + HTTP tunnels

**Cons:**
- ❌ Requires VPS management
- ❌ You handle security patches
- ❌ No global edge network (single VPS)
- ❌ Pro version needed for production

**Resources:**
- [Inlets Documentation](https://inlets.dev/)
- [Inlets Kubernetes Operator](https://github.com/inlets/inlets-operator)

---

### Option 4: Gloo Gateway 2.0 (Solo.io) - Enterprise ZTNA

**Best for:** Enterprise environments, API Gateway + Service Mesh + Zero Trust

```
┌─────────────────────────────────────────────────────────────┐
│                    🌐 INTERNET / USERS                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ☁️  GLOO GATEWAY (Edge Proxy)                   │
│              - API Gateway (Envoy-based)                    │
│              - WAF, Rate Limiting, JWT validation           │
│              - Zero Trust policies                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              🔒 GLOO MESH (Service Mesh)                     │
│              - mTLS between services                        │
│              - Service-to-Service Zero Trust                │
│              - Istio integration                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              📝 HTTPRoute Resources                          │
│              (Gateway API v1.3.0 compatible!)               │
└─────────────────────────────────────────────────────────────┘
```

**Features:**
- ✅ **Gateway API v1.3.0 native** (drop-in replacement for Envoy Gateway!)
- ✅ Zero Trust security (defense-in-depth)
- ✅ API Gateway + Service Mesh unified
- ✅ AI-ready data planes (rate limiting for LLM APIs)
- ✅ Ambient mesh integration (sidecar-less)
- ✅ Enterprise support + SLA

**Setup:**
```bash
# 1. Install Gloo Gateway (replaces Envoy Gateway)
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm install gloo-gateway gloo/gloo-gateway \
  --namespace gloo-system \
  --create-namespace

# 2. Your existing Gateway + HTTPRoute resources work unchanged!
# (Gateway API v1.3.0 compatible)

# 3. Add Zero Trust policies (optional)
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: AuthPolicy
metadata:
  name: jwt-validation
  namespace: gateway
spec:
  targetRefs:
  - kind: Gateway
    name: envoy-gateway
  jwt:
    providers:
    - issuer: https://auth.timourhomelab.org
      jwks:
        remote:
          url: https://auth.timourhomelab.org/.well-known/jwks.json
EOF
```

**Pricing:**
- **Gloo Gateway OSS**: Free (open source)
- **Gloo Gateway Enterprise**: Contact sales - starts ~$10k/year

**Pros:**
- ✅ Gateway API v1.3.0 native (your HTTPRoutes work unchanged!)
- ✅ Enterprise-grade Zero Trust
- ✅ Unified API Gateway + Service Mesh
- ✅ Production SLA + support
- ✅ Extends Gateway API with enterprise features

**Cons:**
- ❌ Expensive for small teams
- ❌ Complexity (service mesh learning curve)
- ❌ Overkill for simple use cases

**Resources:**
- [Gloo Gateway 2.0 Announcement](https://www.solo.io/blog/gloo-gateway-2-0/)
- [Gateway API Integration](https://docs.solo.io/gloo-gateway/latest/gateway-api/)

---

### Option 5: Appgate SDP - Enterprise ZTNA

**Best for:** Large enterprises, compliance (HIPAA, PCI-DSS), service-to-service Zero Trust

```
┌─────────────────────────────────────────────────────────────┐
│                 👥 USERS (Remote Workers)                    │
│                 Appgate SDP Client installed                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ Identity verification
┌─────────────────────────────────────────────────────────────┐
│              🔐 APPGATE SDP CONTROLLER                       │
│              - Identity-based policies                      │
│              - Device posture checks                        │
│              - MFA enforcement                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ Dynamic access
┌─────────────────────────────────────────────────────────────┐
│              🚪 SDP GATEWAY (per Kubernetes cluster)        │
│              - Least privilege access                       │
│              - Microsegmentation                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ☸  KUBERNETES WORKLOADS                        │
│              User-to-Service + Service-to-Service ZTNA      │
└─────────────────────────────────────────────────────────────┘
```

**Features:**
- ✅ Zero Trust for Kubernetes (user + service access)
- ✅ Least privilege access (dynamic policies)
- ✅ Device posture checks (compliance)
- ✅ Works with any Ingress/Gateway
- ✅ Unified policy model

**Pricing:**
- Enterprise only (contact sales)
- Typically $30-100/user/year

**Pros:**
- ✅ Enterprise-grade ZTNA
- ✅ Compliance ready (HIPAA, PCI-DSS, SOC 2)
- ✅ Unified user + service access
- ✅ Works with existing Gateway API setup

**Cons:**
- ❌ Enterprise pricing only
- ❌ Complex setup
- ❌ Requires client software on user devices

**Resources:**
- [Appgate Kubernetes Security](https://www.appgate.com/blog/kubernetes-security-best-practices-zero-trust-access)

---

### Option 6: Open Source ZTNA Alternatives

**Pomerium** (Open Source Zero Trust)
```bash
# Pomerium as reverse proxy before Gateway
helm install pomerium pomerium/pomerium \
  --namespace pomerium \
  --set authenticate.idp.provider=google \
  --set proxy.service.type=LoadBalancer
```

**Features:**
- ✅ Open source (Apache 2.0)
- ✅ Identity-aware proxy
- ✅ Works with any IdP (Google, Okta, etc.)
- ✅ Kubernetes native
- ✅ Free for unlimited users

**Resources:**
- [Pomerium](https://www.pomerium.com/)

---

**FerrumGate** (Open Source ZTNA)
```bash
# FerrumGate ZTNA platform
docker run -d \
  -p 443:443 \
  -v /data:/data \
  ferrumgate/ferrumgate:latest
```

**Features:**
- ✅ Fully open source
- ✅ Zero Trust network access
- ✅ No client software needed (browser-based)
- ✅ Self-hosted

**Resources:**
- [FerrumGate](https://ferrumgate.com/)

---

### Decision Tree: Which Option to Choose?

```
Do you have a static public IP?
├─ YES → Do you need Zero Trust security?
│         ├─ NO → Use Direct LoadBalancer (simplest!)
│         └─ YES → Enterprise? → Gloo Gateway or Appgate SDP
│                              → Homelab? → Pomerium or FerrumGate
│
└─ NO (CGNAT/Dynamic IP) → Free or Paid?
          ├─ FREE → Cloudflare Tunnel (your current setup!)
          ├─ PAID (Self-hosted) → Inlets ($5/mo VPS + $50/mo Pro)
          └─ PAID (Managed) → Tailscale ($48/year) or Ngrok ($8/mo)
```

---

### Migration Example: Cloudflare Tunnel → Direct LoadBalancer

If you want to switch from Cloudflare Tunnel to direct exposure:

```bash
# 1. Remove Cloudflared DaemonSet
kubectl delete daemonset cloudflared -n cloudflared

# 2. Gateway is already exposed (LoadBalancer Service exists)
kubectl get svc -n envoy-gateway-system
# NAME                    EXTERNAL-IP       PORT(S)
# envoy-gateway-service   192.168.68.152    443:30443/TCP

# 3. Configure port forwarding in router
# Forward port 443 → 192.168.68.152

# 4. Update DNS (remove CNAME, add A record)
# DELETE: CNAME * → tunnel.cfargotunnel.com
# ADD:    A     * → YOUR_PUBLIC_IP

# 5. HTTPRoutes unchanged! Gateway API is portable!
```

**Zero downtime migration:**
1. Set up new ingress method (parallel)
2. Update DNS TTL to 60 seconds
3. Switch DNS records
4. Wait 60 seconds
5. Remove old ingress method

---

### Recommendation Summary

| Your Situation | Best Option | Why |
|----------------|-------------|-----|
| **Homelab, CGNAT, Free** | Cloudflare Tunnel | Your current setup! Zero Trust, free, no ports |
| **Static IP, Simple** | Direct LoadBalancer | Simplest setup, lowest latency |
| **Private + Public access** | Tailscale | Mesh network + Funnel for public |
| **Self-hosted, No SaaS** | Inlets | You control everything, $5-10/mo VPS |
| **Enterprise, Zero Trust** | Gloo Gateway or Appgate | Production SLA, compliance ready |
| **Open Source ZTNA** | Pomerium or FerrumGate | Free, identity-aware access |

**Your current Cloudflare Tunnel setup is excellent for homelab!** It's free, Zero Trust, and works behind CGNAT. Only switch if:
- You get a static public IP → Direct LoadBalancer (simpler)
- You need private mesh networking → Tailscale
- You want to self-host everything → Inlets
- You need enterprise compliance → Gloo Gateway or Appgate

---

## 📦 GitOps Summary (ArgoCD + Kustomize)

> **Complete Infrastructure as Code setup following GitOps best practices**

This section provides complete Kustomize + Helm configurations for declarative GitOps deployment with ArgoCD.

---

### Directory Structure

```
kubernetes/
├── infrastructure/
│   ├── network/
│   │   ├── gateway/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── gateway-class.yaml (optional - Envoy creates automatically)
│   │   │   ├── cloudflare-issuer.yaml
│   │   │   ├── cloudflare-api-token-sealed.yaml
│   │   │   └── gateway.yaml
│   │   │
│   │   ├── envoy-gateway/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   └── values.yaml (Helm values)
│   │   │
│   │   └── cloudflared/
│   │       ├── kustomization.yaml
│   │       ├── namespace.yaml
│   │       ├── config.yaml
│   │       ├── tunnel-credentials-sealed.yaml
│   │       └── daemonset.yaml
│   │
│   └── cert-manager/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       └── values.yaml (Helm values)
```

---

### 1. Gateway API Resources

**File: `infrastructure/network/gateway/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: gateway

resources:
  # Install Gateway API v1.3.0 CRDs
  - https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
  # Optional: TLSRoute experimental CRD
  - https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

  # Local resources
  - namespace.yaml
  - cloudflare-api-token-sealed.yaml
  - cloudflare-issuer.yaml
  - gateway.yaml
```

**File: `infrastructure/network/gateway/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gateway
  labels:
    name: gateway
```

**File: `infrastructure/network/gateway/cloudflare-api-token-sealed.yaml`**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: cloudflare-api-token
  namespace: gateway
spec:
  encryptedData:
    api-token: <SEALED_SECRET_HERE>
  template:
    metadata:
      name: cloudflare-api-token
      namespace: gateway
    type: Opaque
```

**File: `infrastructure/network/gateway/cloudflare-issuer.yaml`**
```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cloudflare-issuer
  namespace: gateway
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: cloudflare-key
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

**File: `infrastructure/network/gateway/gateway.yaml`**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  namespace: gateway
  annotations:
    cert-manager.io/issuer: cloudflare-issuer
spec:
  gatewayClassName: envoy-gateway
  addresses:
  - type: IPAddress
    value: 192.168.68.152
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.timourhomelab.org"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: wildcard-tls
    allowedRoutes:
      namespaces:
        from: All
```

---

### 2. Envoy Gateway (Helm)

**File: `infrastructure/network/envoy-gateway/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml

helmCharts:
- name: gateway
  repo: https://github.com/envoyproxy/gateway/releases/download/latest/helm-chart.tgz
  version: v1.2.4
  releaseName: envoy-gateway
  namespace: envoy-gateway-system
  valuesFile: values.yaml
```

**File: `infrastructure/network/envoy-gateway/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: envoy-gateway-system
```

**File: `infrastructure/network/envoy-gateway/values.yaml`**
```yaml
# Minimal values - Envoy Gateway has good defaults
createNamespace: false

config:
  envoyGateway:
    gateway:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller

# Resource limits (optional)
deployment:
  replicas: 1
  pod:
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

---

### 3. cert-manager (Helm)

**File: `infrastructure/cert-manager/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml

helmCharts:
- name: cert-manager
  repo: https://charts.jetstack.io
  version: v1.16.2
  releaseName: cert-manager
  namespace: cert-manager
  valuesFile: values.yaml
```

**File: `infrastructure/cert-manager/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
```

**File: `infrastructure/cert-manager/values.yaml`**
```yaml
# Install CRDs
crds:
  enabled: true

# CRITICAL: Enable Gateway API support
extraArgs:
- --enable-gateway-api

# Resource limits
resources:
  limits:
    cpu: 100m
    memory: 256Mi
  requests:
    cpu: 10m
    memory: 64Mi

webhook:
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 10m
      memory: 64Mi

cainjector:
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 10m
      memory: 64Mi
```

---

### 4. Cloudflare Tunnel

**File: `infrastructure/network/cloudflared/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cloudflared

configMapGenerator:
- name: cloudflared-config
  namespace: cloudflared
  files:
  - config.yaml

resources:
  - namespace.yaml
  - tunnel-credentials-sealed.yaml
  - daemonset.yaml
```

**File: `infrastructure/network/cloudflared/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloudflared
```

**File: `infrastructure/network/cloudflared/config.yaml`**
```yaml
tunnel: b5f4258e-8cd9-4454-b46e-6f4f34219bb4
credentials-file: /etc/cloudflared/credentials/credentials.json
metrics: 0.0.0.0:2000
no-autoupdate: true

warp-routing:
  enabled: true

ingress:
  # Vegard Style: ALL traffic via Gateway (HTTPS)
  - hostname: "*.timourhomelab.org"
    service: https://envoy-gateway-envoy-gateway-ee418b6e.envoy-gateway-system.svc.cluster.local:443
    originRequest:
      originServerName: "*.timourhomelab.org"
      noTLSVerify: true

  - hostname: timourhomelab.org
    service: https://envoy-gateway-envoy-gateway-ee418b6e.envoy-gateway-system.svc.cluster.local:443
    originRequest:
      originServerName: timourhomelab.org
      noTLSVerify: true

  # Catch-all
  - service: http_status:404
```

**File: `infrastructure/network/cloudflared/tunnel-credentials-sealed.yaml`**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: tunnel-credentials
  namespace: cloudflared
spec:
  encryptedData:
    credentials.json: <SEALED_CREDENTIALS_HERE>
  template:
    metadata:
      name: tunnel-credentials
      namespace: cloudflared
```

**File: `infrastructure/network/cloudflared/daemonset.yaml`**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: cloudflared
  name: cloudflared
  namespace: cloudflared
spec:
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
        image: cloudflare/cloudflared:2024.10.0
        imagePullPolicy: IfNotPresent
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config/config.yaml
        - run
        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 60
          failureThreshold: 5
          periodSeconds: 10
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config/config.yaml
          subPath: config.yaml
        - name: credentials
          mountPath: /etc/cloudflared/credentials
          readOnly: true
      restartPolicy: Always
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: credentials
        secret:
          secretName: tunnel-credentials
```

---

### 5. ArgoCD Application

**File: `argocd/gateway-api-application.yaml`**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gateway-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: kubernetes/infrastructure/network/gateway
  destination:
    server: https://kubernetes.default.svc
    namespace: gateway
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

---

### Deployment Order

**Important: Follow this order for initial setup!**

```
1. Gateway API CRDs
   kubectl apply -k infrastructure/network/gateway/

2. cert-manager (needs CRDs first)
   kubectl apply -k infrastructure/cert-manager/

3. Envoy Gateway
   kubectl apply -k infrastructure/network/envoy-gateway/

4. Wait for GatewayClass
   kubectl wait --for=condition=Accepted gatewayclass/envoy-gateway --timeout=300s

5. Cloudflare Tunnel
   kubectl apply -k infrastructure/network/cloudflared/

6. Verify
   kubectl get gateway -n gateway
   kubectl get certificate -n gateway
   kubectl get pods -n cloudflared
```

---

### How to Generate Sealed Secrets

```bash
# 1. Create plain secret YAML (temporary)
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_TOKEN \
  --namespace=gateway \
  --dry-run=client -o yaml > /tmp/cloudflare-secret.yaml

# 2. Seal it
kubeseal --format=yaml \
  < /tmp/cloudflare-secret.yaml \
  > infrastructure/network/gateway/cloudflare-api-token-sealed.yaml

# 3. Delete temporary file
rm /tmp/cloudflare-secret.yaml

# 4. Commit sealed secret to Git
git add infrastructure/network/gateway/cloudflare-api-token-sealed.yaml
git commit -m "feat: add sealed Cloudflare API token"
```

---

### Verify Deployment

```bash
# Check all Gateway API resources
kubectl get gatewayclasses
kubectl get gateway -A
kubectl get httproutes -A

# Check cert-manager
kubectl get clusterissuer
kubectl get certificate -A
kubectl get certificaterequest -A

# Check Envoy Gateway
kubectl get pods -n envoy-gateway-system
kubectl get svc -n envoy-gateway-system

# Check Cloudflare Tunnel
kubectl get pods -n cloudflared
kubectl logs -n cloudflared -l app=cloudflared
```

---

## 📚 References

- [Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [cert-manager](https://cert-manager.io/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Vegard's Blog](https://blog.stonegarden.dev/articles/2024/02/bootstrapping-k3s-with-cilium/)
- [Kustomize](https://kustomize.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)

---

**🎉 Complete!** Production-ready Gateway API with GitOps.
