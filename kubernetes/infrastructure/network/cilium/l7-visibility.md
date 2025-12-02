# Cilium L7 Visibility - Best Practices

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

## Best Practice: L7 Rules in CiliumNetworkPolicy

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
  endpointSelector: {}  # ⚠️ MATCHED ALLE PODS!

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

## Referenzen

- [Cilium L7 Protocol Visibility Docs](https://docs.cilium.io/en/stable/observability/visibility/)
- [Cilium Policy Enforcement](https://docs.cilium.io/en/stable/security/policy/intro/)
- [Google GKE Dataplane V2 + Hubble](https://cloud.google.com/blog/products/containers-kubernetes/using-hubble-for-gke-dataplane-v2-observability)
