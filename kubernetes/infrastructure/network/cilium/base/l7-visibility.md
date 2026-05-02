# Cilium L7 Visibility - s

## Was ist L7 Visibility?

L7 (Layer 7) Visibility ermöglicht Hubble/Cilium, HTTP-Traffic im Detail zu sehen:

| Layer | Was sichtbar ist |
|-------|------------------|
| **L3/L4** (Standard) | Source IP, Dest IP, Port, Protocol |
| **L7** (mit Visibility) | HTTP Method, Path, Status Code, Latency |

### Beispiel Output

```bash
# Ohne L7:
pod-a → pod-b:8080 TCP FORWARDED

# Mit L7:
GET /api/orders → 200 OK (5ms)
POST /api/payments → 201 Created (120ms)
DELETE /api/orders/123 → 204 No Content (8ms)
```

---

## : L7 Rules in CiliumNetworkPolicy

### Empfohlener Ansatz (Namespace-scoped)

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: my-app
  namespace: my-namespace  # Scope auf Namespace!
spec:
  endpointSelector:
    matchLabels:
      app: my-app
      component: api  # Spezifische Komponente

  ingress:
    - toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: ".*"  # Alle HTTP Methods sichtbar

  egress:
    # DNS mit L7 Visibility
    - toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
```

### Vorteile

- L7 HTTP Visibility (Method, Path, Status, Latency)
- DNS Query Visibility
- Zero Trust Egress bleibt aktiv
- Kein Risiko für Cluster-Crash

---

## KRITISCHES NO-GO: Cluster-Wide L7 Policy

### Was NIEMALS tun

```yaml
# ⛔ NIEMALS SO MACHEN - CRASHED DEN CLUSTER!
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: global-l7-visibility
spec:
  endpointSelector: {}  #  MATCHED ALLE PODS!

  ingress:
    - toPorts:
        - ports:
            - port: "80"
          rules:
            http:
              - method: ".*"
```

### Warum crashed das den Cluster?

1. **`endpointSelector: {}`** = Matched ALLE Pods im Cluster
2. Cilium aktiviert **Policy Enforcement Mode** auf allen Pods
3. **CoreDNS** wird auch gematched → kann API Server nicht mehr erreichen
4. **Kein DNS** = Cluster Netzwerk tot
5. **BPF State** bleibt nach Pod-Restart → Node Reboot nötig

### Real-World Incident (02.12.2025)

```
Timeline:
- 00:30 CiliumClusterwideNetworkPolicy mit endpointSelector: {} deployed
- 00:31 CoreDNS verliert API Server Verbindung (Policy Enforcement aktiv)
- 00:32 Cilium Hubble crash (nil pointer dereference in CorrelatePolicy)
- 00:33 Cloudflare Tunnel down (DNS timeout)
- 00:35 Alle Services unreachable
- 00:40-01:30 Recovery: Policy delete, Cilium restart, 3 Node Reboots
```

---

## Richtige Implementierung

### Option 1: Per-Service CiliumNetworkPolicy (Empfohlen)

```yaml
# Pro Service eine Policy - sicher und kontrolliert
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: n8n-main
  namespace: n8n-prod  # Namespace-scoped!
spec:
  endpointSelector:
    matchLabels:
      app: n8n
      component: main  # Spezifisch!

  ingress:
    - toPorts:
        - ports:
            - port: "3008"
          rules:
            http:
              - method: ".*"
```

### Option 2: Pod Annotations (Nur Visibility, kein Enforcement)

```yaml
# Wenn KEINE CiliumNetworkPolicy existiert
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        io.cilium.proxy-visibility: "<Ingress/8080/TCP/HTTP>,<Egress/53/UDP/DNS>"
```

**Wichtig:** Annotations werden IGNORIERT wenn eine CiliumNetworkPolicy existiert!

---

## Entscheidungsbaum

```
Brauchst du L7 Visibility?
│
├─ Ja, mit Security (Zero Trust)
│   └─ CiliumNetworkPolicy pro Namespace/Service
│      └─ ingress.toPorts.rules.http
│
├─ Ja, nur Observability (kein Enforcement)
│   └─ Pod Annotations (io.cilium.proxy-visibility)
│      └─ Nur wenn KEINE Policy existiert!
│
└─ Nein
    └─ Standard L3/L4 Visibility reicht
```

---

## Hubble Commands für L7

```bash
# L7 Flows anzeigen
hubble observe -n n8n-prod -t l7 --last 20

# HTTP Traffic filtern
hubble observe -n n8n-prod --protocol http

# DNS Queries sehen
hubble observe -n n8n-prod --protocol dns

