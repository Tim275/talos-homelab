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
-  Social login (Google, GitHub, Microsoft, Facebook)
-  User management UI (admin console)
-  Advanced MFA (TOTP, WebAuthn, SMS)
-  Identity brokering (SAML, OIDC federation)

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

-  PostgreSQL cluster configured (single instance, 10Gi)
-  Keycloak deployment with production fixes
-  Database credentials sealed secret
-  Gateway HTTPRoute configured
-  Google OAuth + MFA configured
-  LDAP User Federation configured
-  Authelia replaced (disabled in kustomization.yaml)

---

##  Enterprise Identity Architecture (Production 2025)

### Overview

**Keycloak as Central Identity Provider** replacing Authelia for simplified, enterprise-grade authentication.

```
┌─────────────────────────────────────────┐
│  LLDAP (Central User Database)          │
│  └─ dc=homelab,dc=local                 │
│     └─ Users: ou=people                 │
│     └─ Groups: ou=groups                │
└─────────────────────────────────────────┘
                ↑
                │ (LDAP Federation - WRITABLE)
                │
┌─────────────────────────────────────────┐
│  Keycloak (Central Identity Provider)   │
│  ├─ Google OAuth                       │
│  ├─ MFA/2FA (TOTP)                     │
│  ├─ LDAP User Federation               │
│  └─ OIDC Provider for:                  │
│     ├─ kubectl (kubernetes realm)       │
│     ├─ Grafana                          │
│     ├─ N8N                              │
│     ├─ Hubble                           │
│     └─ All apps                         │
└─────────────────────────────────────────┘
```

### Why This Architecture?

**Keycloak vs Authelia:**
-  **Keycloak**: Enterprise IAM, OAuth/OIDC/SAML, LDAP Federation, Social Login, Scalable
-  **Authelia**: Lightweight reverse proxy auth, no LDAP write, limited to home labs

**Benefits:**
1. **One Login for Everything** - Google OAuth → Keycloak → All Apps
2. **Central User Database** - LDAP as single source of truth
3. **MFA Everywhere** - Google Authenticator enforced for all users
4. **Less Complexity** - Single identity provider instead of Authelia + Keycloak

---

##  LDAP User Federation Setup

### Architecture

Keycloak connects to LLDAP as **WRITABLE** federation:
- **Users sync**: LDAP → Keycloak (read)
- **Google OAuth users**: Keycloak → LDAP (write!)
- **Groups sync**: LDAP Groups → Keycloak Roles

### Configuration

**Connection:**
```yaml
URL: ldap://lldap-ldap.lldap.svc.cluster.local:389
Base DN: dc=homelab,dc=local
Users DN: ou=people,dc=homelab,dc=local
Groups DN: ou=groups,dc=homelab,dc=local
Bind DN: uid=admin,ou=people,dc=homelab,dc=local
Edit Mode: WRITABLE  #  Google OAuth users sync to LDAP!
Sync Period: 86400s (24 hours)
```

**Mappers:**
-  **Group Mapper**: LDAP Groups → Keycloak Roles
-  **Email Mapper**: mail → email
-  **First Name Mapper**: givenName → firstName
-  **Last Name Mapper**: sn → lastName

### Deploy LDAP Federation

```bash
# Deploy the LDAP federation setup job
kubectl apply -f kubernetes/80-identity/keycloak/base/ldap-federation-setup.yaml

# Wait for job completion
kubectl wait --for=condition=complete --timeout=120s job/keycloak-ldap-federation-setup -n keycloak

# Check logs
kubectl logs -n keycloak job/keycloak-ldap-federation-setup

# Verify LDAP sync worked
# 1. Check Keycloak Admin Console → User Federation
# 2. Check LLDAP UI: http://lldap:17170
```

### s (2025 Production)

Based on industry standards:

1. **Edit Mode = WRITABLE** 
   - Google OAuth users automatically sync to LDAP
   - One user database for all apps

2. **Periodic Sync = 86400s (24h)** 
   - Changed users sync only (efficient)
   - On-demand sync available via API

3. **Password Validation = LDAP Server** 
   - Keycloak NEVER imports passwords
   - Security best practice

4. **Trust Email = true** 
   - Emails from LDAP are pre-verified
   - No email verification needed for LDAP users

---

##  Google OAuth + MFA Setup

### Architecture

**Double-Layer 2FA Protection:**

```
User → Google OAuth Login
  ↓ (Layer 1: Google's own 2FA)
User → Keycloak MFA Setup
  ↓ (Layer 2: Google Authenticator OTP)
User → LDAP Sync
  ↓ (User now in LDAP database)
User → Access all apps
```

### Google OAuth Setup

**1. Create Google Cloud OAuth Client:**

