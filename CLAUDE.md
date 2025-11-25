# Claude Code Guidelines

This document contains guidelines for Claude Code when working on this repository.

---

## 🔴 OBSERVABILITY STACK - NOT PRODUCTION READY

**Status:** Architecture is excellent (A+), but critical HA & security features missing.

### Critical Fixes Required (Before Production):

See `TODO.md` for complete checklist. Summary:

**Priority 1 - CRITICAL (~1.5 hours):**
- Scale Kibana to 2 replicas (single point of failure)
- Delete plain secret from git (security risk!)
- Add PodDisruptionBudgets for Elasticsearch, Vector Aggregator, Kibana
- Change Elasticsearch anti-affinity to "required"
- Increase Elasticsearch storage 10Gi → 50Gi per node

**Priority 2 - HIGH (~2 hours):**
- Add NetworkPolicies for all components
- Add anti-affinity to Vector Aggregator

**What's Already Good:**
- ✅ No redundant log collectors (Vector only)
- ✅ ILM policies configured (retention management)
- ✅ S3 backups with SLM (daily snapshots)
- ✅ ServiceMonitors for Prometheus
- ✅ Enterprise index design

**Recent Changes:**
- ✅ Jaeger v2 migration completed (OpenTelemetry Operator)
- ✅ OpenTelemetry Operator upgraded to 0.99.1
- ✅ Vector Aggregator on stable 0.51.1-debian
- ✅ Duplicate OpenTelemetry Operator removed

---

## 🚀 TODO - BGP Migration (Cilium L2 → BGP)

**Status:** Ready to migrate - BGP YAML files created, documentation complete

**Goal:** Migrate from Cilium L2 Announcements (ARP) to BGP peering for true ECMP load balancing across all 3 nodes

### Migration Checklist (Zero Downtime Approach)

#### **Phase 1: Preparation** ✅
- [x] BGP YAML files created (`bgp-*.yaml`)
- [x] Complete documentation in `kubernetes/infrastructure/network/cilium/bgp.md`
- [ ] Verify UniFi router supports BGP (UDM-Pro/SE required, NOT UDM)
- [ ] Choose ASN numbers (Cluster: 65000, Router: 65001)
- [ ] Plan IP addressing (LoadBalancer Pool: 192.168.68.150-170)

#### **Phase 2: UniFi Router Configuration**
- [ ] SSH to UniFi router
- [ ] Navigate to: Settings → Gateway → Advanced → BGP
- [ ] Enable BGP: ON
- [ ] Set Local ASN: 65001
- [ ] Set Router ID: 192.168.68.1
- [ ] Add BGP Neighbors (one per Talos node):
  - [ ] Node 1: 192.168.68.10, Remote ASN 65000
  - [ ] Node 2: 192.168.68.11, Remote ASN 65000
  - [ ] Node 3: 192.168.68.12, Remote ASN 65000
- [ ] Optional: Set BGP password (must match `bgp-password-secret.yaml`)

#### **Phase 3: Parallel Operation (L2 + BGP)**
**⚠️ CRITICAL: Keep L2 enabled while testing BGP!**

- [ ] Update `kubernetes/infrastructure/network/cilium/values.yaml`:
  ```yaml
  l2announcements:
    enabled: true  # ← KEEP ENABLED!
  bgp:
    enabled: true  # ← ADD THIS
    announce:
      loadbalancerIP: true
  ```
- [ ] Update `kubernetes/infrastructure/network/cilium/kustomization.yaml`:
  ```yaml
  resources:
    - announce.yaml                # ← KEEP ENABLED
    - ip-pool.yaml
    - bgp-cluster-config.yaml      # ← UNCOMMENT
    - bgp-peer-config.yaml         # ← UNCOMMENT
    - bgp-advertisement.yaml       # ← UNCOMMENT
    - bgp-password-secret.yaml     # ← UNCOMMENT (if using auth)
  ```
- [ ] Commit changes: "enable BGP peering in parallel with L2 announcements for zero downtime migration"
- [ ] ArgoCD sync: `argocd app sync infrastructure-cilium`
- [ ] Verify no errors in ArgoCD UI

#### **Phase 4: Verify BGP Peering**
- [ ] Check BGP peers established:
  ```bash
  kubectl exec -n kube-system ds/cilium -- cilium bgp peers
  # Expected: Session State = established for all 3 nodes
  ```
