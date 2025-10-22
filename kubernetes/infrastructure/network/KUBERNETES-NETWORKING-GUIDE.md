# 🌐 Kubernetes Networking Complete Guide - CNI, Services, Ingress

## 📖 Was ist Kubernetes Networking?

**Kubernetes Networking** ist das System das ermöglicht dass **Pods miteinander kommunizieren**, **Services erreichbar** sind, und **externe Traffic** zu Pods routed wird.

### 🤔 Das Kubernetes Networking Problem

Kubernetes muss 4 grundlegende Networking Herausforderungen lösen:

```
┌────────────────────────────────────────────────────┐
│ 4 Kubernetes Networking Requirements              │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1️⃣ Pod-to-Pod Communication                       │
│    Pod A (10.244.1.5) → Pod B (10.244.2.10)       │
│    Requirement: Direct IP connectivity (no NAT!)  │
│                                                    │
│ 2️⃣ Pod-to-Service Communication                    │
│    Pod → Service (ClusterIP) → Backend Pods       │
│    Requirement: Load balancing, service discovery │
│                                                    │
│ 3️⃣ External-to-Service Communication               │
│    Internet → LoadBalancer/Ingress → Pods        │
│    Requirement: Public IP, TLS termination        │
│                                                    │
│ 4️⃣ Pod-to-External Communication                   │
│    Pod (10.244.1.5) → api.github.com              │
│    Requirement: NAT, egress routing               │
└────────────────────────────────────────────────────┘
```

**Kubernetes delegiert diese Aufgaben an:**
- **CNI Plugin** (Container Network Interface) → Löst 1️⃣ & 4️⃣
- **kube-proxy** (oder CNI) → Löst 2️⃣
- **Ingress Controller** / **LoadBalancer** → Löst 3️⃣

---

## 🏗️ Die 3 Networking Layer

### **Layer 1: CNI (Container Network Interface)**

**Was ist CNI?**

CNI ist ein **Plugin System** das Pod networking konfiguriert. Wenn Kubernetes einen Pod erstellt, ruft es das CNI Plugin mit `ADD <pod-name>`:

```
┌────────────────────────────────────────────────┐
│ CNI Plugin Execution Flow                     │
├────────────────────────────────────────────────┤
│                                                │
│ 1. kubelet creates Pod namespace              │
│    └─ Network namespace: /var/run/netns/pod1  │
│                                                │
│ 2. kubelet calls CNI plugin                   │
│    └─ Command: ADD pod1                       │
│                                                │
│ 3. CNI plugin creates veth pair               │
│    └─ eth0 (in Pod) ↔ vethXYZ (in host)      │
│                                                │
│ 4. CNI assigns IP address                     │
│    └─ IPAM: 10.244.1.5/24                     │
│                                                │
│ 5. CNI configures routing                     │
│    └─ Route: 10.244.0.0/16 → cilium_host      │
└────────────────────────────────────────────────┘
```

**CNI Plugin Options:**

| CNI Plugin | Type | Performance | Features |
|-----------|------|-------------|----------|
| **Cilium** | eBPF-based | ⭐⭐⭐⭐⭐ Best | L7 policies, WireGuard, kube-proxy replacement |
| **Calico** | iptables | ⭐⭐⭐ Good | BGP routing, Network Policies |
| **Flannel** | Overlay (VXLAN) | ⭐⭐ OK | Simple, easy setup |
| **Weave** | Overlay | ⭐⭐ OK | Mesh networking, encryption |

**Our Choice: Cilium**

Reasons:
- ✅ eBPF = Native kernel datapath (fastest)
- ✅ kube-proxy replacement (no extra process)
- ✅ L7 visibility (HTTP/DNS inspection)
- ✅ WireGuard encryption (Zero-Trust)
- ✅ Production-grade (Google GKE, AWS EKS)

---

### **Layer 2: Services & kube-proxy**

**Was ist ein Kubernetes Service?**

