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
echo "=== 7. Compare to pre-snapshot ==="
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
