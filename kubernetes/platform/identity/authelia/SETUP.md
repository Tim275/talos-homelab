# Authelia OIDC Setup Guide

Complete setup instructions for Authelia with LLDAP backend and OIDC support.

## 🔧 Prerequisites

1. **LLDAP deployed** and running
2. **Sealed Secrets Controller** deployed
3. **Admin credentials** from LLDAP

## 📋 Step-by-Step Setup

### Step 1: Generate RSA Private Key (REQUIRED for JWT signing)

```bash
# Generate 4096-bit RSA private key for JWT signing
openssl genrsa -out rsa-private.pem 4096

# Verify the key
openssl rsa -in rsa-private.pem -text -noout | head -20
```

### Step 2: Generate OIDC Client Secrets

```bash
# Generate random client secrets
KUBERNETES_SECRET="k8s-$(openssl rand -hex 16)"
ARGOCD_SECRET="argo-$(openssl rand -hex 16)"

echo "Kubernetes secret: $KUBERNETES_SECRET"
echo "ArgoCD secret: $ARGOCD_SECRET"

# Hash the secrets using Authelia (keep the terminal open for copying)
echo "Hashing Kubernetes secret..."
docker run --rm -it authelia/authelia:4.38.0 authelia crypto hash generate argon2 --password "$KUBERNETES_SECRET"

echo "Hashing ArgoCD secret..."
docker run --rm -it authelia/authelia:4.38.0 authelia crypto hash generate argon2 --password "$ARGOCD_SECRET"
```

### Step 3: Update ConfigMap with Hashed Secrets

Copy the generated hashes and update `configmap.yaml`:

```yaml
# Replace in configmap.yaml:
client_secret: $argon2id$v=19$m=65536,t=3,p=4$YOUR_ACTUAL_HASH_HERE
```

### Step 4: Create and Seal JWK Secret

```bash
# Create the JWK secret with RSA private key
kubectl create secret generic authelia-jwk \
  --from-file=rsa-private.pem=rsa-private.pem \
  --namespace=authelia --dry-run=client -o yaml \
| kubeseal -o yaml > jwk-secret.yaml

# Replace the placeholder in jwk-secret.yaml
```

### Step 5: Create and Seal Main Secrets

```bash
# Generate all required secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
STORAGE_KEY=$(openssl rand -base64 32)
OIDC_HMAC=$(openssl rand -base64 32)
LDAP_PASSWORD="homelab-admin-2024"  # Use your LLDAP admin password

# Create and seal the main secrets
kubectl create secret generic authelia-secrets \
  --from-literal=ldap-password="$LDAP_PASSWORD" \
  --from-literal=session-secret="$SESSION_SECRET" \
  --from-literal=storage-encryption-key="$STORAGE_KEY" \
  --from-literal=oidc-hmac-secret="$OIDC_HMAC" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --namespace=authelia --dry-run=client -o yaml \
| kubeseal -o yaml > sealed-secrets.yaml
```

### Step 6: Deploy Authelia

```bash
# Apply the complete configuration
kubectl apply -k .

# Check deployment status
kubectl get pods -n authelia
kubectl logs -f deployment/authelia -n authelia
```

### Step 7: Verify OIDC Configuration

```bash
# Port-forward to test
kubectl port-forward svc/authelia 9091:80 -n authelia

# Check OpenID configuration
curl -s http://127.0.0.1:9091/.well-known/openid-configuration | jq

# Check JWKS endpoint
curl -s http://127.0.0.1:9091/jwks.json | jq
```

## 🔗 Integration Examples

### Kubernetes API Server (Talos)

```yaml
# tofu/talos/machine-config/patches/oidc-patch.yaml
cluster:
  apiServer:
    extraArgs:
      oidc-issuer-url: "https://auth.homelab.local"
      oidc-client-id: "kubernetes"
      oidc-username-claim: "preferred_username"
      oidc-groups-claim: "groups"
      oidc-username-prefix: "oidc:"
      oidc-groups-prefix: "oidc:"
```

### ArgoCD Integration

```yaml
# In ArgoCD configuration
oidc.config: |
  name: Authelia
  issuer: https://auth.homelab.local
  clientId: argocd
  clientSecret: $argo-secret-here
  requestedScopes: ["openid", "profile", "email", "groups"]
  requestedIDTokenClaims: {"groups": {"essential": true}}
```

## 🧪 Testing OIDC Flow

### Test with kubectl

```bash
# 1. Get authorization URL
AUTH_URL="http://127.0.0.1:9091/api/oidc/authorization"
AUTH_URL+="?response_type=code"
AUTH_URL+="&client_id=kubernetes"
AUTH_URL+="&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
AUTH_URL+="&scope=openid+profile+groups+email"
AUTH_URL+="&state=$(openssl rand -hex 16)"

echo "Open in browser: $AUTH_URL"

# 2. After authorization, exchange code for tokens using the returned code
# (This requires the client secret and proper PKCE flow)
```

## 🔍 Troubleshooting

### Common Issues

1. **No JWK configured**: Error about missing signing key
   - Solution: Ensure `rsa-private.pem` is properly mounted

2. **OIDC client secret mismatch**: Authentication fails
   - Solution: Verify hashed secrets match generated values

3. **Groups not in ID token**: RBAC mapping fails
   - Solution: Check `claims_policy: legacy` is set

4. **LDAP connection failed**: Can't authenticate users
   - Solution: Verify LLDAP service is accessible

### Debug Commands

```bash
# Check Authelia logs
kubectl logs -f deployment/authelia -n authelia

# Test LDAP connection
kubectl exec -it deployment/authelia -n authelia -- \
  ldapsearch -H ldap://lldap-ldap.lldap.svc.cluster.local:389 \
  -D "uid=admin,ou=people,dc=homelab,dc=local" -W \
  -b "dc=homelab,dc=local" "(objectClass=*)"

# Check mounted secrets
kubectl exec -it deployment/authelia -n authelia -- ls -la /secrets/authelia-jwk/
```

## ✅ Success Criteria

- [ ] Authelia pod running without errors
- [ ] OIDC configuration endpoint accessible
- [ ] JWKS endpoint returns valid RSA public key
- [ ] User can login via web interface
- [ ] OIDC authorization flow works
- [ ] Groups are included in ID tokens
- [ ] Kubernetes API server accepts OIDC tokens (after Talos config)

## 🔄 Next Steps

1. Configure **Talos OIDC** integration (infrastructure layer)
2. Create **RBAC mappings** (security layer)
3. Test **kubectl authentication** with OIDC
4. Configure **ArgoCD SSO** (optional)
5. Add **Ingress/Gateway** for external access