Ein **Service** ist eine **stabile IP + DNS Name** für eine Gruppe von Pods (die sich ändern können).

```
┌────────────────────────────────────────────────┐
│ Problem: Pods sind ephemeral                  │
├────────────────────────────────────────────────┤
│                                                │
│ Deployment: frontend (3 replicas)             │
│ ├─ Pod 1: 10.244.1.5  ← deleted! ❌           │
│ ├─ Pod 2: 10.244.2.8  ← running ✅            │
│ └─ Pod 3: 10.244.3.12 ← NEW pod! (new IP)     │
│                                                │
│ ❌ Hard-code IP 10.244.1.5? → Breaks!         │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ Solution: Service (stable IP)                 │
├────────────────────────────────────────────────┤
│                                                │
│ Service: frontend (ClusterIP: 10.96.123.45)   │
│ ├─ Backend Pod 1: 10.244.2.8  ✅              │
│ └─ Backend Pod 2: 10.244.3.12 ✅              │
│                                                │
│ ✅ Always use Service IP: 10.96.123.45        │
│ ✅ DNS: frontend.default.svc.cluster.local    │
└────────────────────────────────────────────────┘
```

**Service Types:**

```yaml
# 1. ClusterIP (default) - Internal only
apiVersion: v1
kind: Service
metadata:
  name: checkout
spec:
  type: ClusterIP  # Only accessible within cluster
  selector:
    app: checkout
  ports:
    - port: 5050
      targetPort: 5050

---

# 2. NodePort - Exposes on each Node's IP
apiVersion: v1
kind: Service
metadata:
  name: checkout
spec:
  type: NodePort
  selector:
    app: checkout
  ports:
    - port: 5050
      targetPort: 5050
      nodePort: 30050  # Access via <node-ip>:30050

---

# 3. LoadBalancer - Cloud LB or MetalLB/Cilium L2 announcements
apiVersion: v1
kind: Service
metadata:
  name: grafana
spec:
  type: LoadBalancer
  selector:
    app: grafana
  ports:
    - port: 80
      targetPort: 3000
  # Assigns external IP: 192.168.68.150 (from CiliumLoadBalancerIPPool)

---

# 4. ExternalName - DNS CNAME alias
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: mysql.rds.amazonaws.com  # Points to external service
```

---

### **kube-proxy vs Cilium eBPF**

**Traditional kube-proxy (iptables mode):**

```
Client Pod → Service IP (10.96.123.45:5050)
     │
     ▼
kube-proxy (watches Services, updates iptables)
     │
     ▼
iptables NAT rules:
├─ -A KUBE-SVC-XYZ -m statistic --mode random --probability 0.5 -j KUBE-SEP-1
├─ -A KUBE-SVC-XYZ -j KUBE-SEP-2
│
├─ KUBE-SEP-1: DNAT to 10.244.1.5:5050  ← Backend Pod 1
└─ KUBE-SEP-2: DNAT to 10.244.2.8:5050  ← Backend Pod 2
```

**Problems:**
- ❌ **O(n) iptables lookup** - 1000 Services = 10K+ rules
- ❌ **Extra process** - kube-proxy consumes CPU/RAM
- ❌ **No connection tracking** - Session affinity issues

**Cilium eBPF (kube-proxy replacement):**

```
Client Pod → Service IP (10.96.123.45:5050)
     │
     ▼
eBPF program (attached to veth interface)
     │
     ▼
eBPF map lookup (O(1)!):
├─ Key: 10.96.123.45:5050
└─ Value: [10.244.1.5:5050, 10.244.2.8:5050]  ← Backend Pods
     │
     ▼
Maglev Consistent Hashing → Select backend
     │
     ▼
Direct routing to 10.244.1.5:5050 (no NAT!)
```

**Benefits:**
- ✅ **O(1) lookup** - Constant time, regardless of # of Services
- ✅ **No kube-proxy** - One less process to manage
- ✅ **Connection tracking** - Session affinity via Maglev
- ✅ **Better performance** - 30% lower latency

