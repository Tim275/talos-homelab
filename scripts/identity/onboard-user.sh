#!/usr/bin/env bash
# Onboarding-Script: neuer Mitarbeiter
#
# Usage:
#   ./scripts/identity/onboard-user.sh <username> <email> "<full-name>" [groups]
#
# Beispiele:
#   ./scripts/identity/onboard-user.sh max max@firma.de "Max Mustermann" engineers
#   ./scripts/identity/onboard-user.sh anna anna@firma.de "Anna Schmidt" "drova-admins,argocd-admins"
#
# Was es macht:
#   1. Erstellt User in LLDAP (idempotent — Exists ist OK)
#   2. Setzt temporäres Passwort (User wird gezwungen, beim ersten Login zu ändern)
#   3. Triggert Keycloak LDAP-Federation Sync
#   4. Setzt KC requiredActions: UPDATE_PASSWORD, CONFIGURE_TOTP, VERIFY_EMAIL
#   5. Sendet Welcome-Email mit Magic-Link an User
#
# Resultat: User bekommt Email → klickt Link → führt durch Setup → kann sich einloggen.

set -euo pipefail

USERNAME="${1:-}"
EMAIL="${2:-}"
FULLNAME="${3:-}"
GROUPS="${4:-viewers}"

if [ -z "$USERNAME" ] || [ -z "$EMAIL" ] || [ -z "$FULLNAME" ]; then
  echo "Usage: $0 <username> <email> \"<full-name>\" [groups,comma,separated]"
  echo "Example: $0 max max@firma.de \"Max Mustermann\" engineers"
  exit 1
fi

FIRST=$(echo "$FULLNAME" | awk '{print $1}')
LAST=$(echo "$FULLNAME" | cut -d' ' -f2-)
TEMP_PASS=$(openssl rand -base64 24 | tr -d '+/=' | head -c 20)

echo "═════════════════════════════════════════════════════════"
echo "  Onboarding: $FULLNAME ($EMAIL)"
echo "═════════════════════════════════════════════════════════"

LLDAP_PASS=$(kubectl get secret -n lldap lldap-secrets -o jsonpath='{.data.admin-password}' | base64 -d)
KC_PASS=$(kubectl get secret -n keycloak keycloak-admin -o jsonpath='{.data.password}' | base64 -d)

echo
echo "→ Step 1: LLDAP — User erstellen"
HELPER=onboard-helper-$(date +%s)
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata: { name: $HELPER, namespace: lldap }
spec:
  restartPolicy: Never
  securityContext: { runAsNonRoot: true, runAsUser: 1000, seccompProfile: { type: RuntimeDefault }}
  containers:
    - name: helper
      image: alpine:3.23
      command: ["sleep", "180"]
      resources: { requests: { cpu: "10m", memory: "32Mi" }, limits: { cpu: "200m", memory: "128Mi" }}
      securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 1000, capabilities: { drop: ["ALL"] }}
EOF
kubectl wait pod $HELPER -n lldap --for=condition=Ready --timeout=60s >/dev/null

kubectl exec -n lldap $HELPER -- sh -c "
apk add --no-cache curl jq openldap-clients >/dev/null 2>&1
TOKEN=\$(curl -sf -X POST http://lldap:17170/auth/simple/login \
  -H 'Content-Type: application/json' \
  -d '{\"username\":\"admin\",\"password\":\"$LLDAP_PASS\"}' | jq -r '.token')

# Create user
curl -sf -X POST http://lldap:17170/api/graphql \
  -H 'Content-Type: application/json' \
  -H \"Authorization: Bearer \$TOKEN\" \
  -d '{\"query\":\"mutation { createUser(user: {id: \\\"$USERNAME\\\", email: \\\"$EMAIL\\\", displayName: \\\"$FULLNAME\\\", firstName: \\\"$FIRST\\\", lastName: \\\"$LAST\\\"}) { id } }\"}' \
  | head -c 200
echo
" 2>&1

