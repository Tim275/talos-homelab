# 🚨 ARGOCD STUCK APPLICATION PREVENTION

## Problem erkannt:
- `infrastructure-grafana` Application war stuck in deletion loop
- ApplicationSet erstellt es permanent neu, egal was wir löschen
- In Talos kein direkter etcd access möglich
- Finalizers können stuck werden
- Cache issues führen zu endlosen loops

## 🛡️ PREVENTION RULES - NIEMALS WIEDER!

### 1. IMMER ApplicationSet ERST disablen, DANN löschen
```bash
# ❌ FALSCH: Application direkt löschen
kubectl delete application infrastructure-grafana -n argocd

# ✅ RICHTIG: Erst ApplicationSet disablen
# 1. In monitoring-app.yaml auskommentieren:
# - name: grafana  →  # - name: grafana
# 2. Commit & Push
# 3. Infrastructure sync
# 4. DANN Application löschen
```

### 2. CACHE CLEAR vor kritischen Operationen
```bash
# Vor großen Changes immer:
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
sleep 30  # Warten bis restart komplett
```

### 3. STUCK APPLICATION NOTFALL-COMMANDS
```bash
# Level 1: Finalizer entfernen
kubectl patch application STUCK_APP -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge

# Level 2: ApplicationSet stoppen
kubectl scale applicationset RESPONSIBLE_SET -n argocd --replicas=0

# Level 3: ArgoCD komplett neustarten
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd

# Level 4: NUKLEAR - Talos rebuild
cd tofu/
tofu destroy -auto-approve
tofu apply -auto-approve
```

### 4. TALOS ARGOCD CONFIG IMPROVEMENTS
Bereits implementiert in `kubernetes/infrastructure/controllers/argocd/values.yaml`:
```yaml
# 🚨 CRITICAL: Global Cache Control
reposerver.cache.expiration: "10m"          # Short cache TTL
controller.ignore.orphaned.resources: true   # Ignore orphaned resources
application.operation.retry.backoff.maxDuration: "3m"  # Max retry time
```

### 5. MONITORING für stuck applications
```bash
# Check für stuck applications:
kubectl get applications.argoproj.io -n argocd --no-headers | grep -E "(Unknown|Progressing)" | awk '{print $1}' | while read app; do
  echo "⚠️ STUCK: $app"
  kubectl get application $app -n argocd -o jsonpath='{.metadata.deletionTimestamp}'
  echo
done
```

### 6. GIT WORKFLOW RULES
- **NIEMALS** direkte Application changes ohne ApplicationSet update
- **IMMER** commit & push vor kritischen operations
- **IMMER** warten auf ArgoCD sync vor deletion

## 🔄 EMERGENCY REBUILD PROZEDURE

Wenn stuck applications nicht mehr lösbar:

1. **Backup critical data:**
```bash
kubectl get sealed-secrets -A -o yaml > sealed-secrets-backup.yaml
kubectl get pvc -A -o yaml > pvc-backup.yaml
```

2. **Talos cluster rebuild:**
```bash
cd tofu/
tofu destroy -auto-approve
tofu apply -auto-approve
```

3. **Restore data:**
```bash
kubectl apply -f sealed-secrets-backup.yaml
# PVCs automatically recreated by applications
```

## ✅ PREVENTION CHECKLIST

Vor jedem großen ArgoCD change:
- [ ] ApplicationSet pattern verstanden?
- [ ] Cache cleared?
- [ ] Git committed & pushed?
- [ ] ApplicationSet disabled before deletion?
- [ ] Backup critical data?

**REGEL**: Lieber 5 Minuten prevention als 2 Stunden debugging!