**Our Setup:**

```yaml
# File: infrastructure/network/cilium/values.yaml
kubeProxyReplacement: true  # ✅ No kube-proxy!

loadBalancer:
  algorithm: maglev  # Consistent hashing for sticky sessions
```

---

### **Layer 3: Ingress & Gateway API**

**Was ist Ingress?**

**Ingress** ermöglicht **HTTP/HTTPS routing** von **außen** zu **internen Services**.

```
┌────────────────────────────────────────────────┐
│ Without Ingress (NodePort or LoadBalancer)    │
├────────────────────────────────────────────────┤
│                                                │
│ ❌ Problem: Need unique IP per Service!       │
│                                                │
│ Service 1: grafana       → 192.168.68.151:80  │
│ Service 2: hubble-ui     → 192.168.68.152:80  │
│ Service 3: argocd-server → 192.168.68.153:80  │
│                                                │
│ → Waste of IPs! (Limited pool: .150-.170)     │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ With Ingress (Shared LoadBalancer)            │
├────────────────────────────────────────────────┤
│                                                │
│ ✅ 1 Shared IP: 192.168.68.150                │
│                                                │
│ grafana.timourhomelab.org      → grafana:80   │
│ hubble.timourhomelab.org       → hubble-ui:80 │
│ argocd.timourhomelab.org       → argocd:443   │
│                                                │
│ → HTTP Host-based routing!                    │
└────────────────────────────────────────────────┘
```

**Ingress Example:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod  # Auto TLS cert
spec:
  ingressClassName: cilium  # Use Cilium Ingress Controller
  tls:
    - hosts:
        - grafana.timourhomelab.org
      secretName: grafana-tls  # cert-manager creates this Secret
  rules:
    - host: grafana.timourhomelab.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
```

**How Ingress Works:**

```
Internet
  │
  ▼
DNS: grafana.timourhomelab.org → 192.168.68.150
  │
  ▼
Cilium Ingress Controller (Envoy proxy)
  │
  ├─ TLS termination (cert-manager cert)
  ├─ HTTP Host header check: "grafana.timourhomelab.org"
  └─ Route to Service: grafana:80
       │
       ▼
  Service: grafana (ClusterIP: 10.96.50.10:80)
       │
       ▼
  Pod: grafana-abc123 (10.244.3.45:3000)
```

---

### **Gateway API (Modern Ingress)**

**Was ist Gateway API?**

Gateway API ist der **Nachfolger von Ingress** - mehr features, bessere multi-tenancy.

```yaml
# Gateway API Example
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-gateway
  namespace: istio-system
spec:
  gatewayClassName: cilium  # Cilium Gateway Controller
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-tls  # cert-manager Secret

---

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: istio-system
  hostnames:
    - grafana.timourhomelab.org
  rules:
    - backendRefs:
        - name: grafana
          port: 80
```

**Gateway API vs Ingress:**

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| **Multi-tenancy** | ❌ Single namespace | ✅ Cross-namespace refs |
| **Protocol support** | HTTP/HTTPS only | HTTP, HTTPS, TCP, UDP, gRPC |
| **Traffic splitting** | ❌ Limited | ✅ Weighted routing (Canary) |
| **Header matching** | ❌ No | ✅ Yes (advanced routing) |
| **Status reporting** | ❌ Basic | ✅ Rich status conditions |

**Our Setup:**

```yaml
# File: infrastructure/network/cilium/values.yaml
gatewayAPI:
  enabled: true
  enableAlpn: true  # HTTP/2 support
  enableAppProtocol: true  # GEP-1911 (protocol detection)
```

---

## 🔀 Traffic Flow Examples

### **Example 1: Pod-to-Pod (Same Node)**

```
Pod A (10.244.1.5) → Pod B (10.244.1.10)  [Same Node]

