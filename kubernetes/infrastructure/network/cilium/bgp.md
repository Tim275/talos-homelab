# BGP Migration Guide - Cilium L2 to BGP

This document explains the migration from **L2 Announcements (ARP)** to **BGP peering** for LoadBalancer IP advertisement.

---

## 🔴 Current Setup - L2 Announcements (ARP)

**Architecture:**
```
LoadBalancer Service → Cilium L2 Announcements → ARP Broadcast → UniFi Router learns MAC
```

**Current Files:**
- `announce.yaml` - CiliumL2AnnouncementPolicy (enables ARP announcements)
- `ip-pool.yaml` - CiliumLoadBalancerIPPool (192.168.68.150-170)
- `values.yaml` - `l2announcements.enabled: true`

**How it works:**
- Cilium announces LoadBalancer IPs via **Layer 2 ARP** protocol
- UniFi router learns: "IP 192.168.68.150 is at MAC address XY"
- Similar to MetalLB L2 mode

**Limitations:**
-  No true load balancing (only failover to single node)
-  Client source IP lost (SNAT applied)
-  Single point of failure per service
-  ARP broadcast traffic in network
-  Not scalable for multi-cluster setups

---

## 🟢 Target Setup - BGP Peering

**Architecture:**
```
LoadBalancer Service → Cilium BGP → eBGP Peering → UniFi Router learns Routes → ECMP Load Balancing
```

**New Files Required:**
- `bgp-cluster-config.yaml` - BGP configuration (ASN, Router ID)
- `bgp-peer-config.yaml` - UniFi router as BGP neighbor
- `bgp-advertisement.yaml` - What to advertise (Service, Pod IPs)
- `bgp-password-secret.yaml` - Optional BGP authentication
- `ip-pool.yaml` - **KEEP** (existing IP pool, no changes)
- `values.yaml` - **UPDATE** (`bgp.enabled: true`)

**How it works:**
- Cilium speaks **BGP protocol** with UniFi router (eBGP peering)
- UniFi router learns routes: "192.168.68.150 reachable via Node1, Node2, Node3"
- Router uses **ECMP** (Equal-Cost Multi-Path) for true load balancing
- Traffic distributed across all 3 nodes

**Advantages:**
-  True load balancing via ECMP (3 nodes)
-  Client source IP preserved (`externalTrafficPolicy: Local`)
-  No single point of failure
-  Reduced broadcast traffic
-  Industry standard (AWS, GCP, Azure use BGP)
-  Multi-cluster ready
-  Enterprise skill building

---

##  Practical Explanation - What Actually Happens?

### 🔴 AKTUELL (L2 ARP) - Current Behavior

**Example:** You access `https://n8n.timourhomelab.org`

```
1. Browser asks: "Where is 192.168.68.150?"

2. Cilium responds via ARP:
   "192.168.68.150 is at MAC address aa:bb:cc (Node 1)"

3. UniFi Router remembers:
   192.168.68.150 → MAC aa:bb:cc → Node 1 ONLY

4. ALL requests go to Node 1
   ┌─────────┐
   │ Client  │──────┐
   └─────────┘      │
                    ▼
   ┌──────────────────────┐
   │ UniFi Router         │
   └──────────┬───────────┘
              │
              ▼ 100% Traffic
   ┌──────────────────┐
   │ Node 1 (overloaded) │  ← ALL requests here!
   └──────────────────┘

   ┌──────────────────┐
   │ Node 2 (idle)    │  ← Does nothing!
   └──────────────────┘

   ┌──────────────────┐
   │ Node 3 (idle)    │  ← Does nothing!
   └──────────────────┘
```

**Problems:**
-  Node 1 does EVERYTHING (overloaded)
-  Node 2 + 3 do NOTHING (wasted resources)
-  If Node 1 crashes → Service down (~5-10 seconds until Cilium failover to Node 2)
-  Client IP is replaced by NAT → Logs show only Node IP

---

### 🟢 NEU (BGP) - New Behavior

**Example:** You access `https://n8n.timourhomelab.org`

