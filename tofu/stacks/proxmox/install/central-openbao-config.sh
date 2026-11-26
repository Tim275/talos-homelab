#!/bin/bash
# Run on msa2 after central-openbao.sh, once per cluster: STAGE=prod or STAGE=staging.
# Expects that cluster's service account signing keys (kubectl get --raw /openid/v1/jwks, as PEM)
# at /root/cluster-sa-pubkeys.pem on msa2. Each cluster reads only kv/<env>/.
set -euo pipefail

id=1060
stage=${STAGE:?STAGE=prod or STAGE=staging}
issuer=${ISSUER:-https://192.168.0.100:6443}
pct push "$id" /root/cluster-sa-pubkeys.pem /root/cluster-sa-pubkeys.pem --perms 600

pct exec "$id" -- env STAGE="$stage" ISSUER="$issuer" bash -s <<'INNER'
set -euo pipefail
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME=bao.timourhomelab.org
BAO_TOKEN=$(jq -r .root_token /root/init.json)
export BAO_TOKEN

bao secrets list -format=json | jq -e '."kv/"' >/dev/null || bao secrets enable -path=kv -version=2 kv
bao auth list -format=json | jq -e ".\"k8s-$STAGE/\"" >/dev/null || bao auth enable -path="k8s-$STAGE" jwt

bao write "auth/k8s-$STAGE/config" \
  bound_issuer="$ISSUER" \
  jwt_validation_pubkeys=@/root/cluster-sa-pubkeys.pem >/dev/null

bao policy write "seed-$STAGE" - <<POLICY
path "kv/data/$STAGE/*" {
  capabilities = ["read"]
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

bao read -format=json sys/auth | jq -c '[keys[] | select(test("/$"))]'
bao policy list | tr '\n' ' '; echo
INNER
