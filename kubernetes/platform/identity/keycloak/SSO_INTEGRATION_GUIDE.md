# 🔐 Enterprise SSO Integration Guide
## IKEA-Style Step-by-Step Anleitung

**Status**: ✅ Production-Ready
**Date**: 2025-10-31
**Goal**: Single Sign-On (SSO) für alle Kubernetes Apps mit Keycloak + LLDAP

---

## 📖 Table of Contents

1. [Warum LLDAP + Keycloak?](#warum-lldap--keycloak)
2. [Architecture](#architecture)
3. [ArgoCD OIDC Integration (IKEA-Style)](#argocd-oidc-integration-ikea-style)
4. [Troubleshooting](#troubleshooting)
5. [Testing](#testing)
6. [Next Apps](#next-apps)

---

## 🤔 Warum LLDAP + Keycloak?

### Das Problem ohne SSO

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   ArgoCD    │    │   Grafana   │    │  Keycloak   │
│  Username:  │    │  Username:  │    │  Username:  │
│  Password:  │    │  Password:  │    │  Password:  │
└─────────────┘    └─────────────┘    └─────────────┘
     ❌                  ❌                  ❌
Jede App braucht eigene User/Pass → Viele Passwörter → Unsicher!
```

### Die Lösung: LLDAP + Keycloak

```
┌──────────────────────────────────────────────────────────┐
│                    🎯 Single Sign-On                     │
│                                                           │
│  1 Login für ALLE Apps! ✅                               │
│  ┌─────────────────────────────────────────┐             │
│  │  User login bei Keycloak                │             │
│  │  ↓                                       │             │
│  │  Keycloak gibt Token                    │             │
│  │  ↓                                       │             │
│  │  Alle Apps nutzen diesen Token          │             │
│  └─────────────────────────────────────────┘             │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │ ArgoCD   │  │ Grafana  │  │ Hubble   │               │
│  │    ✅    │  │    ✅    │  │    ✅    │               │
│  └──────────┘  └──────────┘  └──────────┘               │
└──────────────────────────────────────────────────────────┘
```

### Warum 2 Komponenten?

**LLDAP** (User Directory):
- **Was**: Leichtgewichtige LDAP-Datenbank
- **Warum**: Speichert alle User zentral (IaC-Style!)
- **Beispiel**: `admin`, `tim275` existieren in LLDAP

**Keycloak** (Identity Provider):
- **Was**: OIDC/OAuth2 Server
- **Warum**: Macht Login/Token Management für Apps
- **Beispiel**: ArgoCD fragt Keycloak "Ist dieser User OK?" → Keycloak prüft LLDAP

```
┌─────────────────────────────────────────────────────┐
│                    Das Team                         │
│                                                     │
│  LLDAP           Keycloak           Apps           │
│  (User DB)   →   (Identity)    →   (Consumer)     │
│                                                     │
│  admin           "Is admin OK?"     ArgoCD         │
│  tim275     ←    "Yes! Here's      Grafana        │
│  users           token for admin"   Hubble         │
└─────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

### Gesamtarchitektur

```
┌───────────────────────────────────────────────────────────────┐
│                    🌐 User Browser                            │
└───────────┬───────────────────────────────────────────────────┘
            │
            │ 1. User öffnet ArgoCD
            ▼
┌───────────────────────────────────────────────────────────────┐
│                   🚀 ArgoCD                                   │
│   https://argo.timourhomelab.org                             │
└───────────┬───────────────────────────────────────────────────┘
            │
            │ 2. Redirect zu Keycloak
            ▼
┌───────────────────────────────────────────────────────────────┐
│                   🔐 Keycloak                                 │
│   https://iam.timourhomelab.org/realms/kubernetes           │
│                                                               │
│   ┌─────────────────────────────────────────┐               │
│   │  Login Screen                            │               │
│   │  - Username: tim275                      │               │
│   │  - Password: ********                    │               │
│   │  - MFA Code (optional): 123456          │               │
│   └─────────────────────────────────────────┘               │
└───────────┬───────────────────────────────────────────────────┘
            │
            │ 3. Keycloak prüft bei LLDAP
            ▼
┌───────────────────────────────────────────────────────────────┐
│                   📚 LLDAP                                    │
│   lldap.lldap.svc.cluster.local:389                          │
│                                                               │
│   Users:                                                      │
│   - admin (cluster-admins)                                   │
│   - tim275 (cluster-admins, argocd-admins)                   │
│   - ci-user (ci-runners)                                     │
└───────────┬───────────────────────────────────────────────────┘
            │
            │ 4. ✅ User valid! Return to ArgoCD with token
            ▼
┌───────────────────────────────────────────────────────────────┐
│                   🚀 ArgoCD (Logged In!)                      │
│   User: tim275                                                │
│   Role: Admin (from groups claim)                            │
└───────────────────────────────────────────────────────────────┘
```

---

## 🛠️ ArgoCD OIDC Integration (IKEA-Style)

### Was du brauchst (Teile-Liste)

- ✅ Keycloak deployed (`keycloak` namespace)
- ✅ LLDAP deployed (`lldap` namespace)
- ✅ ArgoCD deployed (`argocd` namespace)
- ✅ kubectl access
- ✅ 15 Minuten Zeit

---

### 📦 SCHRITT 1: Keycloak Client erstellen

**Ziel**: ArgoCD als OIDC Client in Keycloak registrieren

#### 1.1 Keycloak Admin öffnen

```bash
# In Browser öffnen
https://iam.timourhomelab.org

# Login:
Username: admin
Password: [kubectl get secret keycloak-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d]
```

#### 1.2 ArgoCD Client erstellen

```
┌─────────────────────────────────────────────────────────┐
│  Keycloak Admin Console                                 │
│                                                          │
│  1. Wähle Realm: "kubernetes" (oben links)              │
│  2. Klick: "Clients" (linkes Menu)                      │
│  3. Klick: "Create client"                              │
└─────────────────────────────────────────────────────────┘
```

**General Settings**:
```yaml
Client type: OpenID Connect
Client ID: argocd
Name: ArgoCD
Description: ArgoCD GitOps Platform
```
→ Click "Next"

**Capability config**:
```yaml
Client authentication: ON  ✅
Authorization: OFF
Authentication flow:
  ✅ Standard flow
  ✅ Direct access grants
  ❌ Implicit flow
  ❌ Service accounts roles
```
→ Click "Next"

**Login settings**:
```yaml
Root URL: https://argo.timourhomelab.org
Valid redirect URIs:
  - https://argo.timourhomelab.org/auth/callback
  - https://argo.timourhomelab.org/api/dex/callback
Web origins: https://argo.timourhomelab.org
```
→ Click "Save"

#### 1.3 Client Secret kopieren

```
┌─────────────────────────────────────────────────────────┐
│  Client: argocd                                          │
│                                                          │
│  1. Tab: "Credentials"                                  │
│  2. Copy "Client secret"                                │
│     Beispiel: xMkH6QRqgntm1BTq3ah5xWAlUJUZJfbN          │
│                                                          │
│  ⚠️ WICHTIG: Diese Secret brauchst du gleich!           │
└─────────────────────────────────────────────────────────┘
```

---

### 🔗 SCHRITT 2: Groups Scope hinzufügen

**Ziel**: Keycloak soll Gruppen-Membership im Token senden

#### 2.1 Client Scopes konfigurieren

```
┌─────────────────────────────────────────────────────────┐
│  Client: argocd                                          │
│                                                          │
│  1. Tab: "Client scopes"                                │
│  2. Klick: "Add client scope"                           │
│  3. Select: "groups" (default scope)                    │
│  4. Klick: "Add" (Type: Default)                        │
└─────────────────────────────────────────────────────────┘
```

**Alternative: Via kcadm.sh (Command Line)**:

```bash
# Script existiert bereits: /tmp/fix-argocd-client-scopes.sh
/tmp/fix-argocd-client-scopes.sh

# Output:
# ✅ ArgoCD Client Scopes Fixed!
# ArgoCD now has access to: openid, profile, email, groups
```

---

### 🔐 SCHRITT 3: Secret in Kubernetes erstellen

**Ziel**: Client Secret sicher in Kubernetes speichern

#### 3.1 Secret mit kubeseal erstellen

```bash
# 1. Client Secret von Keycloak (Schritt 1.3)
CLIENT_SECRET="xMkH6QRqgntm1BTq3ah5xWAlUJUZJfbN"

# 2. Kubernetes Secret erstellen (temp)
kubectl create secret generic argocd-oidc-secret \
  --from-literal=clientSecret="$CLIENT_SECRET" \
  --namespace=argocd \
  --dry-run=client -o yaml > /tmp/argocd-oidc-secret.yaml

# 3. Mit kubeseal verschlüsseln
kubeseal --format=yaml \
  --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  < /tmp/argocd-oidc-secret.yaml \
  > kubernetes/infrastructure/controllers/argocd/oidc-secret.yaml

# 4. Cleanup temp file
rm /tmp/argocd-oidc-secret.yaml
```

#### 3.2 ⚠️ WICHTIG: ArgoCD Label hinzufügen

**Problem**: ArgoCD kann Secrets nur lesen wenn sie das Label haben!

Edit: `kubernetes/infrastructure/controllers/argocd/oidc-secret.yaml`

```yaml
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: argocd-oidc-secret
  namespace: argocd
spec:
  encryptedData:
    clientSecret: AgA...  # ← Encrypted value
  template:
    metadata:
      name: argocd-oidc-secret
      namespace: argocd
      labels:                                    # ← ADD THIS!
        app.kubernetes.io/part-of: argocd       # ← CRITICAL!
```

#### 3.3 Secret deployen

```bash
# Apply SealedSecret
kubectl apply -f kubernetes/infrastructure/controllers/argocd/oidc-secret.yaml

# Verify: Secret wurde erstellt
kubectl get secret argocd-oidc-secret -n argocd

# Verify: Label ist da
kubectl get secret argocd-oidc-secret -n argocd -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}'
# Output: argocd ✅
```

---

### ⚙️ SCHRITT 4: ArgoCD ConfigMap aktualisieren

**Ziel**: ArgoCD sagen wie es Keycloak nutzen soll

#### 4.1 ConfigMap editieren

```bash
kubectl edit configmap argocd-cm -n argocd
```

#### 4.2 OIDC Config hinzufügen

Add this to ConfigMap data:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # ... existing config ...

  # ========================================
  # 🔐 OIDC Configuration (Keycloak)
  # ========================================
  url: https://argo.timourhomelab.org

  oidc.config: |
    name: Keycloak
    issuer: https://iam.timourhomelab.org/realms/kubernetes
    clientID: argocd
    clientSecret: $argocd-oidc-secret:clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims:
      groups:
        essential: true
```

**Key Points**:
- `clientSecret: $argocd-oidc-secret:clientSecret` → References the Kubernetes Secret
- `requestedScopes` includes `"groups"` → Group membership in token
- `requestedIDTokenClaims.groups.essential: true` → Groups claim is required

---

### 🎭 SCHRITT 5: ArgoCD RBAC Policy konfigurieren

**Ziel**: Keycloak-Groups mit ArgoCD-Rollen verknüpfen

#### 5.1 RBAC ConfigMap editieren

```bash
kubectl edit configmap argocd-rbac-cm -n argocd
```

#### 5.2 RBAC Policy hinzufügen

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # ========================================
  # 🛡️ RBAC Policy (Group-based)
  # ========================================
  policy.default: role:readonly

  policy.csv: |
    # Cluster Admins (from LLDAP group: cluster-admins)
    g, cluster-admins, role:admin

    # ArgoCD Admins (from LLDAP group: argocd-admins)
    g, argocd-admins, role:admin

    # Developers (from LLDAP group: developers)
    g, developers, role:developer

    # Viewers (from LLDAP group: viewers)
    g, viewers, role:readonly

    # Developer role permissions
    p, role:developer, applications, *, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, repositories, *, *, allow
    p, role:developer, clusters, get, *, allow
```

**Erklärung**:
- `g, cluster-admins, role:admin` → LDAP group `cluster-admins` → ArgoCD admin
- `policy.default: role:readonly` → Alle anderen → read-only

---

### 🔄 SCHRITT 6: ArgoCD Server neu starten

**Ziel**: Neue Config laden

```bash
# Restart ArgoCD server deployment
kubectl rollout restart deployment argocd-server -n argocd

# Wait for rollout to complete
kubectl rollout status deployment argocd-server -n argocd --timeout=120s

# Check logs
kubectl logs -n argocd deployment/argocd-server --tail=50 | grep -i oidc
```

---

### ✅ SCHRITT 7: Test!

#### 7.1 Browser Test

```
1. Open: https://argo.timourhomelab.org

2. Click: "LOG IN VIA KEYCLOAK"

3. Keycloak Login:
   - Username: tim275
   - Password: [your LLDAP password]
   - MFA Code (if enabled): 123456

4. ✅ Success! Du bist in ArgoCD eingeloggt!
   - User: tim275
   - Role: Admin (from cluster-admins group)
```

#### 7.2 Verify Groups

```bash
# Check ArgoCD logs for successful OIDC login
kubectl logs -n argocd deployment/argocd-server --tail=100 | grep -i "groups"

# Should see:
# groups: [cluster-admins, argocd-admins]
```

---

## 🔧 Troubleshooting

### Problem 1: "failed to get token: unauthorized_client"

**Symptom**:
```
failed to get token: oauth2: "unauthorized_client"
"Invalid client or Invalid client credentials"
```

**Ursache**: ArgoCD kann Secret nicht lesen (fehlendes Label)

**Fix**:
```bash
# Add label to secret
kubectl label secret argocd-oidc-secret -n argocd \
  app.kubernetes.io/part-of=argocd --overwrite

# Restart ArgoCD
kubectl rollout restart deployment argocd-server -n argocd
```

### Problem 2: "data length is less than nonce size"

**Ursache**: Secret hat falschen/leeren Wert oder ist kaputt

**Fix**:
```bash
# Check secret value
kubectl get secret argocd-oidc-secret -n argocd -o jsonpath='{.data.clientSecret}' | base64 -d

# Should show: xMkH6QRqgntm1BTq3ah5xWAlUJUZJfbN (example)
# If empty → recreate secret (Schritt 3)
```

### Problem 3: "Groups not appearing in ArgoCD"

**Symptom**: Login works but no admin access

**Ursache**: `groups` scope fehlt in Keycloak client

**Fix**:
```bash
# Run client scopes fix script
/tmp/fix-argocd-client-scopes.sh

# Or manually: Add "groups" scope in Keycloak UI
# (see Schritt 2)
```

### Problem 4: Keine User in Keycloak

**Symptom**: Keycloak login zeigt "Invalid username or password"

**Ursache**: LLDAP Users nicht synced

**Fix**:
```bash
# 1. Check LLDAP is running
kubectl get pods -n lldap

# 2. Sync users from LLDAP to Keycloak
# Keycloak Admin → User Federation → ldap → "Sync all users"

# 3. Verify users exist
# Keycloak Admin → Users → Search: *
```

### Problem 5: Session expired sofort

**Ursache**: Browser cache oder Cookie-Problem

**Fix**:
```
1. Komplett ausloggen:
   - Keycloak: https://iam.timourhomelab.org/realms/kubernetes/account
   - Click "Sign out"

2. Browser cache leeren (Ctrl+Shift+Del)

3. Incognito/Private window öffnen

4. Erneut versuchen: https://argo.timourhomelab.org
```

---

## 🧪 Testing

### Complete Test Workflow

```bash
# 1. Verify Keycloak is healthy
kubectl get pods -n keycloak
# STATUS: Running ✅

# 2. Verify ArgoCD is healthy
kubectl get pods -n argocd
# argocd-server: Running ✅

# 3. Check Secret exists
kubectl get secret argocd-oidc-secret -n argocd
# NAME: argocd-oidc-secret ✅

# 4. Check Secret has label
kubectl get secret argocd-oidc-secret -n argocd \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}'
# Output: argocd ✅

# 5. Check ConfigMap OIDC config
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 10 "oidc.config"
# Should show issuer, clientID, etc. ✅

# 6. Test Keycloak OIDC endpoint
curl -k https://iam.timourhomelab.org/realms/kubernetes/.well-known/openid-configuration
# Should return JSON with endpoints ✅
```

### Browser Test

```
Test URL: https://argo.timourhomelab.org

Expected Flow:
1. ArgoCD homepage → "LOG IN VIA KEYCLOAK" button visible ✅
2. Click button → Redirect to Keycloak ✅
3. Keycloak login form appears ✅
4. Enter credentials → MFA prompt (if enabled) ✅
5. Redirect back to ArgoCD ✅
6. Logged in as user (check top-right corner) ✅
7. Admin access (if in cluster-admins group) ✅
```

---

## 🚀 Next Apps

Nach ArgoCD, gleiche Steps für:

### Grafana OIDC

```yaml
# Keycloak Client ID: grafana
# Redirect URI: https://grafana.timourhomelab.org/login/generic_oauth
# Grafana values.yaml:
grafana:
  grafana.ini:
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      client_id: grafana
      client_secret: [from sealed secret]
      scopes: openid email profile groups
      auth_url: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/auth
      token_url: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/token
      api_url: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/userinfo
```

### Hubble UI (via OAuth2-Proxy)

```yaml
# Hubble hat kein natives OIDC → OAuth2-Proxy davor!
# oauth2-proxy values:
config:
  clientID: hubble
  clientSecret: [from sealed secret]
  oidcIssuerUrl: https://iam.timourhomelab.org/realms/kubernetes
```

### Weitere Apps

- Prometheus (via OAuth2-Proxy)
- VUI (Velero UI) (via OAuth2-Proxy)
- N8N (native OIDC)
- CloudBeaver (native OIDC)

---

## 📚 References

### Keycloak Endpoints (kubernetes realm)

```
Issuer: https://iam.timourhomelab.org/realms/kubernetes
Authorization: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/auth
Token: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/token
UserInfo: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/userinfo
JWKS: https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/certs
```

### LLDAP Info

```
LDAP Host: lldap-ldap.lldap.svc.cluster.local
LDAP Port: 389
Base DN: dc=homelab,dc=local
Users DN: ou=people,dc=homelab,dc=local
Groups DN: ou=groups,dc=homelab,dc=local
```

### Users (IaC-managed)

| Username  | Groups                        | Access              |
|-----------|-------------------------------|---------------------|
| admin     | cluster-admins, argocd-admins | Full Admin Access   |
| tim275    | cluster-admins, argocd-admins | Full Admin Access   |
| ci-user   | ci-runners                    | CI/CD Bot           |

---

## ✅ Final Checklist

- [x] LLDAP deployed and users synced
- [x] Keycloak deployed and LDAP federation working
- [x] ArgoCD client created in Keycloak
- [x] Client secret stored as SealedSecret with correct label
- [x] ArgoCD ConfigMap updated with OIDC config
- [x] ArgoCD RBAC policy configured for groups
- [x] ArgoCD server restarted
- [x] Browser test successful
- [x] Groups claim working (admin access)

---

## 🎉 Success!

Du hast jetzt **Enterprise Single Sign-On** für dein Homelab!

**Was du erreicht hast**:
- ✅ Zentrale User-Verwaltung (LLDAP)
- ✅ Professionelles Identity Management (Keycloak)
- ✅ ArgoCD mit OIDC + Group-based RBAC
- ✅ 1 Login für alle Apps (SSO)
- ✅ MFA-ready (via Keycloak)
- ✅ Production-ready Architecture

**Nächste Schritte**:
1. Weitere Apps mit OIDC integrieren (Grafana, Hubble, etc.)
2. MFA für kritische User aktivieren
3. Keycloak Session-Timeouts konfigurieren
4. Audit Logs aktivieren

---

**Last Updated**: 2025-10-31
**Author**: Tim275 + Claude
**Status**: ✅ Production Ready