```
1. Browser asks: "Where is 192.168.68.150?"

2. Cilium speaks BGP with UniFi:
   Node 1: "192.168.68.150 reachable via ME"
   Node 2: "192.168.68.150 reachable via ME"
   Node 3: "192.168.68.150 reachable via ME"

3. UniFi Router learns 3 equal-cost routes:
   192.168.68.150 → via Node 1 (33%)
   192.168.68.150 → via Node 2 (33%)
   192.168.68.150 → via Node 3 (33%)

4. Traffic is DISTRIBUTED (ECMP Load Balancing)
   ┌─────────┐
   │ Client  │──────┬──────┬──────┐
   └─────────┘      │      │      │
                    ▼      ▼      ▼
   ┌──────────────────────────────┐
   │ UniFi Router (ECMP)          │
   └──┬───────────┬───────────┬───┘
      │ 33%       │ 33%       │ 33%
      ▼           ▼           ▼
   ┌────────┐ ┌────────┐ ┌────────┐
   │ Node 1 │ │ Node 2 │ │ Node 3 │  ← ALL working!
   └────────┘ └────────┘ └────────┘
```

**Advantages:**
-  Traffic evenly distributed (33% / 33% / 33%)
-  All nodes working → Better performance
-  If Node 1 crashes → Router immediately uses Node 2+3 (0 downtime)
-  Client IP preserved → You see real IPs in logs

---

##  Concrete Examples - What You'll Notice

### **Example 1: Heavy Load (many requests)**

**L2 ARP (OLD):**
```
10 clients access N8N
→ ALL 10 requests go to Node 1
→ Node 1: 100% CPU
→ Node 2: 0% CPU (idle)
→ Node 3: 0% CPU (idle)
→ Response Time: 500ms (Node 1 overloaded)
```

**BGP (NEW):**
```
10 clients access N8N
→ 3-4 requests to Node 1 (33%)
→ 3-4 requests to Node 2 (33%)
→ 3-4 requests to Node 3 (33%)
→ All nodes: 33% CPU (evenly distributed)
→ Response Time: 100ms (load distributed)
```

---

### **Example 2: Node Failure**

**L2 ARP (OLD):**
```
Node 1 crashes (running N8N service)
→ 5-10 seconds downtime (Cilium failover)
→ Cilium announces new ARP for Node 2
→ Service back online
```

**BGP (NEW):**
```
Node 1 crashes
→ BGP session to Node 1 breaks
→ UniFi Router IMMEDIATELY uses Node 2+3
→ 0 seconds downtime
→ Load now: 50% Node 2, 50% Node 3
```

---

### **Example 3: Client IP Logging**

**L2 ARP (OLD):**
```
Your laptop: 192.168.68.50
→ Request to N8N
→ N8N sees in logs: 192.168.68.10 (Node IP!)
→ You CANNOT see which client it was
```

**BGP (NEW):**
```
Your laptop: 192.168.68.50
→ Request to N8N
→ N8N sees in logs: 192.168.68.50 (real client IP!)
→ You see EXACTLY which client it was
```

---

##  Performance Comparison (Real World)

| Scenario | L2 ARP | BGP |
|----------|--------|-----|
| **100 Requests/sec** | Node 1: 100 req/s<br>Node 2: 0<br>Node 3: 0 | Node 1: 33 req/s<br>Node 2: 33 req/s<br>Node 3: 33 req/s |
| **Node 1 crashes** | 5-10s Downtime | 0s Downtime |
| **CPU Load** | Node 1: 80%<br>Node 2: 5%<br>Node 3: 5% | Node 1: 30%<br>Node 2: 30%<br>Node 3: 30% |
| **Client IP visible?** |  No (NAT) |  Yes |

---

##  Why This Matters for Your Homelab

**1. Better Resource Utilization:**
- You have 3 nodes with 16 cores each
- L2: Only 1 node working (32 cores idle = wasted)
- BGP: All 3 nodes working (all 48 cores utilized)

**2. Higher Availability:**
- L2: Node crash = service interruption
- BGP: Node crash = no interruption

**3. Better Logs for Security/Debugging:**
- L2: You only see node IPs (useless)
- BGP: You see real client IPs (important for security)

**4. Enterprise Skills:**
- L2: Homelab solution (not in production)
- BGP: Real cloud practice (AWS, GCP, Azure use BGP)

---

##  Safe Migration - Zero Downtime Strategy

### **CRITICAL: Will Cilium Crash During Migration?**

**Answer:** No, Cilium itself will NOT crash - but your **services could become unreachable** if you migrate incorrectly!

---

### ** DANGER - What Can Go Wrong?**

**Risky Migration Approach:**

```
Step 1: Disable L2 in values.yaml
   l2announcements:
     enabled: false  

Step 2: Enable BGP
   bgp:
     enabled: true

Step 3: ArgoCD sync

 PROBLEM: If BGP doesn't work → ALL Services DOWN!
 Router has no routes → Services unreachable
 Downtime until you re-enable L2
```

