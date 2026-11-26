#!/bin/bash
# Run on msa2 after central-openbao.sh, once per cluster: STAGE=prod or STAGE=staging.
# Expects that cluster's service account signing keys (kubectl get --raw /openid/v1/jwks, as PEM)
# at /root/cluster-sa-pubkeys.pem on msa2. Each cluster reads only kv/<env>/.
# Authenticates with BAO_TOKEN if set (admin login), otherwise with the initial root token.
set -euo pipefail

id=1060
stage=${STAGE:?STAGE=prod or STAGE=staging}
issuer=${ISSUER:-https://192.168.0.100:6443}
pct push "$id" /root/cluster-sa-pubkeys.pem /root/cluster-sa-pubkeys.pem --perms 600

pct exec "$id" -- env STAGE="$stage" ISSUER="$issuer" BAO_TOKEN="${BAO_TOKEN:-}" bash -s <<'INNER'
set -euo pipefail
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME=bao.timourhomelab.org
BAO_TOKEN=${BAO_TOKEN:-$(jq -r .root_token /root/init.json 2>/dev/null)}
[ -n "$BAO_TOKEN" ] || { echo "no token: set BAO_TOKEN from the admin login"; exit 1; }
export BAO_TOKEN

bao policy write admin - <<'POLICY'
path "*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}
POLICY
bao auth list -format=json | jq -e '."userpass/"' >/dev/null || bao auth enable userpass
if ! bao read auth/userpass/users/timour >/dev/null 2>&1; then
  umask 077
  [ -s /root/admin-password ] || openssl rand -base64 32 | tr -d '\n' >/root/admin-password
  bao write auth/userpass/users/timour password=@/root/admin-password \
    token_policies=admin token_ttl=1h token_max_ttl=8h >/dev/null
fi

bao secrets list -format=json | jq -e '."kv/"' >/dev/null || bao secrets enable -path=kv -version=2 kv
bao auth list -format=json | jq -e ".\"k8s-$STAGE/\"" >/dev/null || bao auth enable -path="k8s-$STAGE" jwt

bao write "auth/k8s-$STAGE/config" \
  bound_issuer="$ISSUER" \
  jwt_validation_pubkeys=@/root/cluster-sa-pubkeys.pem >/dev/null

bao policy write "seed-$STAGE" - <<POLICY
path "kv/data/$STAGE/*" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
POLICY

bao policy write "seal-$STAGE" - <<POLICY
path "kv/data/$STAGE/platform/openbao/openbao-seal-key" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
POLICY

bao policy write snapshot - <<'POLICY'
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
POLICY

bao write "auth/k8s-$STAGE/role/external-secrets" \
  role_type=jwt user_claim=sub \
  bound_subject=system:serviceaccount:external-secrets:eso \
  bound_audiences=central-openbao \
  token_policies="seed-$STAGE" token_no_default_policy=true \
  token_ttl=10m token_max_ttl=1h >/dev/null

bao write "auth/k8s-$STAGE/role/openbao-seal" \
  role_type=jwt user_claim=sub \
  bound_subject=system:serviceaccount:openbao:eso \
  bound_audiences=central-openbao \
  token_policies="seal-$STAGE" token_no_default_policy=true \
  token_ttl=10m token_max_ttl=1h >/dev/null

bao auth list -format=json | jq -e '."github/"' >/dev/null || bao auth enable -path=github jwt
bao write auth/github/config \
  oidc_discovery_url=https://token.actions.githubusercontent.com \
  bound_issuer=https://token.actions.githubusercontent.com >/dev/null

bao policy write "pipeline-$STAGE" - <<POLICY
path "kv/data/$STAGE/pipeline/*" {
  capabilities = ["read"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
POLICY

jq -n --arg stage "$STAGE" '{
  role_type: "jwt", user_claim: "sub", bound_audiences: ["central-openbao"],
  bound_claims: {
    repository_id: "1461209908",
    sub: ["repo:Tim275@117520669/talos-homelab@1461209908:ref:refs/heads/main",
          "repo:Tim275@117520669/talos-homelab@1461209908:environment:tofu-apply"]
  },
  token_policies: ["pipeline-\($stage)"], token_no_default_policy: true,
  token_ttl: "15m", token_max_ttl: "1h"
}' | bao write "auth/github/role/tofu-$STAGE" - >/dev/null

bao read -format=json sys/auth | jq -c '[keys[] | select(test("/$"))]'
bao policy list | tr '\n' ' '; echo
INNER
