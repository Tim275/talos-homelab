# Backstage Setup-Procedure (manuelle Steps NACH GitOps-Sync)

Backstage braucht 3 Secrets die als SealedSecrets committed werden müssen.
Ohne diese läuft Backstage nicht (CrashLoopBackOff: missing env-var).

## Phase 2 — Secrets erstellen + sealen

### 1. Backstage DB Credentials (CNPG-generated, kopieren)

CNPG generiert beim ersten Start ein Secret `backstage-db-credentials`.
Backstage erwartet ENV `username` + `password`. ✓ kompatibel.

Wenn Cluster created: kein Sealed-Secret nötig. CNPG handled.

### 2. GitHub PAT (für catalog-info-import + repo-discovery)

Generate Personal-Access-Token:
- https://github.com/settings/tokens
- Scopes: `repo` (read-only), `read:org`, `read:user`
- Save in 1Password

Seal:
```bash
CERT=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt
NS=backstage

kubectl create secret generic backstage-github-token \
  --namespace=$NS \
  --from-literal=GITHUB_TOKEN="<your-PAT>" \
  --dry-run=client -o yaml | \
kubeseal --cert "$CERT" --format yaml --scope strict \
  > kubernetes/platform/developer-platform/backstage/base/backstage-github-token-sealed.yaml
```

Add to kustomization.yaml + commit.

### 3. Backstage OIDC Client-Secret (Keycloak)

Manuell in KC-Realm "kubernetes" erstellen:

```bash
ADMIN_PASS=$(kubectl get secret -n keycloak keycloak-admin -o jsonpath='{.data.password}' | base64 -d)
SECRET=$(openssl rand -hex 32)

kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master \
  --user admin --password '$ADMIN_PASS' >/dev/null 2>&1

/opt/keycloak/bin/kcadm.sh create clients -r kubernetes \
  -s clientId=backstage \
  -s 'name=Backstage Developer Portal' \
  -s enabled=true \
  -s clientAuthenticatorType=client-secret \
  -s secret='$SECRET' \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s 'rootUrl=https://backstage.timourhomelab.org' \
  -s 'redirectUris=[\"https://backstage.timourhomelab.org/api/auth/oidc/handler/frame\"]' \
  -s 'webOrigins=[\"+\"]'
"
echo "Save in 1Password: $SECRET"
```

Plus default-client-scopes attachen:

```bash
kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password '$ADMIN_PASS' >/dev/null 2>&1
CID=\$(/opt/keycloak/bin/kcadm.sh get clients -r kubernetes -q clientId=backstage --fields id 2>&1 | grep '\"id\"' | cut -d'\"' -f4)
for SCOPE in profile email web-origins acr basic roles groups; do
  SID=\$(/opt/keycloak/bin/kcadm.sh get client-scopes -r kubernetes 2>&1 | grep -B1 \"\\\"name\\\" : \\\"\$SCOPE\\\"\" | grep '\"id\"' | head -1 | cut -d'\"' -f4)
  /opt/keycloak/bin/kcadm.sh update \"clients/\$CID/default-client-scopes/\$SID\" -r kubernetes >/dev/null
done
"
```

Seal client-secret:
```bash
kubectl create secret generic backstage-oidc-credentials \
  --namespace=backstage \
  --from-literal=BACKSTAGE_OIDC_CLIENT_SECRET="$SECRET" \
  --dry-run=client -o yaml | \
kubeseal --cert "$CERT" --format yaml --scope strict \
  > kubernetes/platform/developer-platform/backstage/base/backstage-oidc-credentials-sealed.yaml
```

### 4. ArgoCD Token + ServiceAccount-Token

Für Backstage-Plugin "argocd" + "kubernetes" — beides als Secret-refs.

ArgoCD-Token via API:
```bash
ARGOCD_PASS=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
TOKEN=$(curl -sk -X POST https://argo.timourhomelab.org/api/v1/session \
  -d "{\"username\":\"admin\",\"password\":\"$ARGOCD_PASS\"}" | jq -r .token)
# Im app-config.yaml als ARGOCD_PASSWORD
```

Kubernetes SA-Token: in Backstage-NS ein read-only-SA erstellen + Token-Secret.

### 5. Cloudflare Tunnel Hostname

CF-Dashboard → Tunnels → talos-homelab → Add Hostname:
- Subdomain: `backstage`
- Service: `https://envoy-gateway-envoy-gateway-XXX.gateway.svc.cluster.local:443`

### 6. Final: Kustomization Sealed-Refs einkommentieren + push

```bash
# In kustomization.yaml die 3 sealed-secret-Files unkommentieren
# Dann:
git add kubernetes/platform/developer-platform/backstage/
git commit -m "backstage secrets sealed"
git push
```

ArgoCD synct → Backstage Pod Running → https://backstage.timourhomelab.org → KC-Login.

## Phase 3+ — Plugins, Service-Catalog

Das ist iterativ, sieh CLAUDE.md (kommt noch) für Details.