---

### ** SAFE Migration - Parallel Operation (Zero Downtime)**

The key is to run **L2 and BGP in parallel** during testing, then cut over once BGP is proven.

---

#### **Phase 1: Parallel Operation (L2 + BGP simultaneously)**

**Step 1 - Add BGP WITHOUT disabling L2:**

```yaml
# kubernetes/infrastructure/network/cilium/values.yaml

#  L2 STAYS ACTIVE
l2announcements:
  enabled: true  # ← DO NOT disable!

#  BGP ENABLED IN PARALLEL
bgp:
  enabled: true
  announce:
    loadbalancerIP: true
```

**Step 2 - Deploy BGP CRDs:**

```yaml
# kubernetes/infrastructure/network/cilium/kustomization.yaml
resources:
  #  L2 STAYS ACTIVE
  - announce.yaml
  - ip-pool.yaml

  #  BGP ENABLED IN PARALLEL
  - bgp-cluster-config.yaml
  - bgp-peer-config.yaml
  - bgp-advertisement.yaml
  - bgp-password-secret.yaml
```

**Result:**
-  L2 announcements continue working (existing services OK)
-  BGP peering is established (new capability)
-  **Both systems run in parallel** → Zero Risk

---

#### **Phase 2: Test BGP with New Service**

Create a test service to verify BGP works:

```yaml
# test-bgp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami-bgp-test
  namespace: default
  labels:
    bgp.cilium.io/ip-pool: default              # ← BGP IP Pool
    bgp.cilium.io/advertise-service: default    # ← BGP Advertisement
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local  # ← Client IP preservation
  selector:
    app: whoami
  ports:
  - port: 80
```

**Verify BGP Works:**

```bash
# 1. Check BGP peering
kubectl exec -n kube-system ds/cilium -- cilium bgp peers
# Expected: Session State = established

# 2. Check BGP routes
kubectl exec -n kube-system ds/cilium -- cilium bgp routes advertised ipv4 unicast
# Expected: Service IP advertised from all 3 nodes

# 3. Test service reachable
curl http://172.20.10.X  # BGP IP
# Expected: HTTP 200, RemoteAddr shows real client IP
```

**If this works:**
-  BGP works correctly
-  ECMP Load Balancing active
-  Client IP preservation working

---

#### **Phase 3: Disable L2 (only after successful tests)**

**ONLY when BGP is 100% working:**

```yaml
# kubernetes/infrastructure/network/cilium/values.yaml
l2announcements:
  enabled: false  #  NOW safe to disable

bgp:
  enabled: true
```

```yaml
# kubernetes/infrastructure/network/cilium/kustomization.yaml
resources:
  #  L2 disabled
  # - announce.yaml

  #  BGP stays active
  - bgp-cluster-config.yaml
  - bgp-peer-config.yaml
  - bgp-advertisement.yaml
  - bgp-password-secret.yaml
  - ip-pool.yaml  # ← STAYS (reused by BGP)
```

---

### ** Rollback Plan - If BGP Fails**

**Immediately revert to L2:**

```yaml
# values.yaml
l2announcements:
  enabled: true  #  RE-ENABLE

bgp:
  enabled: false  #  DISABLE
```

```yaml
# kustomization.yaml
resources:
  - announce.yaml  #  RE-ENABLE
  # - bgp-*.yaml   #  COMMENT OUT
```

```bash
# ArgoCD sync
argocd app sync infrastructure-cilium

# Services reachable again within 10-20 seconds
```

---

### ** Migration Timeline - Zero Downtime**

```
Day 1 - Preparation
├─ BGP YAML files created 
├─ UniFi Router BGP configured
└─ L2 announcements: ACTIVE

Day 2 - Parallel Operation
├─ BGP enabled (values.yaml: bgp.enabled: true)
├─ L2 announcements: STILL ACTIVE
├─ BGP peering: established
└─ Test Service deployed

Day 3 - Verification
├─ BGP routes advertised 
├─ ECMP Load Balancing working 
├─ Client IP preservation 
└─ All tests passed

Day 4 - Cutover
├─ L2 announcements disabled
├─ BGP takes over completely
└─ Monitoring: All OK 
```

---

### ** Important Points**

**1. Cilium Will NOT Crash:**
- BGP is just a configuration change
- Cilium pods stay running
- CNI continues to function

**2. Services Could Become Unreachable If:**
-  You disable L2 BEFORE BGP works
-  UniFi Router BGP is misconfigured
-  ASN numbers don't match
-  IP addresses are wrong

