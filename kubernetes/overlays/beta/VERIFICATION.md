# 🧪 Beta Overlay Verification

## Pre-Flight Check:

### 1. Test Kustomize Build (Dry Run):
```bash
# Zeigt was deployed würde OHNE es zu tun
kubectl kustomize kubernetes/overlays/beta/
```

### 2. Check Plugin exists:
```bash
# ArgoCD Plugin muss existieren
kubectl get configmap -n argocd argocd-cm -o yaml | grep kustomize-build-with-helm
```

### 3. Step-by-Step Deployment:

```bash
# Option A: Einzeln deployen für Kontrolle
kubectl apply -f kubernetes/infra/controllers/application-set.yaml
kubectl apply -f kubernetes/infra/storage/application-set.yaml  
kubectl apply -f kubernetes/infra/monitoring/application-set.yaml
kubectl apply -f kubernetes/infra/network/application-set.yaml

# Option B: Oder mit Beta Overlay (wenn Test ok)
kubectl apply -k kubernetes/overlays/beta/
```

## Rollback Plan:

```bash
# Falls was schief geht
kubectl delete -k kubernetes/overlays/beta/

# Oder einzeln
kubectl delete applicationset -n argocd storage monitoring controllers network
```

## Expected Result:
```
NAME         APPS
controllers  3 (argocd, cert-manager, sealed-secrets)
storage      3 (proxmox-csi, rook-ceph, rook-ceph-rgw)  
monitoring   5+ (prometheus, grafana, loki, etc.)
network      2+ (cilium, gateway)
```