- [ ] Check BGP routes advertised:
  ```bash
  kubectl exec -n kube-system ds/cilium -- cilium bgp routes advertised ipv4 unicast
  # Expected: Service IPs advertised from all 3 nodes
  ```
- [ ] Verify UniFi router sees BGP sessions:
  ```bash
  # SSH to UniFi router
  vtysh -c "show ip bgp summary"
  # Expected: 3 established sessions
  ```

#### **Phase 5: Test with New Service**
- [ ] Deploy test service:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: whoami-bgp-test
    namespace: default
    labels:
      bgp.cilium.io/ip-pool: default
      bgp.cilium.io/advertise-service: default
  spec:
    type: LoadBalancer
    externalTrafficPolicy: Local  # Client IP preservation
    selector:
      app: whoami
    ports:
    - port: 80
  ```
- [ ] Verify service gets BGP IP: `kubectl get svc whoami-bgp-test`
- [ ] Test service reachable: `curl http://<BGP-IP>`
- [ ] Verify client IP preserved (check RemoteAddr in response)
- [ ] Verify ECMP: `curl` multiple times, traffic should hit different nodes

#### **Phase 6: Monitor (24h minimum)**
- [ ] Monitor for 24 hours with both L2 and BGP active
- [ ] Check Cilium logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=cilium`
- [ ] Check BGP peering stays established
- [ ] Verify no service interruptions
- [ ] Monitor UniFi router BGP sessions

#### **Phase 7: Cutover (Disable L2)**
**⚠️ ONLY proceed if Phase 6 passed with ZERO issues!**

- [ ] Update `kubernetes/infrastructure/network/cilium/values.yaml`:
  ```yaml
  l2announcements:
    enabled: false  # ← NOW SAFE TO DISABLE
  bgp:
    enabled: true
  ```
- [ ] Update `kubernetes/infrastructure/network/cilium/kustomization.yaml`:
  ```yaml
  resources:
    # - announce.yaml              # ← COMMENT OUT
    - ip-pool.yaml
    - bgp-cluster-config.yaml
    - bgp-peer-config.yaml
    - bgp-advertisement.yaml
    - bgp-password-secret.yaml
  ```
- [ ] Commit changes: "disable L2 announcements after successful BGP migration and 24h monitoring"
- [ ] ArgoCD sync: `argocd app sync infrastructure-cilium`
- [ ] Immediately verify all services still reachable
- [ ] Monitor for 1 hour post-cutover

#### **Phase 8: Final Verification**
- [ ] All existing services still reachable
- [ ] ECMP load balancing working (traffic distributed across 3 nodes)
- [ ] Client source IP preserved (`externalTrafficPolicy: Local`)
- [ ] Node failure test: Drain one node, verify traffic goes to remaining 2 nodes
- [ ] Document completion in `bgp.md`

### **🚨 Rollback Plan**

If BGP fails at any point:

```bash
# 1. Re-enable L2 in values.yaml
l2announcements:
  enabled: true
bgp:
  enabled: false

# 2. Re-enable L2 in kustomization.yaml
resources:
  - announce.yaml  # ← UNCOMMENT
  # - bgp-*.yaml   # ← COMMENT OUT

# 3. ArgoCD sync
argocd app sync infrastructure-cilium

