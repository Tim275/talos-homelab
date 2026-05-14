#!/usr/bin/env bash
# Post-Upgrade Verify
# Run AFTER: talosctl upgrade-k8s | talos OS upgrade
# Catches all known regression patterns from CLAUDE.md
#
# Usage: ./scripts/upgrades/post-upgrade-verify.sh [optional: pre-snapshot-dir]

set -uo pipefail

SNAP="${1:-}"
FAIL=0
WARN=0

ok()   { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠ $*"; WARN=$((WARN+1)); }

echo "=== 1. CoreDNS — iam-rewrite + gateway forward ==="
COREFILE=$(kubectl get cm -n kube-system coredns -o jsonpath='{.data.Corefile}')
if echo "$COREFILE" | grep -q "rewrite name exact iam.timourhomelab.org"; then
  ok "iam-rewrite present"
else
  fail "iam-rewrite MISSING (talosctl upgrade-k8s overrode it)"
  echo "    FIX: kubectl apply -f tofu/talos/inline-manifests/coredns-config.yaml"
  echo "         kubectl rollout restart deployment/coredns -n kube-system"
fi
if echo "$COREFILE" | grep -q "forward . 192.168.0.1"; then
  ok "gateway forward (no Talos hostDNS)"
else
  fail "forward target wrong — pods will see SERVFAIL externally"
fi

echo
echo "=== 2. DNS resolution from in-cluster ==="
DNS_TEST=$(kubectl run dns-verify-$(date +%s) --rm -i --restart=Never \
  --image=ghcr.io/cloudnative-pg/postgresql:16.1 \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"x","image":"ghcr.io/cloudnative-pg/postgresql:16.1","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"cpu":"100m","memory":"128Mi"}},"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}},"command":["sh","-c","getent hosts github.com >/dev/null 2>&1 && echo DNSOK || echo DNSFAIL"]}]}}' \
  --timeout=30s 2>&1)
echo "$DNS_TEST" | grep -q "DNSOK" && ok "github.com resolves" || fail "DNS broken"