┌────────────────────────────────────────┐
│ Node: worker-1                         │
├────────────────────────────────────────┤
│                                        │
│  Pod A (eth0: 10.244.1.5)             │
│    │                                   │
│    ▼                                   │
│  vethABC (host side)                  │
│    │                                   │
│    ▼                                   │
│  eBPF program (cilium_from_container) │
│    │                                   │
│    │ Check: Destination 10.244.1.10   │
│    │ → Same node? YES!                │
│    │ → Direct forward (no routing)    │
│    │                                   │
│    ▼                                   │
│  vethXYZ (Pod B's veth)               │
│    │                                   │
│    ▼                                   │
│  Pod B (eth0: 10.244.1.10)            │
└────────────────────────────────────────┘

Performance: ~0.5 microseconds (eBPF redirect)
```

---

### **Example 2: Pod-to-Pod (Different Nodes)**

```
Pod A (10.244.1.5, Node: worker-1) → Pod B (10.244.2.10, Node: worker-2)

┌──────────────────────┐         ┌──────────────────────┐
│ Node: worker-1       │         │ Node: worker-2       │
├──────────────────────┤         ├──────────────────────┤
│                      │         │                      │
│ Pod A (10.244.1.5)  │         │ Pod B (10.244.2.10) │
│   │                  │         │   │                  │
│   ▼                  │         │   ▼                  │
│ vethABC              │         │ vethXYZ              │
│   │                  │         │   │                  │
│   ▼                  │         │   ▼                  │
│ eBPF program         │         │ eBPF program         │
│   │                  │         │   │                  │
│   │ Dest: 10.244.2.10│         │   │                  │
│   │ → Different node!│         │   │                  │
│   │                  │         │   │                  │
│   ▼                  │         │   ▼                  │
│ eth0 (Node IP)       │         │ eth0 (Node IP)       │
│   │                  │         │   │                  │
│   └──────────────────┼─────────┤   │                  │
│       WireGuard      │ Encrypted│   │                  │
│       Tunnel         │  Traffic │   │                  │
│                      │  ────────►   │                  │
└──────────────────────┘         └──────────────────────┘

Steps:
1. eBPF checks: Destination on different node
2. Encapsulation: WireGuard encryption (if enabled)
3. Route: Via native routing (no VXLAN!)
4. Destination node: eBPF decrypts, forwards to Pod B

Performance: ~1-2 microseconds + network latency
```

---

### **Example 3: Pod → Service → Backend Pods**

```
Frontend Pod (10.244.1.5) → checkout Service (10.96.123.45:5050)

┌────────────────────────────────────────────────┐
│ Step 1: Frontend Pod sends HTTP request       │
├────────────────────────────────────────────────┤
│ Source: 10.244.1.5:52341                      │
│ Dest:   10.96.123.45:5050  ← Service IP!      │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 2: eBPF program intercepts                │
├────────────────────────────────────────────────┤
│ eBPF map lookup:                               │
│ Key: 10.96.123.45:5050                        │
│ Value: [10.244.2.10:5050, 10.244.3.15:5050]   │
│         ↑ Backend Pod 1   ↑ Backend Pod 2     │
│                                                │
│ Maglev Hash: source IP + port → Backend 1     │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 3: Direct routing to Backend Pod         │
├────────────────────────────────────────────────┤
│ New Dest: 10.244.2.10:5050  ← Backend Pod     │
│ No DNAT! (Source IP preserved: 10.244.1.5)    │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 4: Backend Pod receives request          │
├────────────────────────────────────────────────┤
│ Backend sees: Source IP = 10.244.1.5          │
│ → Real client IP preserved! (No NAT!)         │
└────────────────────────────────────────────────┘
```

**Key Difference vs iptables:**

```
iptables (DNAT):
Frontend (10.244.1.5) → Service (10.96.123.45)
  → iptables DNAT → Backend sees Source: 10.96.123.45 ❌
  → Lost real client IP!

Cilium eBPF (Direct Server Return):
Frontend (10.244.1.5) → Service (10.96.123.45)
  → eBPF direct route → Backend sees Source: 10.244.1.5 ✅
  → Real client IP preserved!
```

---

### **Example 4: Internet → Ingress → Pod**

```
Internet → grafana.timourhomelab.org (192.168.68.150)

┌────────────────────────────────────────────────┐
│ Step 1: DNS Resolution                        │
├────────────────────────────────────────────────┤
│ dig grafana.timourhomelab.org                 │
│ → A record: 192.168.68.150                    │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 2: ARP/L2 Announcement                   │
├────────────────────────────────────────────────┤
│ Router sends ARP: Who has 192.168.68.150?     │
│ Cilium L2 Announcement replies:               │
│ → MAC address: aa:bb:cc:dd:ee:ff (worker-1)   │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 3: Traffic arrives at worker-1           │
├────────────────────────────────────────────────┤
│ Cilium Ingress Controller (Envoy)             │
│ ├─ TLS Termination (cert-manager cert)        │
│ ├─ HTTP Host header: grafana.timourhomelab.org│
│ └─ Matches Ingress rule → Route to grafana:80 │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ Step 4: Service → Pod routing                 │
├────────────────────────────────────────────────┤
│ Service: grafana (ClusterIP: 10.96.50.10:80)  │
│ eBPF map lookup → Backend Pod: 10.244.3.45    │
│ Direct route to Pod                            │
└────────────────────────────────────────────────┘
```

---

## 📊 IP Address Ranges (Our Cluster)

### **Pod CIDR: 10.244.0.0/16**

```
Total IPs: 65,536 (2^16)
Per-Node allocation: /24 (256 IPs per Node)

Node allocations:
├─ ctrl-0:   10.244.0.0/24   (256 IPs)
├─ worker-1: 10.244.1.0/24   (256 IPs)
├─ worker-2: 10.244.2.0/24   (256 IPs)
├─ worker-3: 10.244.3.0/24   (256 IPs)
├─ worker-4: 10.244.4.0/24   (256 IPs)
├─ worker-5: 10.244.5.0/24   (256 IPs)
└─ worker-6: 10.244.6.0/24   (256 IPs)

Max Pods per Node: 254 (1 IP reserved for gateway)
Total Cluster Capacity: 7 nodes × 254 pods = 1,778 pods
```

**IPAM Mode**: `kubernetes` (uses Node `spec.podCIDR`)

```yaml
# File: infrastructure/network/cilium/values.yaml
ipam:
  mode: kubernetes  # Read podCIDR from Node spec
```

---

### **Service CIDR: 10.96.0.0/12**

```
Total IPs: 1,048,576 (2^20)
Range: 10.96.0.0 - 10.111.255.255

Reserved IPs:
├─ 10.96.0.1       → Kubernetes API Server (default)
├─ 10.96.0.10      → CoreDNS Service
└─ 10.96.123.45    → Example: checkout Service

Max Services: ~1 million (more than enough!)
```

**Service IP allocation**: Managed by Kubernetes API Server (not CNI)

---

### **LoadBalancer IP Pool: 192.168.68.150-170**

```
CiliumLoadBalancerIPPool (L2 Announcements)

Available IPs: 21 (192.168.68.150 - .170)
Used: ~8
Free: ~13

Allocated IPs:
├─ 192.168.68.150 → Cilium Ingress (shared for all Ingresses)
├─ 192.168.68.151 → Grafana LoadBalancer
├─ 192.168.68.152 → Hubble UI LoadBalancer
└─ 192.168.68.153 → ArgoCD Server LoadBalancer
```

**File**: `infrastructure/network/cilium/ip-pool.yaml`

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: ip-pool
  namespace: kube-system
spec:
  blocks:
    - start: 192.168.68.150
      stop: 192.168.68.170
```

**L2 Announcements** (ARP/NDP):

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default-l2-announcement-policy
  namespace: kube-system
spec:
  externalIPs: true
  loadBalancerIPs: true
```

**How it works:**

```
1. Service type=LoadBalancer created
2. Cilium allocates IP from pool: 192.168.68.151
3. Cilium sends ARP announcement: "I have 192.168.68.151!"
4. Router updates ARP table: 192.168.68.151 → worker-1 MAC
5. Traffic to .151 arrives at worker-1
6. Cilium routes to Service backend Pods
```

---

## 🔒 Network Policies

### **What are Network Policies?**

**Network Policies** sind **Firewall rules** für Pods - ermöglichen **Zero-Trust Networking**.

```
┌────────────────────────────────────────────────┐
│ Without Network Policies (Default: Allow All) │
├────────────────────────────────────────────────┤
│                                                │
│ ❌ Frontend can access Database directly!     │
│ ❌ Any Pod can access any other Pod!          │
│ ❌ No isolation between namespaces!           │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ With Network Policies (Zero-Trust)            │
├────────────────────────────────────────────────┤
│                                                │
│ ✅ Frontend → Checkout (allowed)              │
│ ✅ Checkout → Database (allowed)              │
│ ❌ Frontend → Database (denied!)              │
│ ✅ Explicit allow-list model                  │
└────────────────────────────────────────────────┘
```

**Example Network Policy (L3/L4):**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: boutique-dev
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system  # Allow Istio Gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: checkout  # Frontend can call checkout
      ports:
        - protocol: TCP
          port: 5050
    - to:  # Allow DNS
        - namespaceSelector:
            matchLabels:
              name: kube-system
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

---

### **Cilium L7 Network Policies**

**Cilium extends Kubernetes Network Policies** mit **L7 (HTTP/DNS) filtering**:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-l7-policy
  namespace: boutique-dev
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            app: checkout
      toPorts:
        - ports:
            - port: "5050"
              protocol: TCP
          rules:
            http:
              - method: "GET"    # ✅ Allow GET /cart
                path: "/cart"
              - method: "POST"   # ✅ Allow POST /checkout
                path: "/checkout"
      # ❌ Block: POST /admin (not in allow-list)
```

**L7 Policy Enforcement Flow:**

```
Frontend Pod → checkout:5050 (HTTP POST /checkout)
      │
      ▼
eBPF checks: Is L7 policy attached? YES!
      │
      ▼
eBPF redirects to Envoy proxy (L7 inspection)
      │
      ▼
Envoy parses HTTP:
├─ Method: POST
├─ Path: /checkout
└─ Matches L7 rule? YES! → ALLOW
      │
      ▼
Forward to Backend Pod: checkout (10.244.2.10:5050)
```

**FQDN-based Policy (DNS):**

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-github-api
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
    - toFQDNs:
        - matchName: "api.github.com"  # Only GitHub API allowed
    - toFQDNs:
        - matchPattern: "*.google.com"  # Wildcard support
```

**How FQDN policies work:**

```
1. Frontend Pod: DNS query for api.github.com
2. Cilium DNS Proxy intercepts query
3. Cilium resolves: api.github.com → 140.82.121.6
4. Cilium adds temporary Network Policy:
   - Allow egress to 140.82.121.6:443 (TTL-based)
5. Frontend Pod connects to 140.82.121.6:443 ✅
6. After DNS TTL expires, rule is removed
```

---

## 🔍 DNS in Kubernetes

### **CoreDNS (Cluster DNS)**

**CoreDNS** ist der **DNS Server** für Kubernetes - löst Service Namen zu ClusterIPs auf.

```
┌────────────────────────────────────────────────┐
│ DNS Resolution Flow                           │
├────────────────────────────────────────────────┤
│                                                │
│ Pod (10.244.1.5)                              │
│   │                                            │
│   │ DNS query: checkout.default.svc.cluster.local│
│   │                                            │
│   ▼                                            │
│ /etc/resolv.conf:                             │
│   nameserver 10.96.0.10  ← CoreDNS Service IP │
│   search default.svc.cluster.local            │
│   │                                            │
│   ▼                                            │
│ CoreDNS Pod (10.244.0.15)                     │
│   │                                            │
│   │ Lookup: checkout.default.svc.cluster.local│
│   │ → ClusterIP: 10.96.123.45                 │
│   │                                            │
│   ▼                                            │
│ Response: 10.96.123.45                        │
└────────────────────────────────────────────────┘
```

**DNS Naming Convention:**

```
<service-name>.<namespace>.svc.cluster.local

Examples:
├─ checkout.default.svc.cluster.local       → 10.96.123.45
├─ grafana.monitoring.svc.cluster.local     → 10.96.50.10
└─ kube-dns.kube-system.svc.cluster.local   → 10.96.0.10

Shortcuts (from same namespace):
├─ checkout                 → Works! (same namespace)
├─ checkout.default         → Works! (explicit namespace)
└─ checkout.default.svc     → Works! (full without .cluster.local)
```

**Headless Services (StatefulSet DNS):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
spec:
  clusterIP: None  # Headless Service!
  selector:
    app: elasticsearch
  ports:
    - port: 9200

---

# DNS records for individual Pods:
elasticsearch-0.elasticsearch.observability.svc.cluster.local → 10.244.2.15
elasticsearch-1.elasticsearch.observability.svc.cluster.local → 10.244.3.20
elasticsearch-2.elasticsearch.observability.svc.cluster.local → 10.244.4.25
```

---

## 🛠️ Troubleshooting Common Issues

### **1. Pod Cannot Resolve Service DNS**

**Symptom:**

```bash
kubectl exec -it frontend-abc123 -- curl http://checkout:5050
# Error: Could not resolve host: checkout
```

**Diagnose:**

```bash
# 1. Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check Pod's /etc/resolv.conf
kubectl exec -it frontend-abc123 -- cat /etc/resolv.conf
# Expected:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local

# 3. Test DNS query
kubectl exec -it frontend-abc123 -- nslookup checkout
# Expected: Should return 10.96.123.45

# 4. Check Service exists
kubectl get svc checkout
```

**Common Causes:**

```
❌ CoreDNS Pods not running
   → Check: kubectl get pods -n kube-system -l k8s-app=kube-dns
   → Solution: Restart CoreDNS deployment

❌ NetworkPolicy blocking DNS (port 53/UDP)
   → Check: NetworkPolicy has egress rule for kube-dns
   → Solution: Add DNS egress rule

❌ Wrong Service name or namespace
   → Use: <service>.<namespace>.svc.cluster.local
```

---

### **2. Service IP Not Responding**

**Symptom:**

```bash
kubectl exec -it frontend-abc123 -- curl http://10.96.123.45:5050
# Error: Connection timeout
```

**Diagnose:**

```bash
# 1. Check Service has Endpoints
kubectl get endpoints checkout
# Expected: Should show backend Pod IPs (10.244.x.y:5050)

# 2. Check backend Pods are running
kubectl get pods -l app=checkout

# 3. Check Cilium service mapping
kubectl exec -n kube-system ds/cilium -- cilium service list | grep 10.96.123.45

# 4. Test direct Pod IP connectivity
kubectl exec -it frontend-abc123 -- curl http://10.244.2.10:5050
```

**Common Causes:**

```
❌ No backend Pods running
   → Check: kubectl get pods -l app=checkout
   → Solution: Scale deployment or fix CrashLoopBackOff

❌ Service selector doesn't match Pod labels
   → Check: kubectl get svc checkout -o yaml
   → Solution: Fix selector to match Pod labels

❌ eBPF service map not updated
   → Check: cilium service list
   → Solution: Restart Cilium agent
```

---

### **3. Ingress Not Reachable from Internet**

**Symptom:**

```bash
curl https://grafana.timourhomelab.org
# Error: Connection timeout
```

**Diagnose:**

```bash
# 1. Check Ingress has IP assigned
kubectl get ingress -n monitoring grafana
# Expected: ADDRESS should show 192.168.68.150

# 2. Check LoadBalancer IP is allocated
kubectl get svc -n kube-system cilium-ingress
# Expected: EXTERNAL-IP should show 192.168.68.150

# 3. Check L2 announcements are working
kubectl get ciliuml2announcementpolicy
# Expected: default-l2-announcement-policy should exist

# 4. Test from external machine (not in cluster)
ping 192.168.68.150
# Expected: Should respond

# 5. Check DNS resolution
dig grafana.timourhomelab.org
# Expected: Should return 192.168.68.150
```

**Common Causes:**

```
❌ LoadBalancer IP pool exhausted
   → Check: CiliumLoadBalancerIPPool has free IPs
   → Solution: Expand IP pool range

❌ L2 announcements not working
   → Check: ARP table on router
   → Solution: Verify CiliumL2AnnouncementPolicy

❌ Firewall blocking port 80/443
   → Check: Node firewall rules
   → Solution: Allow ingress on ports 80/443

❌ DNS not pointing to correct IP
   → Check: dig <hostname>
   → Solution: Update DNS A record
```

---

## 📋 Best Practices Checklist

### ✅ **CNI (Cilium)**

- [x] eBPF-based CNI (Cilium) deployed
- [x] kube-proxy replacement enabled
- [x] Native routing mode (no VXLAN overhead)
- [x] WireGuard encryption enabled (Zero-Trust)
- [x] BPF map sizing configured for scale (10K+ pods)
- [x] Bandwidth Manager enabled (EDT + Fair Queue)
- [x] L7 visibility policy applied (HTTP/DNS inspection)

---

### ✅ **Services & Load Balancing**

- [x] ClusterIP for internal services
- [x] LoadBalancer for external services (Cilium L2 announcements)
- [x] Maglev consistent hashing (sticky sessions)
- [x] Service mesh ready (Istio integration)
- [x] IP pool allocated (192.168.68.150-170)

---

### ✅ **Ingress & Gateway API**

- [x] Cilium Ingress Controller enabled
- [x] Shared LoadBalancer mode (1 IP for multiple Ingresses)
- [x] cert-manager integration (automatic TLS certs)
- [x] Gateway API support enabled (modern ingress)
- [x] L7 HTTP routing configured

---

### ✅ **DNS**

- [x] CoreDNS deployed (kube-system namespace)
- [x] DNS caching enabled (reduced external queries)
- [x] Cilium DNS proxy enabled (FQDN policies)
- [x] DNS metrics exported to Prometheus

---

### ✅ **Network Policies**

- [x] L7 visibility policy (global HTTP/DNS inspection)
- [x] Namespace isolation policies (future: per-app policies)
- [x] FQDN-based egress policies (DNS-based filtering)
- [x] Zero-Trust model (explicit allow-list)

---

## 📚 References

### **Official Documentation**

- Kubernetes Networking: https://kubernetes.io/docs/concepts/cluster-administration/networking/
- CNI Specification: https://github.com/containernetworking/cni
- Cilium Docs: https://docs.cilium.io/
- Gateway API: https://gateway-api.sigs.k8s.io/

### **Homelab Configs**

- **Cilium values.yaml**: `infrastructure/network/cilium/values.yaml`
- **IP Pool**: `infrastructure/network/cilium/ip-pool.yaml`
- **L2 Announcements**: `infrastructure/network/cilium/announce.yaml`
- **L7 Visibility**: `infrastructure/network/cilium/l7-visibility-policy.yaml`

---

**Status**: **100% Production Ready** ✅

**Architecture**: Cilium eBPF CNI + kube-proxy replacement + WireGuard encryption + L7 policies

**Result**: Enterprise-grade Kubernetes networking with best-in-class performance and security.
