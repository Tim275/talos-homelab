#!/bin/sh
set -eu
: "${ACTION:?}" "${CUSTOMER:?}"

CUSTOMER=$(printf '%s' "$CUSTOMER" | tr '[:upper:]' '[:lower:]')
echo "$CUSTOMER" | LC_ALL=C grep -Eq '^[a-z]{1,5}[0-9]{2,12}$' || { echo "customer number invalid: $CUSTOMER"; exit 1; }
ADDRESS=$(printf '%s' "${ADDRESS:-}" | tr '[:upper:]' '[:lower:]')
if [ "$ACTION" = create ] || [ "$ACTION" = invite ]; then
  echo "$ADDRESS" | LC_ALL=C grep -Eq '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' || { echo "address invalid: $ADDRESS"; exit 1; }
fi
SERVICES=$(printf '%s' "${SERVICES:-}" | tr '[:upper:],' '[:lower:] ' | xargs -n1 | sort -u)
# the address never appears in the workflow file or its env, so the log cannot print it
EMAIL=$(jq -r '.inputs.email // ""' "$GITHUB_EVENT_PATH" | tr '[:upper:]' '[:lower:]')
[ -z "$EMAIL" ] || echo "::add-mask::$EMAIL"

KC=${KC:-http://keycloak-service.keycloak.svc.cluster.local:8080}
REALM=customers
domain=$(sed -n 's/^  domain: //p' kubernetes/platform/automation/crossplane/overlays/prod/environment.yaml)

if [ "$ACTION" = create ] || [ "$ACTION" = invite ]; then
  [ -n "$ADDRESS" ] && [ -n "$SERVICES" ] || { echo "address and services are needed to invite"; exit 1; }
  echo "$EMAIL" | LC_ALL=C grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$' || { echo "email missing or invalid"; exit 1; }
  for s in $SERVICES; do
    url=https://$ADDRESS-$s.$domain/healthz
    tries=0
    until curl -sf -o /dev/null --max-time 10 "$url"; do
      tries=$((tries + 1))
      [ $tries -lt 60 ] || { echo "$url did not answer within 30 minutes, run the workflow again with action invite once the order is live"; exit 1; }
      sleep 30
    done
  done
fi

secret=${CLIENT_SECRET:-}
if [ -z "$secret" ]; then
  sa=/var/run/secrets/kubernetes.io/serviceaccount
  secret=$(curl -sSf --cacert $sa/ca.crt -H "Authorization: Bearer $(cat $sa/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/keycloak/secrets/keycloak-customer-invite-client-secret | jq -r .data.clientSecret | base64 -d)
fi
[ -n "$secret" ] || { echo "client secret of customer-invite not readable"; exit 1; }
echo "::add-mask::$secret"
token=$(curl -sSf -d grant_type=client_credentials -d client_id=customer-invite --data-urlencode "client_secret=$secret" \
  "$KC/realms/$REALM/protocol/openid-connect/token" | jq -r .access_token)
[ -n "$token" ] && [ "$token" != null ] || { echo "login as customer-invite failed"; exit 1; }
echo "::add-mask::$token"

api() {
  method=$1 path=$2
  shift 2
  curl -sSf -X "$method" -H "Authorization: Bearer $token" -H "Content-Type: application/json" "$KC/admin/realms/$REALM$path" "$@"
}
group_id() {
  api GET /groups -G --data-urlencode "search=$CUSTOMER" --data-urlencode exact=true | jq -r --arg n "$CUSTOMER" '.[] | select(.name == $n) | .id'
}
set_enabled() {
  api PUT "/users/$1" -d "$(api GET "/users/$1" | jq -c --argjson e "$2" '.enabled = $e')"
}

gid=$(group_id)

members() {
  api GET "/groups/$gid/members?max=1000" | jq -r '.[].id'
}

case $ACTION in
  cancel|resume)
    [ -n "$gid" ] || { echo "no group $CUSTOMER, nothing to change"; exit 0; }
    enable=true
    [ "$ACTION" = cancel ] && enable=false
    count=0
    for id in $(members); do
      set_enabled "$id" "$enable"
      [ "$enable" = true ] || api POST "/users/$id/logout"
      count=$((count + 1))
    done
    echo "$ACTION: $count users of $CUSTOMER, enabled=$enable" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
    exit 0
    ;;
  delete)
    [ -n "$gid" ] || { echo "no group $CUSTOMER, nothing to delete"; exit 0; }
    deleted=0 kept=0
    for id in $(members); do
      if [ "$(api GET "/users/$id/groups" | jq 'length')" -le 1 ]; then
        api DELETE "/users/$id"
        deleted=$((deleted + 1))
      else
        api DELETE "/users/$id/groups/$gid"
        kept=$((kept + 1))
      fi
    done
    echo "delete: $deleted users of $CUSTOMER removed, $kept kept for other customers" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
    exit 0
    ;;
esac

[ -n "$gid" ] || { echo "group $CUSTOMER missing in realm $REALM, is the order synced?"; exit 1; }
user_id() {
  api GET /users -G --data-urlencode "email=$EMAIL" --data-urlencode exact=true | jq -r '.[0].id // empty'
}
uid=$(user_id)
if [ -z "$uid" ]; then
  api POST /users -d "$(jq -cn --arg e "$EMAIL" '{username: $e, email: $e, enabled: true}')"
  uid=$(user_id)
else
  set_enabled "$uid" true
fi
api PUT "/users/$uid/groups/$gid"
service=$(printf '%s\n' $SERVICES | head -1)
redirect=$(jq -rn --arg u "https://$ADDRESS-$service.$domain/" '$u | @uri')
api PUT "/users/$uid/execute-actions-email?client_id=$service-$CUSTOMER&redirect_uri=$redirect" -d '["VERIFY_EMAIL","UPDATE_PASSWORD","CONFIGURE_TOTP"]'
echo "invitation sent for $CUSTOMER" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
