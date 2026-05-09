# Istio (base) — PARKED

**Status:** Folder exists, NICHT in `network/kustomization.yaml` referenziert.
ArgoCD synct das nicht. Folder bleibt für eventuelle Re-Activation.

## Warum entfernt (April 2026)

- 0 von 8 Istio-Features aktiv genutzt
- ~500MB RAM Overhead (istiod + Sidecars)
- Alle Features abgedeckt durch Cilium:
  - mTLS → Cilium SPIRE-Integration
  - L7 NetworkPolicy → Cilium L7 Proxy
  - Observability → Hubble + Tempo + Prometheus
  - Service-Mesh-AuthZ → CiliumNetworkPolicy

## Restore-Steps (falls Istio doch gebraucht wird)

```bash
# 1. application.yaml in folder erstellen + base kustomization einkommentieren
# 2. kubernetes/infrastructure/network/kustomization.yaml ergänzen:
#    - istio-base/application.yaml
#    - istio-cni/application.yaml
#    - istio-control-plane/application.yaml
#    - istio-gateway/application.yaml
#    - istio-config/application.yaml
# 3. git push → ArgoCD synct in 1-3min
# 4. Verify: kubectl get pods -n istio-system
```

## Sub-Folders (alle parked)

- `istio-base/` — base CRDs (du bist hier)
- `istio-cni/` — Istio CNI plugin
- `istio-config/` — AuthorizationPolicy, VirtualService, DestinationRule examples
- `istio-control-plane/` — istiod + ztunnel
- `istio-gateway/` — ingress-gateway