echo
echo "=== 3. Keycloak — users + reachability ==="
ADMIN_PASS=$(kubectl get secret -n keycloak keycloak-admin -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
KC_PODS=$(kubectl get pods -n keycloak -l app=keycloak --no-headers 2>/dev/null | grep -c Running || echo 0)
[ "$KC_PODS" -ge 1 ] && ok "$KC_PODS KC pod(s) Running" || fail "KC pods down"

KC_USERS=$(kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$ADMIN_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh get users/count -r kubernetes 2>&1
" 2>/dev/null | tail -1)
if [ -n "$KC_USERS" ] && [ "$KC_USERS" -ge 2 ] 2>/dev/null; then
  ok "KC has $KC_USERS users (LDAP federation working)"
else
  fail "KC users low/missing ($KC_USERS) — LDAP federation broken or LLDAP empty"
  echo "    FIX: trigger LDAP sync OR re-run lldap-bootstrap CronJob"
fi

# Verify MFA still enforced (fresh imports lose TOTP credential)
TOTP_USERS=$(kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$ADMIN_PASS' >/dev/null 2>&1
for U in timour tim275; do
  TID=\$(/opt/keycloak/bin/kcadm.sh get users -r kubernetes -q username=\$U --fields id 2>&1 | grep '\"id\"' | head -1 | cut -d'\"' -f4)
  HAS_TOTP=\$(/opt/keycloak/bin/kcadm.sh get users/\$TID -r kubernetes --fields totp 2>&1 | grep -c 'true' || echo 0)
  REQ_TOTP=\$(/opt/keycloak/bin/kcadm.sh get users/\$TID -r kubernetes --fields requiredActions 2>&1 | grep -c 'CONFIGURE_TOTP' || echo 0)
  [ \"\$HAS_TOTP\" = '1' ] || [ \"\$REQ_TOTP\" = '1' ] && echo \"\$U:OK\" || echo \"\$U:NO_MFA\"
done
" 2>/dev/null)
if echo "$TOTP_USERS" | grep -q "NO_MFA"; then
  fail "User(s) without TOTP/CONFIGURE_TOTP: $TOTP_USERS"
  echo "    FIX: kcadm.sh update users/<id> -r kubernetes -s 'requiredActions=[\"CONFIGURE_TOTP\"]'"
else
  ok "MFA enforced on timour + tim275"
fi

echo
echo "=== 4. LLDAP — bootstrap CronJob healthy ==="
LAST_OK=$(kubectl get cronjob -n lldap lldap-bootstrap -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)
[ -n "$LAST_OK" ] && ok "Last success: $LAST_OK" || warn "CronJob has never succeeded — trigger manually"

echo
echo "=== 5. ArgoCD — app health ==="
NOT_HEALTHY=$(kubectl get applications -n argocd --no-headers 2>/dev/null | awk '$2!="Synced" || $3!="Healthy"' | wc -l | tr -d ' ')
[ "$NOT_HEALTHY" -le 2 ] && ok "Apps Synced+Healthy: $NOT_HEALTHY drifting" || warn "$NOT_HEALTHY apps not Synced+Healthy"

MISSING=$(kubectl get applications -n argocd --no-headers 2>/dev/null | awk '$3=="Missing"' | wc -l | tr -d ' ')
[ "$MISSING" -eq 0 ] && ok "no Missing apps" || fail "$MISSING apps Missing"

echo
echo "=== 6. PVCs / Storage ==="
PENDING=$(kubectl get pvc -A --no-headers 2>/dev/null | awk '$4=="Pending"' | wc -l | tr -d ' ')
[ "$PENDING" -eq 0 ] && ok "no Pending PVCs" || fail "$PENDING PVCs Pending"

echo
echo "=== 7. SPIRE-Agents — service-account-token health (battle-tested 2026-05-14) ==="
# Talos-upgrade kann kubelet während PSAT-token-renewal sigterm'n → expired token
# → SPIRE-agent crashloop → cluster-weit mTLS broken → drova services TCP-timeout
SPIRE_TOTAL=$(kubectl get pods -n cilium-spire -l app=spire-agent --no-headers 2>/dev/null | wc -l | tr -d ' ')
SPIRE_OK=$(kubectl get pods -n cilium-spire -l app=spire-agent --no-headers 2>/dev/null \
  | awk '$3=="Running"' | wc -l | tr -d ' ')
SPIRE_BAD=$((SPIRE_TOTAL - SPIRE_OK))
if [ "$SPIRE_BAD" -eq 0 ] && [ "$SPIRE_TOTAL" -gt 0 ]; then
  ok "all $SPIRE_TOTAL SPIRE-agents Running"
elif [ "$SPIRE_TOTAL" -eq 0 ]; then
  fail "0 SPIRE-agents found — DaemonSet down or namespace gone"
else
  fail "$SPIRE_BAD of $SPIRE_TOTAL SPIRE-agent(s) NOT Running — Cilium mTLS broken"
  echo "    FIX: kubectl rollout restart ds/spire-agent -n cilium-spire"
fi

# Check for ANY 'service account token has expired' in last 10min logs
TOKEN_ERR=$(kubectl logs -n cilium-spire spire-server-0 -c spire-server --since=10m 2>/dev/null \
  | grep -c "service account token has expired" | tr -d ' \n')
TOKEN_ERR=${TOKEN_ERR:-0}
if [ "$TOKEN_ERR" -eq 0 ] 2>/dev/null; then
  ok "no PSAT-token-expired errors"
else
  warn "$TOKEN_ERR PSAT-token-expired errors in 10min (lingering, may self-heal)"
fi

echo
echo "=== 8. Phase=Succeeded pods (silent-death pattern after upgrade-eviction) ==="
# StatefulSet/Deployment behandelt Exit Code 0 als "successfully terminated" → kein
# auto-recreate. Heute: AM-0 (17h), Prometheus-0 (28h), envoy-gateway (40 restarts).
SUCCEEDED=$(kubectl get pods -A --field-selector=status.phase=Succeeded --no-headers 2>/dev/null \
  | grep -vE "Completed|^kube-system" | wc -l | tr -d ' ')
# Filter out legit Jobs/CronJobs (have ownerReference Job)
ZOMBIE=$(kubectl get pods -A --field-selector=status.phase=Succeeded -o json 2>/dev/null \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
zombies = []
for p in d.get('items', []):
    refs = p.get('metadata', {}).get('ownerReferences', [])
    # Skip if owned by Job (legit) — flag if owned by StatefulSet/ReplicaSet
    if any(r.get('kind') in ('StatefulSet', 'ReplicaSet') for r in refs):
        zombies.append(f\"{p['metadata']['namespace']}/{p['metadata']['name']}\")
for z in zombies[:10]:
    print(z)
print(f'TOTAL:{len(zombies)}', file=sys.stderr)
" 2>&1)
ZOMBIE_COUNT=$(echo "$ZOMBIE" | grep -oE "TOTAL:[0-9]+" | cut -d: -f2)
if [ "${ZOMBIE_COUNT:-0}" -eq 0 ]; then
  ok "no zombie pods (Phase=Succeeded under StatefulSet/RS)"
else
  fail "$ZOMBIE_COUNT zombie pods — won't auto-recreate, manual force-delete needed"
  echo "$ZOMBIE" | grep -v "TOTAL:" | head -5 | sed 's/^/    /'
  echo "    FIX: kubectl delete pod -n <ns> <pod> --force --grace-period=0"
fi

echo
echo "=== 9. PodDisruptionBudgets — unhealthy? ==="
# Flag NUR wenn currentHealthy < expectedPods. disruptionsAllowed=0 ist by-design
# bei single-replica services (n8n-postgres-primary etc) und kein Problem.
PDB_UNHEALTHY=$(kubectl get pdb -A -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
unhealthy = []
for p in d.get('items', []):
    cur = p.get('status', {}).get('currentHealthy', 0)
    exp = p.get('status', {}).get('expectedPods', 0)
    if exp > 0 and cur < exp:
        ns = p['metadata']['namespace']
        nm = p['metadata']['name']
        unhealthy.append(f'{ns}/{nm} ({cur}/{exp})')
for u in unhealthy[:5]:
    print(u)
print(f'TOTAL:{len(unhealthy)}', file=sys.stderr)
" 2>&1)
PDB_COUNT=$(echo "$PDB_UNHEALTHY" | grep -oE "TOTAL:[0-9]+" | cut -d: -f2)
[ "${PDB_COUNT:-0}" -eq 0 ] && ok "all PDBs at full health" \
  || fail "$PDB_COUNT PDB(s) unhealthy — pods missing from coverage"

echo
echo "=== 10. Velero backups (last 24h) ==="
# Velero Schedules sollten lastBackup < 24h haben
STALE_VELERO=$(kubectl get schedules -n velero -o json 2>/dev/null | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
d = json.load(sys.stdin)
stale = []
threshold = datetime.now(timezone.utc) - timedelta(hours=26)
for s in d.get('items', []):
    nm = s['metadata']['name']
    last = s.get('status', {}).get('lastBackup', '')
    if not last:
        stale.append(f'{nm}: NEVER')
        continue
    try:
        last_dt = datetime.fromisoformat(last.replace('Z', '+00:00'))
        if last_dt < threshold:
            stale.append(f'{nm}: {last}')
    except: pass
for s in stale[:5]:
    print(s)
print(f'TOTAL:{len(stale)}', file=sys.stderr)
" 2>&1)
STALE_COUNT=$(echo "$STALE_VELERO" | grep -oE "TOTAL:[0-9]+" | cut -d: -f2)
[ "${STALE_COUNT:-0}" -eq 0 ] && ok "all Velero schedules backed up <26h ago" \
  || fail "$STALE_COUNT Velero schedules stale (>26h)"

echo
echo "=== 11. CNPG backups — daily completed today? ==="
# Drova + n8n + keycloak postgres müssen täglich backupen
for CLUSTER_NS in "drova/drova-postgres" "n8n-prod/n8n-postgres" "keycloak/keycloak-db"; do
  NS="${CLUSTER_NS%/*}"
  CL="${CLUSTER_NS#*/}"
  # Check if CNPG cluster exists
  kubectl get cluster -n "$NS" "$CL" >/dev/null 2>&1 || continue
  TODAY=$(date -u +%Y%m%d)
  COMPLETED=$(kubectl get backup.postgresql.cnpg.io -n "$NS" --no-headers 2>/dev/null \
    | grep "$TODAY" | grep -c "completed" | tr -d ' \n')
  COMPLETED=${COMPLETED:-0}
  if [ "$COMPLETED" -ge 1 ] 2>/dev/null; then
    ok "$CL: $COMPLETED backup(s) completed today"
  else
    LATEST=$(kubectl get backup.postgresql.cnpg.io -n "$NS" --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | tail -1)
    warn "$CL: no completed backup today ($(echo $LATEST | awk '{print $1, $4}'))"
  fi
done

echo
echo "=== 12. Argo Rollouts — any aborted? ==="
ABORTED=$(kubectl get rollouts -A --no-headers 2>/dev/null | awk '$NF=="Degraded"' | wc -l | tr -d ' ')
[ "$ABORTED" -eq 0 ] && ok "no Degraded Rollouts" \
  || fail "$ABORTED Degraded Rollout(s) — AnalysisTemplate may have failed"

echo
echo "=== 13. Compare to pre-snapshot ==="
if [ -n "$SNAP" ] && [ -d "$SNAP" ]; then
  EXPECTED=$(cat "$SNAP/argocd-app-count.txt")
  ACTUAL=$(kubectl get applications -n argocd --no-headers | wc -l | tr -d ' ')
  [ "$EXPECTED" = "$ACTUAL" ] && ok "ArgoCD app count: $ACTUAL (match)" || warn "App count drifted: $EXPECTED → $ACTUAL"

  PRE_KC=$(cat "$SNAP/kc-users-count.txt")
  [ "$PRE_KC" = "$KC_USERS" ] && ok "KC users count: $KC_USERS (match)" || warn "KC users: $PRE_KC → $KC_USERS"
else
  warn "No pre-snapshot provided — skipping diff"
fi

echo
echo "════════════════════════════════════════════════════"
[ $FAIL -eq 0 ] && [ $WARN -eq 0 ] && echo "✅ ALL CHECKS PASSED — upgrade successful" && exit 0
[ $FAIL -eq 0 ] && echo "⚠️  $WARN warnings — review but not blocking" && exit 0
echo "❌ $FAIL failures, $WARN warnings — see fixes above"
exit 1