```
Google Cloud Console → APIs & Services → Credentials
→ Create OAuth 2.0 Client ID

Application Type: Web Application
Authorized JavaScript origins: https://iam.timourhomelab.org
Authorized redirect URIs: https://iam.timourhomelab.org/realms/kubernetes/broker/google/endpoint

Result:
- Client ID: 540167708145-q1af7j65jecufoui2khqvtjkv1fvl5te.apps.googleusercontent.com
- Client Secret: GOCSPX-...
```

**2. Create SealedSecret:**

```bash
kubectl create secret generic keycloak-google-oauth \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET' \
  --namespace keycloak \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller -o yaml \
  > google-oauth-sealed-secret.yaml

kubectl apply -f google-oauth-sealed-secret.yaml
```

**3. Deploy Google OAuth Integration:**

```bash
kubectl apply -f kubernetes/80-identity/keycloak/base/google-oauth-setup.yaml
kubectl logs -n keycloak job/keycloak-google-oauth-setup
```

### MFA Setup (via Admin Console)

**Required Configuration:**

1. **Authentication Flow**: `Browser with MFA`
   - Keycloak Admin Console → Authentication → Flows
   - Set as default for browser login

2. **Required Action**: `Configure OTP`
   - Keycloak Admin Console → Authentication → Required Actions
   - Enable "Configure OTP" as default

3. **Test**:
   - New user logs in → MUST setup Google Authenticator
   - Existing user logs in → MUST setup Google Authenticator on first login

---

##  Migration from Authelia

### What We Did

**1. Disabled Authelia:**
```yaml
# platform/identity/kustomization.yaml
# - authelia/application.yaml  # DISABLED: Replaced by Keycloak
```

**2. Apps Now Use Keycloak OIDC:**
- Grafana → Keycloak OIDC
- N8N → Keycloak OIDC
- Hubble → Keycloak OIDC
- kubectl → Keycloak OIDC (kubernetes realm)

**3. Central User Database:**
- LLDAP = Single source of truth
- Keycloak syncs to/from LDAP
- Google OAuth users auto-sync to LDAP

### Migration Steps

**If you want to re-enable Authelia (not recommended):**

```bash
# Uncomment in kustomization
# platform/identity/kustomization.yaml:
#   - authelia/application.yaml

# ArgoCD will automatically redeploy
```

**To fully remove Authelia:**

```bash
# Delete namespace (optional)
kubectl delete namespace authelia
```

---

##  Testing & Verification

### Test LDAP Federation

```bash
# 1. Check Keycloak User Federation
kubectl port-forward -n keycloak svc/keycloak 8080:8080
# Open: http://localhost:8080
# Login: admin / <keycloak-admin-password>
# Navigate: User Federation → lldap-federation
# Click: Sync all users

# 2. Check LLDAP has users
kubectl port-forward -n lldap svc/lldap 17170:17170
# Open: http://localhost:17170
# Login: admin / <lldap-admin-password>
# Check: Users tab → Should see Keycloak users

# 3. Test Google OAuth login
# Open: https://iam.timourhomelab.org/realms/kubernetes/account/
# Click: "Sign in with Google"
# Complete: Google login + MFA setup
# Result: User appears in LLDAP!
```

### Test kubectl OIDC

```bash
# Clear OIDC cache
rm -rf ~/.kube/cache/oidc-login/

# Login via Google OAuth + MFA
kubectl get nodes
# → Browser opens
# → Google login
# → MFA setup (if first time)
# → Token cached
# → kubectl works!

# Check token
kubectl oidc-login get-token \
  --oidc-issuer-url=https://iam.timourhomelab.org/realms/kubernetes \
  --oidc-client-id=kubectl
```

---

## 📁 Files Reference

```
infrastructure/authentication/keycloak/
├── google-oauth-sealed-secret.yaml          # Google OAuth credentials (encrypted)
├── google-oauth-setup.yaml                  # Google OAuth setup job (FIXED!)
├── ldap-federation-setup.yaml               # LDAP federation setup job (NEW!)
├── realm-export-job.yaml                    # Backup job for realm config
├── kubernetes-realm-backup.json             # MFA config backup (135 lines)
├── kubernetes-realm-backup-with-google-oauth.json  # Full backup (181 lines)
└── README.md                                # This file
```

---

##  Production Checklist

-  **LDAP Federation**: Keycloak ↔ LLDAP sync enabled
-  **Google OAuth**: Social login configured
-  **MFA/2FA**: TOTP enforced for all users
-  **kubectl OIDC**: Kubernetes authentication working
-  **Authelia**: Disabled (replaced by Keycloak)
-  **Realm Backup**: Automated export job configured
-  **GitOps**: All credentials encrypted with SealedSecrets
