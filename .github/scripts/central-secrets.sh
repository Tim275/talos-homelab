#!/bin/bash
# Loads the secrets of one pipeline into the job environment.
# Runs on main: from the central OpenBao with the job's ID token. Pull requests: from PR_* (GitHub secrets).
# Field tf_encryption becomes TF_ENCRYPTION, every other field TF_VAR_<field>.
set -euo pipefail

name="$1"
addr=https://192.168.0.60:8200

put() {
  local key="$1" value="$2" line delim
  while IFS= read -r line; do
    [ "${#line}" -ge 6 ] && echo "::add-mask::$line"
  done <<<"$value"
  delim="EOF_$(openssl rand -hex 8)"
  printf '%s<<%s\n%s\n%s\n' "$key" "$delim" "$value" "$delim" >>"$GITHUB_ENV"
}

if [ -n "${PR_TF_ENCRYPTION:-}" ]; then
  put TF_ENCRYPTION "$PR_TF_ENCRYPTION"
  env | grep -o '^PR_TF_VAR_[A-Za-z0-9_]*' | while read -r k; do put "${k#PR_}" "${!k}"; done
  exit 0
fi

jwt=$(curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=central-openbao" | jq -r .value)
token=$(jq -n --arg jwt "$jwt" '{role: "tofu-prod", jwt: $jwt}' |
  curl -fsS -X POST "$addr/v1/auth/github/login" -d @- | jq -r .auth.client_token)
echo "::add-mask::$token"

data=$(curl -fsS -H "X-Vault-Token: $token" "$addr/v1/kv/data/prod/pipeline/$name" | jq -c .data.data)
for field in $(jq -r 'keys[]' <<<"$data"); do
  value=$(jq -r --arg f "$field" '.[$f]' <<<"$data")
  if [ "$field" = tf_encryption ]; then put TF_ENCRYPTION "$value"; else put "TF_VAR_$field" "$value"; fi
done
curl -fsS -X POST -H "X-Vault-Token: $token" "$addr/v1/auth/token/revoke-self" -o /dev/null || true
echo "secrets for $name loaded: $(jq -r 'keys | length' <<<"$data")"