**3. Safe Migration Means:**
-  Run L2 + BGP in parallel
-  Verify BGP with test service
-  Only then disable L2

---

### ** Migration Checklist**

```
□ BGP YAML files created (bgp-*.yaml)
□ UniFi Router BGP configured (ASN 65001, Peers at 192.168.68.10-12)
□ Cilium values.yaml: bgp.enabled: true (L2 STAYS enabled: true)
□ kustomization.yaml: BGP files uncommented (announce.yaml STAYS)
□ ArgoCD sync infrastructure-cilium
□ Verify: cilium bgp peers → Session State = established
□ Test Service deployed (whoami-bgp-test)
□ Verify: Service reachable via BGP IP
□ Verify: Client IP preservation works
□ 24h Monitoring: No issues
□ Disable L2 (values.yaml: l2announcements.enabled: false)
□ Comment out announce.yaml in kustomization.yaml
□ ArgoCD sync
□ Final Verify: All services still reachable
```

---

### **TL;DR**

Cilium won't crash, but you MUST run **L2 and BGP in parallel** while testing. Only disable L2 when BGP is 100% proven. Otherwise all services go down! 

---

##  Migration Strategy

### Phase 1: Preparation (5 minutes)

1. **Check UniFi router capabilities:**
   - UniFi Dream Machine Pro/SE supports BGP
   - UniFi Dream Router does NOT support BGP (requires UDM-Pro)
   - Check: Console Settings → Gateway → Advanced → BGP

2. **Choose ASN numbers:**
   - Cilium Cluster: **ASN 65000** (private ASN range 64512-65534)
   - UniFi Router: **ASN 65001** (different ASN for eBGP)

3. **Plan IP addressing:**
   - LoadBalancer Pool: **192.168.68.150-170** (existing, no change)
   - BGP Peer IP: **192.168.68.1** (UniFi router)
   - Node IPs: **192.168.68.x** (existing Talos nodes)

### Phase 2: BGP Configuration (20 minutes)

1. **Create BGP YAML files:**
   ```bash
   # Already created in this directory:
   # - bgp-cluster-config.yaml
   # - bgp-peer-config.yaml
   # - bgp-advertisement.yaml
   # - bgp-password-secret.yaml (optional)
   ```

2. **Enable in kustomization.yaml:**
   ```yaml
   resources:
     #  DISABLE L2:
     # - announce.yaml

     #  ENABLE BGP:
     - bgp-cluster-config.yaml
     - bgp-peer-config.yaml
     - bgp-advertisement.yaml
     - bgp-password-secret.yaml  # Optional
     - ip-pool.yaml  # Keep existing
   ```

3. **Update values.yaml:**
   ```yaml
   #  DISABLE L2:
   l2announcements:
     enabled: false

   #  ENABLE BGP:
   bgp:
     enabled: true
     announce:
       loadbalancerIP: true
       podCIDR: false  # Only announce LoadBalancer IPs
   ```

### Phase 3: UniFi Router BGP Setup (10 minutes)

**UniFi Console → Settings → Gateway → Advanced → BGP:**

1. **Enable BGP:** ON
2. **Local ASN:** 65001
3. **Router ID:** 192.168.68.1

4. **Add BGP Neighbor (repeat for each Talos node):**
   - **Neighbor IP:** 192.168.68.10 (node1)
   - **Remote ASN:** 65000
   - **Password:** (optional, matches `bgp-password-secret.yaml`)
   - **Enable:** ON

5. **Add BGP Neighbor:** 192.168.68.11 (node2)
6. **Add BGP Neighbor:** 192.168.68.12 (node3)

### Phase 4: Deploy & Verify (10 minutes)

1. **Deploy BGP configuration:**
   ```bash
   # ArgoCD will auto-sync, or manually:
   kubectl apply -k kubernetes/infrastructure/network/cilium/
   ```

2. **Verify BGP peering:**
   ```bash
   # Check Cilium BGP status:
   kubectl exec -n kube-system ds/cilium -- cilium bgp peers

   # Expected output:
   # Node       Local AS  Peer AS  Peer Address     Session State
   # node1      65000     65001    192.168.68.1     established
   # node2      65000     65001    192.168.68.1     established
   # node3      65000     65001    192.168.68.1     established
   ```