# Set password via LDAP
kubectl exec -n lldap $HELPER -- ldappasswd -x -H ldap://lldap-ldap:389 \
  -D 'uid=admin,ou=people,dc=homelab,dc=local' \
  -w "$LLDAP_PASS" \
  -s "$TEMP_PASS" \
  "uid=$USERNAME,ou=people,dc=homelab,dc=local" 2>&1 | head -2

# Add to groups
for GROUP in $(echo "$GROUPS" | tr ',' ' '); do
  echo "  Adding to group: $GROUP"
  kubectl exec -n lldap $HELPER -- sh -c "
TOKEN=\$(curl -sf -X POST http://lldap:17170/auth/simple/login \
  -H 'Content-Type: application/json' \
  -d '{\"username\":\"admin\",\"password\":\"$LLDAP_PASS\"}' | jq -r '.token')
GROUPS_RESP=\$(curl -sf http://lldap:17170/api/graphql \
  -H 'Content-Type: application/json' \
  -H \"Authorization: Bearer \$TOKEN\" \
  -d '{\"query\":\"{ groups { id displayName } }\"}')
GID=\$(echo \"\$GROUPS_RESP\" | jq -r \".data.groups[] | select(.displayName==\\\"$GROUP\\\") | .id\")
[ -n \"\$GID\" ] && curl -sf -X POST http://lldap:17170/api/graphql \
  -H 'Content-Type: application/json' \
  -H \"Authorization: Bearer \$TOKEN\" \
  -d '{\"query\":\"mutation { addUserToGroup(userId: \\\"$USERNAME\\\", groupId: '\$GID') { ok } }\"}' \
  | head -c 100
" 2>&1
done

kubectl delete pod $HELPER -n lldap --wait=false >/dev/null

echo
echo "→ Step 2: KC — LDAP-Federation Sync"
FED_ID=$(kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$KC_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh get components -r kubernetes -q type=org.keycloak.storage.UserStorageProvider --fields id 2>&1 | grep '\"id\"' | head -1 | cut -d'\"' -f4
")
kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$KC_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh create user-storage/$FED_ID/sync?action=triggerFullSync -r kubernetes 2>&1
" >/dev/null

sleep 2
echo
echo "→ Step 3: KC — requiredActions setzen (force setup on first login)"
KCID=$(kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$KC_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh get users -r kubernetes -q username=$USERNAME --fields id 2>&1 | grep '\"id\"' | head -1 | cut -d'\"' -f4
")

if [ -z "$KCID" ]; then
  echo "  ✗ User noch nicht in KC — Federation-Sync warten + Script nochmal laufen lassen"
  exit 1
fi
echo "  KC user ID: $KCID"

kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$KC_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh update users/$KCID -r kubernetes -s 'requiredActions=[\"UPDATE_PASSWORD\",\"CONFIGURE_TOTP\",\"VERIFY_EMAIL\"]'
" 2>&1 | head -2

echo
echo "→ Step 4: KC — Welcome-Email senden"
kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$KC_PASS' >/dev/null 2>&1
/opt/keycloak/bin/kcadm.sh update users/$KCID/execute-actions-email -r kubernetes \
  -s 'lifespan=43200' \
  -b '[\"UPDATE_PASSWORD\",\"CONFIGURE_TOTP\",\"VERIFY_EMAIL\"]'
" 2>&1 | head -3

echo
echo "═════════════════════════════════════════════════════════"
echo "  ✓ Onboarding Complete"
echo "═════════════════════════════════════════════════════════"
echo "  Username:    $USERNAME"
echo "  Email:       $EMAIL"
echo "  Groups:      $GROUPS"
echo "  Login URL:   https://argo.timourhomelab.org (oder grafana, drova, ...)"
echo "  Account:     https://iam.timourhomelab.org/realms/kubernetes/account/"
echo
echo "  Email an $EMAIL gesendet → 12h gültig → klickt Link → führt durch:"
echo "    1. Passwort setzen"
echo "    2. TOTP-App scannen"
echo "    3. Email verifizieren"
