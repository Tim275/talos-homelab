# Keycloak OIDC Provider

## Overview

Enterprise identity platform with social login, advanced MFA, and user management.

**Location**: `platform/identity/keycloak/`
**Exposed**: `iam.timourhomelab.org`

## Architecture

```
Keycloak 25.0.0 (OIDC/SAML provider)
└── PostgreSQL 16 (CloudNativePG, 10Gi Ceph storage)
└── Gateway API (Envoy Gateway TLS termination)
```

**Resources:**
- CPU: 500m request, 2000m limit
- Memory: 1024Mi request, 2048Mi limit

## Why Keycloak?

**vs Authelia:**
- ✅ Social login (Google, GitHub, Microsoft, Facebook)
- ✅ User management UI (admin console)
- ✅ Advanced MFA (TOTP, WebAuthn, SMS)
- ✅ Identity brokering (SAML, OIDC federation)

**Use together:**
- Authelia: Internal services, lightweight
- Keycloak: User-facing apps, complex auth flows

## Authentication Methods

1. **LLDAP Federation**: Connect to LLDAP user directory
2. **Social Login**: Google, GitHub, Microsoft, Facebook, Apple
3. **MFA**: Google Authenticator, YubiKey, SMS, Email OTP
4. **Enterprise**: SAML, Active Directory, Kerberos

## Critical Configuration

### Cookie Fix (REQUIRED)

```yaml
args:
- --spi-sticky-session-encoder-infinispan-should-attach-route=false
```

**Why**: Default Keycloak attaches node-id to cookies → breaks reverse proxy → "Cookie not found" error.

### PostgreSQL Connection

```yaml
KC_DB_URL: jdbc:postgresql://keycloak-db-rw.keycloak.svc.cluster.local:5432/keycloak
KC_DB_USERNAME: keycloak (from sealed secret)
KC_DB_PASSWORD: <sealed> (from sealed secret)
```

## Deployment

### Check Status

```bash
# PostgreSQL cluster
kubectl get cluster -n keycloak keycloak-db

# Keycloak pod
kubectl get pods -n keycloak -w
```

### Access Admin Console

```bash
# Port-forward
kubectl port-forward -n keycloak svc/keycloak 8090:8080

# Open: http://localhost:8090
# Login: admin / <sealed-secret-password>
```

## Configuration

### 1. Create Realm

1. Admin console → Hover "Master" → "Create Realm"
2. Name: `homelab`
3. Click "Create"

### 2. OIDC Clients

**Grafana:**
- Client ID: `grafana`
- Access Type: `confidential`
- Valid Redirect URIs: `https://grafana.timourhomelab.org/*`

**ArgoCD:**
- Client ID: `argocd`
- Access Type: `confidential`
- Valid Redirect URIs: `https://argocd.timourhomelab.org/auth/callback`

**Kubernetes:**
- Client ID: `kubernetes`
- Access Type: `public`
- Valid Redirect URIs: `http://localhost:*`

### 3. LLDAP Federation (Optional)

```
User Federation → Add LDAP Provider
Connection URL: ldap://lldap.lldap.svc.cluster.local:3890
Bind DN: uid=admin,ou=people,dc=timourhomelab,dc=org
Users DN: ou=people,dc=timourhomelab,dc=org
Test connection → Synchronize users
```

### 4. Social Login (Optional)

**Google:**
1. Get OAuth credentials: https://console.cloud.google.com
2. Identity Providers → Add provider → Google
3. Enter Client ID + Secret

**GitHub:**
1. Get OAuth App: https://github.com/settings/developers
2. Identity Providers → Add provider → GitHub
3. Enter Client ID + Secret

## Troubleshooting

### Cookie Not Found Error

**Check deployment has cookie fix:**
```bash
kubectl get deployment -n keycloak keycloak -o yaml | grep should-attach-route
```

### Database Connection Issues

```bash
# Check PostgreSQL
kubectl get pods -n keycloak -l cnpg.io/cluster=keycloak-db
kubectl logs -n keycloak -l cnpg.io/cluster=keycloak-db

# Check credentials secret
kubectl get secret -n keycloak keycloak-db-app
```

### Slow Startup

Keycloak takes 30-90 seconds to initialize with PostgreSQL (expected behavior).

```bash
# Watch logs
kubectl logs -n keycloak -l app.kubernetes.io/name=keycloak --tail=100 -f
```

## Status

- ✅ PostgreSQL cluster configured (single instance, 10Gi)
- ✅ Keycloak deployment with production fixes
- ✅ Database credentials sealed secret
- ✅ Gateway HTTPRoute configured
- ⏳ Ready to deploy via ArgoCD