# Services should be reachable again within 10-20 seconds
```

### **Benefits After Migration**

- ✅ **True Load Balancing**: ECMP distributes traffic across all 3 nodes (instead of single node)
- ✅ **Zero Downtime**: Node failure = 0s downtime (instead of 5-10s with L2)
- ✅ **Client IP Preservation**: Real client IPs in logs (instead of Node IPs)
- ✅ **Better Resource Utilization**: All 48 cores used (instead of 16)
- ✅ **Enterprise Skills**: BGP knowledge for AWS/GCP/Azure

### **Documentation**

Complete migration guide: `kubernetes/infrastructure/network/cilium/bgp.md`

---

## 🔒 TODO - WireGuard Tunnel Setup (DSGVO-Compliant)

**Status:** Documentation complete - Ready to implement tomorrow

**Goal:** Expose homelab services via encrypted WireGuard tunnel with ZERO open ports in homelab using Hetzner VPS + nginx reverse proxy

### Implementation Guide

Complete step-by-step guide: `WIREGUARD_TUNNEL_SETUP.md`

### Architecture Overview

```
Internet User → Hetzner VPS (🇩🇪 Germany) → WireGuard Tunnel → Homelab Gateway API → Services
```

### Key Benefits

- ✅ **ZERO open ports in homelab** (only outbound WireGuard connection)
- ✅ **DSGVO-compliant** (Hetzner = Germany, EU data centers)
- ✅ **Encrypted tunnel** (ChaCha20-Poly1305)
- ✅ **Gateway API unchanged** (HTTPRoutes work as-is)
- ✅ **DDoS protection** (Hetzner infrastructure)
- ✅ **Cost: €5.83/month** (Hetzner CX22 VPS)

### Quick Implementation Checklist

#### Phase 1: Hetzner VPS Setup
- [ ] Create Hetzner Cloud VPS (CX22, Ubuntu 24.04, Falkenstein datacenter)
- [ ] Install WireGuard, nginx, certbot, ufw
- [ ] Configure UFW firewall (22, 80, 443, 51820)

#### Phase 2: WireGuard Server
- [ ] Generate server and client keys
- [ ] Configure `/etc/wireguard/wg0.conf` on Hetzner VPS
- [ ] Enable IP forwarding
- [ ] Start WireGuard server

#### Phase 3: nginx Reverse Proxy
- [ ] Configure nginx to proxy to `10.0.0.2:80` (Gateway API over tunnel)
- [ ] Set up Let's Encrypt SSL certificates
- [ ] Configure HTTP → HTTPS redirect

#### Phase 4: Homelab WireGuard Client
- [ ] Configure WireGuard via Talos machineconfig patch OR Kubernetes DaemonSet
- [ ] Establish tunnel to Hetzner VPS
- [ ] Verify bidirectional connectivity (`ping 10.0.0.1` ↔ `ping 10.0.0.2`)

#### Phase 5: Gateway API Configuration
- [ ] Configure Gateway Service to listen on `10.0.0.2:80`
- [ ] Verify existing HTTPRoutes work unchanged
- [ ] Test services accessible via tunnel

#### Phase 6: DNS Configuration
- [ ] Point `*.timourhomelab.org` to Hetzner VPS public IP
- [ ] Verify DNS propagation
- [ ] Test end-to-end HTTPS access

#### Phase 7: Production Testing
- [ ] Test all services (n8n, Grafana, ArgoCD, etc.)
- [ ] Verify WebSocket support
- [ ] Check SSL certificate validity
- [ ] Monitor WireGuard tunnel stability

### Security Considerations

- No open ports in homelab (only outbound WireGuard connection)
- WireGuard keys stored securely
- SSH key-based authentication on Hetzner VPS
- UFW firewall active
- Regular system updates

### Documentation

Full implementation guide with all commands and configurations: `WIREGUARD_TUNNEL_SETUP.md`

---

## Git Commit Messages

### Rules

1. **Single sentence only** - Commit messages must be concise and fit in one line
2. **No prefixes** - No `feat:`, `fix:`, `chore:`, etc. - just write what you did
3. **No bullet points** - Lines starting with `- ` are forbidden
4. **No AI attribution** - All commits must appear as written by Tim275 only
5. **Natural language** - Write like a human developer, not like an AI

### Format

```
<single sentence describing what was done>
```

### Good Examples

```bash
✅ enable Kyverno with disallow-latest-tag policy
✅ resolve Velero backup storage configuration
✅ update ArgoCD to version 2.12.0
✅ add Istio service mesh architecture docs
✅ implement P0-P4 alerting system with PagerDuty integration
✅ remove duplicate Elasticsearch cleanup job
```

### Bad Examples

```bash
❌ feat: enable Kyverno with disallow-latest-tag policy
❌ fix: resolve Velero backup storage configuration
❌ chore: update ArgoCD to version 2.12.0
❌ docs: add Istio service mesh architecture
❌ feat: enable Kyverno
   - Enable governance-app.yaml
   - Configure policy deployment
   - Add infrastructure exemptions
```

### Enforcement

The repository has a `commit-msg` git hook that enforces these rules:
- Located at `.git/hooks/commit-msg`
- Automatically rejects commits with bullet points
- Automatically rejects commits with AI attribution

### Why Simple Messages?

- **Natural**: Looks like commits from a real developer
- **Readable**: `git log --oneline` is clean and scannable
- **Professional**: No AI-generated markers like "feat:", "chore:", etc.
- **Clarity**: Forces concise description of what actually changed

## Working with Claude Code

When Claude Code suggests commit messages, they will automatically follow these guidelines. Commits should read naturally, as if written by Tim275 himself.