# Auf spezifischem Node
kubectl exec -n kube-system <cilium-pod> -- hubble observe -n n8n-prod -t l7
```

---

## Checkliste vor L7 Policy Deployment

- [ ] Policy ist **Namespace-scoped** (NICHT CiliumClusterwideNetworkPolicy)
- [ ] `endpointSelector` hat **spezifische Labels** (NICHT `{}`)
- [ ] `kube-system` Namespace ist **NICHT** included
- [ ] CoreDNS/API Server Traffic ist **NICHT** betroffen
- [ ] Getestet in Dev/Staging vor Production
- [ ] ArgoCD App hat `prune: true` für Rollback

---

## Policy Audit Mode - Policies testen ohne zu blocken

### Was ist Audit Mode?

Audit Mode erlaubt dir, Policies zu testen **ohne Traffic zu blockieren**. Statt `DENIED` wird Traffic nur **geloggt**.

### Aktivierung via Helm Values

```yaml
# cilium/values.yaml
policyAuditMode: true  # Global für alle Policies
```

### Aktivierung pro Policy (Empfohlen)

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: my-app-audit
  namespace: my-namespace
  annotations:
    # Policy im Audit Mode - loggt nur, blockt nicht
    io.cilium.policy.audit-mode: "true"
spec:
  endpointSelector:
    matchLabels:
      app: my-app
  egress:
    - toEndpoints:
        - matchLabels:
            app: database
      toPorts:
        - ports:
            - port: "5432"
```

### Audit Logs prüfen

```bash
# Zeigt was geblockt WÜRDE (aber nicht wird)
hubble observe --verdict AUDIT

# Oder via Cilium Agent
kubectl exec -n kube-system ds/cilium -- cilium-dbg monitor --type policy-verdict
```

### Workflow: Policy sicher einführen

```
1. Policy mit audit-mode: "true" deployen
2. Hubble/Grafana beobachten (1-2 Tage)
3. Prüfen: Welcher Traffic würde geblockt?
4. Policy anpassen falls nötig
5. Annotation entfernen → Policy aktiv
```

### Grafana Dashboard

Das **official-hubble** Dashboard zeigt:
- `hubble_flows_processed_total{verdict="AUDIT"}` - Was geblockt würde

---

## BGP Peering vs. L2 Announcements

### Was ist das?

| Feature | L2 Announcements | BGP Peering |
|---------|------------------|-------------|
| **Protokoll** | ARP (Layer 2) | BGP (Layer 3) |
| **Reichweite** | Gleiches VLAN | Über Router hinweg |
| **Setup** | Einfach | Komplexer |
| **Skalierung** | Begrenzt | Enterprise-grade |
| **Use Case** | Homelab, Single VLAN | Multi-Site, Data Center |

### Du hast aktuell: L2 Announcements

```yaml
# cilium/announce.yaml - ARP-basiert
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
```

### BGP wäre: Routing mit deinem UniFi Router

```yaml
# bgp-peer-config.yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeerConfig
spec:
  peers:
    - peerAddress: 192.168.1.1  # Dein Router
      peerASN: 65000
```

**Für Homelab:** L2 reicht völlig. BGP nur wenn du Multi-Site oder komplexes Routing brauchst.

---

## Istio + Cilium Integration

### Was macht das?

| Component | Funktion |
|-----------|----------|
| **Cilium** | Networking (CNI), Network Policies, L3/L4 |
| **Istio** | Service Mesh, mTLS, L7 Traffic Management |
| **Zusammen** | Cilium für Netzwerk, Istio für mTLS/L7 |

### Architektur

```
┌─────────────────────────────────────────────┐
│              Application Pods               │
├─────────────────────────────────────────────┤
│  Istio Sidecar (Envoy)  ← mTLS, L7 Routing │
├─────────────────────────────────────────────┤
│  Cilium Agent           ← CNI, L3/L4 Policy │
├─────────────────────────────────────────────┤
│  Linux Kernel (eBPF)    ← Fast Datapath    │
└─────────────────────────────────────────────┘
```

### Du hast beides!

```bash
kubectl get pods -n istio-system  # Istiod läuft
kubectl get pods -n kube-system -l k8s-app=cilium  # Cilium läuft
```

### Wann Istio nutzen?

| Szenario | Cilium allein | + Istio |
|----------|---------------|---------|
| Network Policies |  |  |
| L7 Visibility |  |  |
| **mTLS (Encryption)** |  |  |
| **Traffic Splitting** |  |  (Canary, Blue/Green) |
| **Circuit Breaker** |  |  |
| **Rate Limiting** |  Basic |  Advanced |

**Für dein Homelab:** Cilium reicht für 95% der Fälle. Istio nur wenn du mTLS oder Advanced Traffic Management brauchst.

---

## Referenzen

- [Cilium L7 Protocol Visibility Docs](https://docs.cilium.io/en/stable/observability/visibility/)
- [Cilium Policy Enforcement](https://docs.cilium.io/en/stable/security/policy/intro/)
- [Google GKE Dataplane V2 + Hubble](https://cloud.google.com/blog/products/containers-kubernetes/using-hubble-for-gke-dataplane-v2-observability)
