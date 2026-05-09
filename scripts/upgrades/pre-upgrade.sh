#!/usr/bin/env bash
# Pre-Upgrade Snapshot
# Run BEFORE: talosctl upgrade <node> | talosctl upgrade-k8s | tofu apply
# Captures critical state to /tmp/pre-upgrade-<timestamp>/

set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
SNAP="/tmp/pre-upgrade-${TS}"
mkdir -p "$SNAP"
echo "Snapshot dir: $SNAP"

echo "→ Node + K8s versions"
kubectl get nodes -o wide > "$SNAP/nodes.txt"

echo "→ ArgoCD app status"
kubectl get applications -n argocd -o wide > "$SNAP/argocd-apps.txt"
EXPECTED_APPS=$(kubectl get applications -n argocd --no-headers | wc -l | tr -d ' ')
echo "$EXPECTED_APPS" > "$SNAP/argocd-app-count.txt"

echo "→ CoreDNS Corefile (must survive upgrade)"
kubectl get cm -n kube-system coredns -o jsonpath='{.data.Corefile}' > "$SNAP/coredns-corefile.txt"
grep "rewrite name exact iam" "$SNAP/coredns-corefile.txt" >/dev/null && \
  echo "  ✓ iam-rewrite present" || echo "  ✗ iam-rewrite MISSING (already broken)"

echo "→ KC users count (LDAP-Federation health)"
ADMIN_PASS=$(kubectl get secret -n keycloak keycloak-admin -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
KC_USERS=$(kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$ADMIN_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh get users/count -r kubernetes 2>&1
" 2>/dev/null | tail -1)
echo "$KC_USERS" > "$SNAP/kc-users-count.txt"
echo "  KC users: $KC_USERS"

echo "→ LLDAP CronJob last success"
kubectl get cronjob -n lldap lldap-bootstrap -o yaml > "$SNAP/lldap-cronjob.yaml" 2>/dev/null || true

echo "→ Critical SealedSecrets (count)"
kubectl get sealedsecret -A --no-headers | wc -l > "$SNAP/sealed-secrets-count.txt"

echo "→ PVCs Bound"
kubectl get pvc -A --no-headers | awk '$3=="Bound"' | wc -l > "$SNAP/pvc-bound-count.txt"

echo "→ Pods Running per namespace"
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c > "$SNAP/pods-per-ns.txt"

echo
echo "✓ Snapshot saved to: $SNAP"
echo "Run AFTER upgrade: ./scripts/upgrades/post-upgrade-verify.sh $SNAP"