3. **Verify routes on UniFi:**
   ```bash
   # SSH to UniFi router:
   show ip bgp summary

   # Should show 3 established sessions (one per node)
   # Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
   # 192.168.68.10   4 65000      10      12        0    0    0 00:05:00        5
   # 192.168.68.11   4 65000       8      10        0    0    0 00:05:00        5
   # 192.168.68.12   4 65000       7       9        0    0    0 00:05:00        5
   ```

4. **Test LoadBalancer service:**
   ```bash
   # Create test service:
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --type=LoadBalancer --port=80

   # Check external IP:
   kubectl get svc nginx
   # NAME    TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)        AGE
   # nginx   LoadBalancer   10.96.100.200   192.168.68.150   80:32000/TCP   1m

   # Test from external client:
   curl http://192.168.68.150
   # Should see nginx welcome page
   ```

5. **Verify ECMP load balancing:**
   ```bash
   # On UniFi router:
   show ip route 192.168.68.150

   # Should show 3 next-hops (ECMP):
   # S>  192.168.68.150/32 [20/0] via 192.168.68.10, eth0, 00:05:00
   #                              via 192.168.68.11, eth0, 00:05:00
   #                              via 192.168.68.12, eth0, 00:05:00
   ```

### Phase 5: Rollback Plan (if needed)

If BGP doesn't work, rollback to L2:

1. **Disable BGP in kustomization.yaml:**
   ```yaml
   resources:
     - announce.yaml  #  RE-ENABLE
     # - bgp-*.yaml   #  DISABLE
   ```

2. **Re-enable L2 in values.yaml:**
   ```yaml
   l2announcements:
     enabled: true  #  RE-ENABLE
   bgp:
     enabled: false  #  DISABLE
   ```

3. **Disable BGP on UniFi:**
   - Console → Settings → Gateway → Advanced → BGP → OFF

4. **ArgoCD sync:**
   ```bash
   argocd app sync infrastructure-cilium
   ```

---

##  Comparison: L2 vs BGP

| Feature | L2 Announcements | BGP Peering |
|---------|-----------------|-------------|
| **Protocol** | ARP (Layer 2) | BGP (Layer 3) |
| **Load Balancing** | No (failover only) | Yes (ECMP) |
| **Client Source IP** | Lost (SNAT) | Preserved |
| **Failure Mode** | Single node down = outage | Automatic failover |
| **Router Config** | None | BGP peers required |
| **YAML Files** | 2-3 files | 5-6 files |
| **Setup Time** | 10 minutes | 30-45 minutes |
| **Scalability** | Single cluster only | Multi-cluster ready |
| **Industry Standard** | No | Yes (AWS, GCP, Azure) |
| **Broadcast Traffic** | High (ARP) | Low (BGP updates) |

---

## 🎤 Interview Talking Points

**"Why did you migrate from L2 to BGP?"**

> "I migrated from Cilium L2 Announcements to BGP peering for several reasons:
>
> 1. **True Load Balancing:** L2 only provides failover to a single node. BGP enables ECMP load balancing across all 3 nodes, distributing traffic evenly.
>
> 2. **Client Source IP Preservation:** With L2, the client IP gets SNAT'd and lost. BGP with `externalTrafficPolicy: Local` preserves the real client IP for logging and security policies.
>
> 3. **Enterprise Skills:** BGP is the industry standard used by AWS, GCP, Azure. Learning BGP in my homelab prepares me for real-world cloud infrastructure.
>
> 4. **Scalability:** BGP prepares my homelab for multi-cluster setups and service mesh architectures.
>
> 5. **No Single Point of Failure:** L2 pins services to one node. BGP distributes load, so a node failure doesn't cause service disruption.
>
> The setup required creating 4 new CRDs (`CiliumBGPClusterConfig`, `CiliumBGPPeerConfig`, `CiliumBGPAdvertisement`) and configuring my UniFi router with ASN 65001 to peer with my cluster (ASN 65000). The migration took about 45 minutes including testing."

---

## 📚 References

- [Cilium BGP Documentation](https://docs.cilium.io/en/stable/network/bgp-control-plane/)
- [UniFi BGP Configuration](https://help.ui.com/hc/en-us/articles/115000166827-UniFi-UDM-USG-Advanced-Routing-BGP)
- [BGP ECMP Load Balancing](https://docs.cilium.io/en/stable/network/bgp-control-plane/#ecmp-load-balancing)
- [ExternalTrafficPolicy: Local](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip)

---

##  Status

- **Current:** L2 Announcements (ARP) - Working
- **Target:** BGP Peering - Ready to migrate (YAML files created)
- **Decision:** Migrate when UniFi router BGP is confirmed available
