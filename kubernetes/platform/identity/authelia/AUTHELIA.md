# Authelia Enterprise OIDC Setup Guide

## 🎯 Overview

Authelia ist ein Open-Source OIDC Provider mit Multi-Factor Authentication (MFA) für Enterprise Single Sign-On (SSO). Diese Dokumentation beschreibt das komplette Setup mit **Self-Service TOTP Registration** für skalierbare Multi-User Umgebungen.

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AUTHELIA ARCHITECTURE                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  User Browser                                                │
│       ↓                                                      │
│  Cloudflare Tunnel (auth.timourhomelab.org)                 │
│       ↓                                                      │
│  Authelia Service (Port 9091)                               │
│       ↓                                                      │
│  ┌────────────────────────────────────────────────┐         │
│  │  Authentication Backend: LLDAP                 │         │
│  │  - LDAP Server: lldap-ldap.lldap.svc          │         │
│  │  - Base DN: dc=homelab,dc=local               │         │
│  │  - Users: ou=people                           │         │
│  │  - Groups: ou=groups (cluster-admins)         │         │
│  └────────────────────────────────────────────────┘         │
│       ↓                                                      │
│  ┌────────────────────────────────────────────────┐         │
│  │  Notification Backend: SMTP Email              │         │
│  │  - Provider: Outlook (smtp-mail.outlook.com)   │         │
│  │  - Port: 587 (STARTTLS)                       │         │
│  │  - From: timour.miagol@outlook.de             │         │
│  └────────────────────────────────────────────────┘         │
│       ↓                                                      │
│  ┌────────────────────────────────────────────────┐         │
│  │  Storage Backend: SQLite                       │         │
│  │  - Path: /data/db.sqlite3 (emptyDir)          │         │
│  │  - Stores: User sessions, TOTP secrets        │         │
│  └────────────────────────────────────────────────┘         │
│       ↓                                                      │
│  ┌────────────────────────────────────────────────┐         │
│  │  OIDC Provider Configuration                   │         │
│  │  - Issuer: https://auth.timourhomelab.org     │         │
│  │  - Clients: kubernetes, argocd, grafana, n8n  │         │
│  │  - Token Lifetime: 1h access, 90m refresh     │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## 🔐 Enterprise Multi-Factor Authentication (MFA)

Authelia bietet **3 MFA-Methoden** (wie Okta/Google Workspace):

### Method 1: TOTP (Time-based One-Time Password)
- **Apps**: Google Authenticator, Microsoft Authenticator, Authy
- **Setup**: Self-Service via QR Code nach Email-Verifikation
- **Use Case**: Standard MFA für alle Users

### Method 2: WebAuthn (Biometric Authentication)
- **Devices**: Fingerprint, Face ID, YubiKey, Windows Hello
- **Setup**: Self-Service via Browser API
- **Use Case**: Passwordless authentication für Power Users

### Method 3: Duo Push (Optional)
- **Provider**: Duo Security (free für 10 users)
- **Setup**: Duo API integration + mobile app enrollment
- **Use Case**: Mobile Push Notifications (Enterprise Premium)

**Für dieses Setup verwenden wir TOTP als Primary MFA Method.**

## 📋 Prerequisites

### 1. LLDAP User Directory
- **Service**: `lldap-ldap.lldap.svc.cluster.local:389`
- **Admin User**: `uid=admin,ou=people,dc=homelab,dc=local`
- **Admin Password**: Stored in `authelia-secrets` sealed secret
- **User Email**: **KRITISCH** - Jeder User MUSS valide Email in LLDAP haben!

**Check LLDAP User Email:**
```bash
kubectl port-forward -n lldap svc/lldap-http 17170:80
# Open: http://localhost:17170
# Login as admin → Users → Edit user → Ensure email field is filled!
```

### 2. Outlook SMTP Email Account
- **Email**: timour.miagol@outlook.de
- **App Password**: Erstellt via Outlook Account Security Settings
- **SMTP Server**: smtp-mail.outlook.com:587 (STARTTLS)

**How to Generate Outlook App Password:**
1. Gehe zu: https://account.microsoft.com/security
2. Navigiere zu: **Security > Advanced security options**
3. Klicke: **Add a new way to sign in or verify > App password**
4. Generiere: New app password → Copy password (Format: `xxxx xxxx xxxx xxxx`)
5. **WICHTIG**: Spaces entfernen für Kubernetes Secret!

### 3. Sealed Secrets Controller
- **Required für**: SMTP password encryption
- **Check**: `kubectl get pods -n sealed-secrets`
- **Service**: `sealed-secrets-controller.sealed-secrets.svc`

## 🚀 Step-by-Step Setup

### Step 1: SMTP Email Configuration

**1.1 Create SMTP Password Secret (Plain):**
```bash
# Create temporary secret (will be sealed)
kubectl create secret generic authelia-smtp-password \
  --namespace=authelia \
  --from-literal=smtp-password='mkkxolytjmrkajta' \
  --dry-run=client -o yaml > /tmp/authelia-smtp-secret.yaml
```

**1.2 Seal the Secret:**
```bash
# Encrypt with Sealed Secrets controller
kubeseal --controller-name=sealed-secrets-controller \
         --controller-namespace=sealed-secrets \
         --format=yaml \
         < /tmp/authelia-smtp-secret.yaml \
         > kubernetes/platform/identity/authelia/smtp-sealed-secret.yaml

# Clean up plaintext secret
rm /tmp/authelia-smtp-secret.yaml
```

**1.3 Deploy Sealed Secret:**
```bash
kubectl apply -f kubernetes/platform/identity/authelia/smtp-sealed-secret.yaml

# Verify unsealed secret was created
kubectl get secret -n authelia authelia-smtp-password
```

### Step 2: Configure Authelia SMTP Notifier

**2.1 Update ConfigMap (`kubernetes/platform/identity/authelia/configmap.yaml`):**

```yaml
# Notifier (Outlook SMTP - Enterprise Self-Service)
notifier:
  disable_startup_check: false
  smtp:
    address: smtp://smtp-mail.outlook.com:587
    username: timour.miagol@outlook.de
    sender: "Homelab Authelia <timour.miagol@outlook.de>"
    subject: "[Homelab] {title}"
    startup_check_address: timour.miagol@outlook.de
    disable_require_tls: false
    disable_html_emails: false
    # Password from secret: AUTHELIA_NOTIFIER_SMTP_PASSWORD
```

**2.2 Apply ConfigMap:**
```bash
kubectl apply -f kubernetes/platform/identity/authelia/configmap.yaml
```

### Step 3: Inject SMTP Password into Deployment

**3.1 Update Deployment (`kubernetes/platform/identity/authelia/deployment.yaml`):**

Add SMTP password environment variable:
```yaml
env:
  # ... existing env vars ...

  # SMTP Password (Outlook App Password)
  - name: AUTHELIA_NOTIFIER_SMTP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: authelia-smtp-password
        key: smtp-password
```

**3.2 Apply Deployment:**
```bash
kubectl apply -f kubernetes/platform/identity/authelia/deployment.yaml
```

### Step 4: Verify SMTP Configuration

**4.1 Check Authelia Pod Logs:**
```bash
kubectl logs -n authelia -l app.kubernetes.io/name=authelia --tail=50
```

**Expected Output:**
```
level=info msg="Configuration has been loaded successfully"
level=info msg="SMTP notifier configured successfully"
level=info msg="Startup check: sending test email to timour.miagol@outlook.de"
level=info msg="Startup check: test email sent successfully"
```

**4.2 Check Email Inbox:**
- **Subject**: `[Homelab] Authelia Startup Notification`
- **From**: `Homelab Authelia <timour.miagol@outlook.de>`
- **Content**: "Authelia SMTP notifier is working correctly"

**If email NOT received:**
```bash
# Check SMTP credentials
kubectl get secret -n authelia authelia-smtp-password -o yaml

# Check Authelia logs for errors
kubectl logs -n authelia -l app.kubernetes.io/name=authelia | grep -i smtp
```

## 🔒 Self-Service TOTP Registration (End User Guide)

### For End Users (New Employees)

**Step 1: Initial Login**
1. Navigate to: https://auth.timourhomelab.org
2. Enter your username (from LLDAP)
3. Enter your password (from LLDAP)
4. Click **Sign In**

**Step 2: Register TOTP Device**
1. After login, click **Register 2FA Device** (or similar)
2. You will see: **"Identity Verification - One-Time Code sent to email"**
3. Check your email inbox (use email from LLDAP profile!)
4. Copy the **6-digit verification code** from email
5. Paste code into Authelia dialog
6. Click **Verify**

**Step 3: Scan QR Code**
1. After verification, a **QR Code** appears
2. Open your authenticator app:
   - **Android**: Google Authenticator, Microsoft Authenticator
   - **iOS**: Google Authenticator, Microsoft Authenticator
   - **Desktop**: Authy
3. Scan the QR code with your app
4. Enter the **6-digit TOTP code** from your app into Authelia
5. Click **Register**

**Step 4: Test TOTP Login**
1. Logout from Authelia
2. Login again with username + password
3. You will be prompted for **TOTP code**
4. Open your authenticator app
5. Enter the current 6-digit code
6. Click **Sign In**

**✅ Success! You now have TOTP 2FA enabled!**

## 👨‍💼 Administrator Guide

### How to Onboard New Users

**Step 1: Create User in LLDAP**
1. Port-forward LLDAP UI:
   ```bash
   kubectl port-forward -n lldap svc/lldap-http 17170:80
   ```
2. Open: http://localhost:17170
3. Login as admin
4. Click **Users > Add User**
5. Fill in:
   - **Username**: `john.doe`
   - **Display Name**: `John Doe`
   - **Email**: `john.doe@company.com` (**REQUIRED for TOTP verification!**)
   - **Password**: `temporary-password-123`
6. Add to group: `cluster-admins` (or `developers`)
7. Click **Create**

**Step 2: Send Credentials to User**
Send email to new user:
```
Subject: Homelab Access - Credentials

Hi John,

Your Homelab access has been created:

Username: john.doe
Temporary Password: temporary-password-123
Login URL: https://auth.timourhomelab.org

Please login and register your TOTP device (Google Authenticator app).
You will receive an email verification code during TOTP setup.

After TOTP registration, you can access:
- ArgoCD: https://argocd.homelab.local
- Grafana: https://grafana.homelab.local
- N8N: https://n8n.homelab.local

Best regards,
IT Team
```

**Step 3: User Follows Self-Service TOTP Registration**
- User logs in with temporary password
- User registers TOTP device (receives email verification code)
- User scans QR code with authenticator app
- User completes TOTP registration

**NO ADMIN INTERVENTION REQUIRED!** 🎉

### How to Add OIDC Clients - Complete Step-by-Step Guide

This section provides a **comprehensive guide** for configuring OIDC clients in Authelia, based on the successful Netbird VPN integration.

---

#### 🎯 **Step 1: Understand OIDC Client Types**

**Frontend Applications (Dashboard/UI):**
- **Example**: Netbird Dashboard, Grafana UI, ArgoCD UI
- **Authentication**: User login via browser redirect
- **Token Type**: `idToken` (contains user claims)
- **Audience**: Required for token validation
- **Redirect URIs**: Browser callback URLs

**Backend Services (API/Management):**
- **Example**: Netbird Management API, Kubernetes API Server
- **Authentication**: Service-to-service token validation
- **Token Type**: `accessToken` or JWT validation
- **OIDC Discovery**: Uses `.well-known/openid-configuration` endpoint

---

#### 🛠️ **Step 2: Add OIDC Client to Authelia ConfigMap**

**Example 1: Simple OIDC Client (Nextcloud)**

Edit `kubernetes/platform/identity/authelia/configmap.yaml`:

```yaml
identity_providers:
  oidc:
    clients:
      # ... existing clients ...

      # Nextcloud OIDC Client
      - id: nextcloud
        description: Nextcloud File Storage
        secret: nextcloud-oidc-secret-placeholder-change-me  # STEP 3: Generate this!
        public: false
        authorization_policy: one_factor  # or two_factor for MFA
        redirect_uris:
          - https://cloud.homelab.local/apps/oidc_login/oidc
        scopes:
          - openid
          - profile
          - email
        userinfo_signing_algorithm: none
```

**Example 2: OIDC Client with Audience (Netbird Pattern)**

⚠️ **CRITICAL**: If your application uses **audience validation** (like Netbird, Kubernetes API), you **MUST** add the `audience` field!

```yaml
# Netbird VPN OIDC Client (Dashboard - Frontend)
- id: netbird
  description: Netbird Dashboard (Frontend)
  secret: netbird-oidc-secret-placeholder-change-me  # STEP 3: Generate this!
  public: false
  authorization_policy: one_factor
  audience:                    # ⚠️ CRITICAL for audience validation!
    - netbird                  # Whitelists "netbird" as valid audience
  redirect_uris:
    - https://netbird.timourhomelab.org/callback
    - https://netbird.timourhomelab.org/silent-callback
  scopes:
    - openid
    - profile
    - email
  userinfo_signing_algorithm: none
```

**🔍 When to Use `audience` Field:**

✅ **USE `audience` if your application:**
- Validates JWT `aud` (audience) claim
- Has separate frontend + backend components
- Uses OIDC discovery with audience parameter
- Shows error: "Requested audience 'X' has not been whitelisted"

❌ **SKIP `audience` if your application:**
- Only uses basic OIDC login (username/email only)
- Doesn't validate audience claim
- Simple single-page apps with no backend API

---

#### 🔐 **Step 3: Generate OIDC Client Secret**

```bash
# Generate cryptographically secure secret
openssl rand -base64 32

# Example output:
Dl8iWXZ4Rj6rZ8b2GYQxrbRZvwMBQkn/ONg05wusD5c=
```

**Replace placeholder in configmap.yaml:**
```yaml
secret: Dl8iWXZ4Rj6rZ8b2GYQxrbRZvwMBQkn/ONg05wusD5c=
```

⚠️ **Security Warning**:
- Never commit plaintext secrets to Git!
- For production: Use SealedSecrets or external secret management
- Rotate secrets regularly (every 90 days recommended)

---

#### 📋 **Step 4: Apply ConfigMap and Restart Authelia**

**Option A: Via ArgoCD (Recommended for GitOps)**

```bash
# Commit changes to Git
cd kubernetes/platform/identity/authelia
git add configmap.yaml
git commit -m "feat: add Nextcloud OIDC client"
git push

# Trigger ArgoCD sync
export KUBECONFIG=/path/to/kubeconfig.yaml
kubectl patch application authelia -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Wait for sync to complete (5-10 seconds)
sleep 10

# Restart Authelia to load new config
kubectl delete pod -n authelia -l app.kubernetes.io/name=authelia
```

**Option B: Manual Apply (Testing/Development)**

```bash
# Apply configmap directly
kubectl apply -f kubernetes/platform/identity/authelia/configmap.yaml

# Restart Authelia deployment
kubectl rollout restart -n authelia deployment/authelia

# Verify pods are running
kubectl get pods -n authelia
```

---

#### 🔧 **Step 5: Configure Application to Use Authelia OIDC**

**5.1 Frontend Application (Dashboard) Configuration**

Example: Netbird Dashboard environment variables:

```yaml
# Dashboard kustomization.yaml
configMapGenerator:
  - name: dashboard-config
    namespace: netbird
    literals:
      - AUTH_CLIENT_ID="netbird"                           # OIDC client ID from Authelia
      - AUTH_AUDIENCE="netbird"                            # Must match audience in Authelia config
      - AUTH_AUTHORITY="https://auth.timourhomelab.org"   # Authelia OIDC issuer URL
      - AUTH_REDIRECT_URI="/callback"                      # Relative redirect path
      - AUTH_SILENT_REDIRECT_URI="/silent-callback"        # For silent token refresh
      - AUTH_SUPPORTED_SCOPES="openid profile email"       # Requested scopes
      - USE_AUTH0="false"                                  # Disable Auth0 mode
      - NETBIRD_TOKEN_SOURCE="idToken"                     # Use ID token (not access token)
```

**5.2 Backend Service (Management API) Configuration**

Example: Netbird Management API `management.json`:

```json
{
  "HttpConfig": {
    "Address": ":80",
    "AuthAudience": "netbird",                    // Must match audience in Authelia
    "AuthUserIDClaim": "preferred_username",      // JWT claim for user ID
    "OIDCConfigEndpoint": "https://auth.timourhomelab.org/.well-known/openid-configuration"
  },
  "PKCEAuthorizationFlow": {
    "ProviderConfig": {
      "Audience": "netbird",                      // Consistent audience everywhere!
      "Scope": "openid profile email",
      "RedirectURLs": [ "http://localhost:53000" ],
      "UseIDToken": false                         // Backend uses access token
    }
  }
}
```

**🔍 Key Configuration Rules:**

1. **Consistent `audience` value**: Dashboard, Backend, and Authelia MUST all use same value (e.g., "netbird")
2. **Public OIDC Discovery**: Always use public domain (not internal cluster DNS):
   - ✅ `https://auth.timourhomelab.org/.well-known/openid-configuration`
   - ❌ `http://authelia.authelia.svc.cluster.local:9091/.well-known/openid-configuration`
3. **Redirect URIs**: Must EXACTLY match URLs configured in Authelia
4. **Token Source**: Frontend uses `idToken`, Backend validates tokens

---

#### ✅ **Step 6: Verify OIDC Configuration**

**6.1 Check Authelia OIDC Discovery Endpoint:**

```bash
curl -s https://auth.timourhomelab.org/.well-known/openid-configuration | jq .
```

**Expected Output:**
```json
{
  "issuer": "https://auth.timourhomelab.org",
  "authorization_endpoint": "https://auth.timourhomelab.org/api/oidc/authorization",
  "token_endpoint": "https://auth.timourhomelab.org/api/oidc/token",
  "userinfo_endpoint": "https://auth.timourhomelab.org/api/oidc/userinfo",
  "jwks_uri": "https://auth.timourhomelab.org/jwks.json",
  "scopes_supported": ["openid", "profile", "email", "groups"],
  ...
}
```

**6.2 Check Application Pods:**

```bash
# Check frontend dashboard pod
kubectl get pods -n <namespace>
kubectl logs -n <namespace> deployment/<dashboard> --tail=50

# Verify environment variables are set
kubectl exec -n <namespace> deployment/<dashboard> -- env | grep "AUTH_"
```

**6.3 Test OIDC Login Flow:**

1. Navigate to application URL (e.g., `https://netbird.timourhomelab.org`)
2. Click "Login with SSO" or similar
3. **Expected**: Redirect to `https://auth.timourhomelab.org`
4. Enter LLDAP credentials (username + password)
5. **Expected**: Redirect back to application with successful login

**🚨 Common Errors and Fixes:**

**Error 1: "Requested audience 'X' has not been whitelisted"**
- **Cause**: Missing `audience` field in Authelia client config
- **Fix**: Add `audience: [X]` to client configuration in `configmap.yaml`

**Error 2: "Error: Unauthenticated"**
- **Cause**: Issuer mismatch or missing AUTH_CLIENT_ID
- **Fix**: Use PUBLIC OIDC discovery URL, ensure AUTH_CLIENT_ID is set

**Error 3: "Invalid redirect_uri"**
- **Cause**: Callback URL not in Authelia's `redirect_uris` list
- **Fix**: Add exact callback URL to client config

**Error 4: "Invalid client_id"**
- **Cause**: Client ID in application doesn't match Authelia config
- **Fix**: Ensure `AUTH_CLIENT_ID` = `id` field in Authelia client

---

#### 📊 **Step 7: Monitor and Troubleshoot**

**Check Authelia Logs:**
```bash
kubectl logs -n authelia -l app.kubernetes.io/name=authelia --tail=100 | grep -i oidc
```

**Check Application Logs:**
```bash
kubectl logs -n <namespace> deployment/<app> --tail=100
```

**Verify Token Claims:**
```bash
# Login to application, capture JWT token from browser developer tools
# Decode token at: https://jwt.io

# Example decoded token:
{
  "iss": "https://auth.timourhomelab.org",
  "sub": "tim275",
  "aud": "netbird",                          // Must match audience config!
  "preferred_username": "tim275",
  "groups": ["admins", "developers"],
  "email": "timour.miagol@outlook.de",
  "exp": 1696789200
}
```

---

#### 🎯 **Real-World Example: Netbird VPN Integration**

**Success Story**: Netbird VPN was successfully integrated with Authelia OIDC after multiple iterations.

**Challenges Faced:**
1. ❌ Initial error: "Error: Unauthenticated" → Fixed by using PUBLIC OIDC discovery
2. ❌ Second error: Missing AUTH_CLIENT_ID → Fixed by adding environment variable
3. ❌ Final error: "Requested audience 'netbird' has not been whitelisted" → Fixed by adding `audience: [netbird]`

**Final Working Configuration:**

**Authelia ConfigMap** (`configmap.yaml`):
```yaml
- id: netbird
  description: Netbird Dashboard (Frontend)
  secret: netbird-oidc-secret-placeholder-change-me
  public: false
  authorization_policy: one_factor
  audience:              # ✅ CRITICAL FIX!
    - netbird
  redirect_uris:
    - https://netbird.timourhomelab.org/callback
    - https://netbird.timourhomelab.org/silent-callback
  scopes:
    - openid
    - profile
    - email
  userinfo_signing_algorithm: none
```

**Netbird Dashboard** (`dashboard/kustomization.yaml`):
```yaml
configMapGenerator:
  - name: dashboard-config
    literals:
      - AUTH_CLIENT_ID="netbird"        # ✅ REQUIRED!
      - AUTH_AUDIENCE="netbird"         # ✅ Must match Authelia audience
      - AUTH_AUTHORITY="https://auth.timourhomelab.org"
      - AUTH_REDIRECT_URI="/callback"
      - AUTH_SUPPORTED_SCOPES="openid profile email"
      - NETBIRD_TOKEN_SOURCE="idToken"
```

**Netbird Management API** (`management/management.json`):
```json
{
  "HttpConfig": {
    "AuthAudience": "netbird",
    "OIDCConfigEndpoint": "https://auth.timourhomelab.org/.well-known/openid-configuration"
  }
}
```

**Result**: ✅ OIDC login successful! All components authenticated correctly.

---

#### 📚 **OIDC Client Configuration Checklist**

Before deploying a new OIDC client, verify:

- [ ] Client ID is unique and descriptive
- [ ] Client secret is cryptographically secure (32+ bytes)
- [ ] `redirect_uris` includes ALL callback URLs (frontend + silent refresh)
- [ ] `audience` field added if application validates audience claim
- [ ] Scopes include minimum required: `openid`, `profile`, `email`
- [ ] `authorization_policy` set correctly (`one_factor` or `two_factor`)
- [ ] Application uses PUBLIC OIDC discovery URL (not internal cluster DNS)
- [ ] Application `AUTH_CLIENT_ID` matches Authelia `id` field
- [ ] Application `AUTH_AUDIENCE` matches Authelia `audience` array value
- [ ] ConfigMap committed to Git and ArgoCD synced
- [ ] Authelia pods restarted to load new config
- [ ] Application pods restarted to pick up new environment variables
- [ ] Login flow tested end-to-end

**✅ If all items checked → OIDC integration should work!**

## 🛠️ Troubleshooting

### Problem 1: Email Not Received During TOTP Registration

**Symptoms:**
- Click "Register TOTP" → "Identity Verification" dialog appears
- No email received with verification code

**Root Causes & Solutions:**

**1.1 User has no email in LLDAP:**
```bash
# Check user email in LLDAP
kubectl port-forward -n lldap svc/lldap-http 17170:80
# Open: http://localhost:17170 → Users → Check email field
```

**Fix**: Add email address to user profile in LLDAP

**1.2 SMTP credentials incorrect:**
```bash
# Check Authelia logs
kubectl logs -n authelia -l app.kubernetes.io/name=authelia | grep -i smtp
```

**Common Errors:**
```
level=error msg="SMTP: Authentication failed"
→ Fix: Regenerate Outlook app password, update sealed secret

level=error msg="SMTP: Connection timeout"
→ Fix: Check network connectivity to smtp-mail.outlook.com:587

level=error msg="SMTP: TLS handshake failed"
→ Fix: Ensure disable_require_tls: false (Outlook requires TLS!)
```

**1.3 Outlook blocked email as spam:**
- Check **Outlook Junk Email** folder
- Add `noreply@authelia.com` to safe senders

**1.4 SMTP password not injected:**
```bash
# Verify secret exists
kubectl get secret -n authelia authelia-smtp-password

# Verify deployment has env var
kubectl get deployment -n authelia authelia -o yaml | grep AUTHELIA_NOTIFIER_SMTP_PASSWORD
```

### Problem 2: "Invalid Code" After Entering Email Verification Code

**Symptoms:**
- Receive email with 6-digit code
- Enter code in Authelia → "Invalid code" error

**Root Causes:**

**2.1 Code expired (5 minute timeout):**
- Email verification codes expire after 5 minutes
- Request new code by clicking "Resend Code"

**2.2 Wrong code format:**
- Must be exactly 6 digits
- No spaces, no dashes

**2.3 Clock skew:**
```bash
# Check Authelia pod time
kubectl exec -n authelia -it deployment/authelia -- date

# Compare with host time
date
```

**Fix**: Ensure NTP is synced on cluster nodes

### Problem 3: TOTP Code Not Working After Registration

**Symptoms:**
- TOTP registration successful
- Login with password → TOTP prompt appears
- Authenticator app shows 6-digit code
- Authelia rejects code: "Invalid authentication"

**Root Causes:**

**3.1 Clock skew between app and Authelia:**
```yaml
# Check TOTP config in configmap.yaml
totp:
  period: 30        # Default: 30 seconds
  skew: 1           # Allows ±1 period (±30s)
```

**Fix**: Increase skew tolerance:
```yaml
totp:
  skew: 2  # Allows ±2 periods (±60s)
```

**3.2 Wrong TOTP secret stored:**
- Re-register TOTP device
- Ensure QR code scan was successful
- Check authenticator app shows "Homelab Authelia" account

**3.3 SQLite database corrupted:**
```bash
# Check Authelia storage
kubectl exec -n authelia -it deployment/authelia -- ls -lh /data/db.sqlite3

# If database is corrupted, delete and re-register all TOTP devices
kubectl delete pod -n authelia -l app.kubernetes.io/name=authelia
```

### Problem 4: Cloudflare Tunnel Connection Issues

**Symptoms:**
- https://auth.timourhomelab.org not reachable
- Browser shows: "Connection timeout" or "Bad Gateway"

**Root Causes:**

**4.1 Cloudflare Tunnel not running:**
```bash
kubectl get pods -n cloudflared
```

**Fix**: Ensure cloudflared deployment is running

**4.2 HTTPRoute not configured:**
```bash
kubectl get httproute -n authelia
```

**Fix**: Apply HTTPRoute for Authelia:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: authelia
  namespace: authelia
spec:
  parentRefs:
  - name: cloudflared-gateway
    namespace: cloudflared
  hostnames:
  - "auth.timourhomelab.org"
  rules:
  - backendRefs:
    - name: authelia
      port: 9091
```

**4.3 Service not exposing correct port:**
```bash
kubectl get svc -n authelia authelia -o yaml
```

**Expected output:**
```yaml
ports:
- name: http
  port: 9091
  targetPort: 9091
```

### Problem 5: "Two Factor Required" but TOTP Not Registered

**Symptoms:**
- Login with password successful
- Redirect to "Two Factor Required" screen
- User has NOT registered TOTP yet
- Infinite redirect loop

**Root Cause:**
Access control policy requires `two_factor` but user has no 2FA device registered.

**Fix**: Temporarily change policy to `one_factor` for initial TOTP registration:

```yaml
# configmap.yaml
access_control:
  rules:
    - domain: "*.homelab.local"
      policy: one_factor  # TEMPORARILY! Change back to two_factor after TOTP registration
      subject:
        - "group:cluster-admins"
```

**After TOTP Registration:**
```yaml
# configmap.yaml
access_control:
  rules:
    - domain: "*.homelab.local"
      policy: two_factor  # Enforce MFA for all admins
      subject:
        - "group:cluster-admins"
```

## 📊 Monitoring & Health Checks

### Check Authelia Health

**API Health Endpoint:**
```bash
kubectl exec -n authelia deployment/authelia -- wget -qO- http://localhost:9091/api/health
```

**Expected Output:**
```json
{
  "status": "healthy"
}
```

### Check SMTP Connection

**Manual SMTP Test:**
```bash
# Port-forward Authelia pod
kubectl port-forward -n authelia deployment/authelia 9091:9091

# Trigger password reset (sends test email)
curl -X POST https://auth.timourhomelab.org/api/reset-password/identity/start \
  -H "Content-Type: application/json" \
  -d '{"username": "admin"}'
```

**Check Email Received:**
- Subject: `[Homelab] Password Reset Request`
- From: `Homelab Authelia <timour.miagol@outlook.de>`

### Check LDAP Connection

**Test LDAP Authentication:**
```bash
kubectl exec -n authelia deployment/authelia -- \
  ldapsearch -x -H ldap://lldap-ldap.lldap.svc.cluster.local:389 \
  -D "uid=admin,ou=people,dc=homelab,dc=local" \
  -w '<admin-password>' \
  -b "ou=people,dc=homelab,dc=local" \
  "(uid=admin)"
```

**Expected Output:**
```
dn: uid=admin,ou=people,dc=homelab,dc=local
uid: admin
mail: timour.miagol@outlook.de
displayName: Admin User
```

## 🔒 Security Best Practices

### 1. OIDC Client Secrets

**❌ Bad:**
```yaml
secret: argocd-oidc-secret-placeholder-change-me  # Default placeholder!
```

**✅ Good:**
```yaml
secret: Dl8iWXZ4Rj6rZ8b2GYQxrbRZvwMBQkn/ONg05wusD5c=  # Generated with openssl rand -base64 32
```

### 2. Access Control Policies

**❌ Bad:**
```yaml
access_control:
  default_policy: bypass  # ALL services bypassed - NO SECURITY!
```

**✅ Good:**
```yaml
access_control:
  default_policy: deny  # Deny by default, allow explicitly
  rules:
    - domain: "auth.timourhomelab.org"
      policy: bypass  # Only Authelia portal bypassed

    - domain: "*.homelab.local"
      policy: two_factor  # MFA required for all services
      subject:
        - "group:cluster-admins"
```

### 3. Session Configuration

**❌ Bad:**
```yaml
session:
  expiration: 24h      # Too long - security risk!
  inactivity: 1h       # User stays logged in for 1 hour without activity
```

**✅ Good:**
```yaml
session:
  expiration: 1h       # Short session lifetime
  inactivity: 5m       # Auto-logout after 5 minutes inactivity
  remember_me: 1M      # Optional "Remember Me" extends to 1 month
```

### 4. SMTP Password Storage

**❌ Bad:**
```yaml
# deployment.yaml
env:
- name: AUTHELIA_NOTIFIER_SMTP_PASSWORD
  value: "mkkxolytjmrkajta"  # Plaintext password in deployment!
```

**✅ Good:**
```yaml
# deployment.yaml
env:
- name: AUTHELIA_NOTIFIER_SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: authelia-smtp-password  # Sealed Secret
      key: smtp-password
```

## 📚 References

### Official Documentation
- **Authelia**: https://www.authelia.com/docs/
- **OIDC Integration**: https://www.authelia.com/integration/openid-connect/introduction/
- **TOTP Configuration**: https://www.authelia.com/configuration/second-factor/time-based-one-time-password/
- **SMTP Notifier**: https://www.authelia.com/configuration/notifications/smtp/

### External Resources
- **Outlook App Password**: https://support.microsoft.com/account-billing/manage-app-passwords-for-two-step-verification
- **LLDAP GitHub**: https://github.com/lldap/lldap
- **Sealed Secrets**: https://github.com/bitnami-labs/sealed-secrets

### Architecture Decisions
- **Why SMTP over File Notifier**: File notifier doesn't scale for multiple users - emails are sent to individual user inboxes
- **Why TOTP over WebAuthn**: TOTP works on all devices (mobile, desktop) without special hardware
- **Why Self-Service Registration**: Admins don't need to manually configure TOTP for every new employee
- **Why Outlook over Gmail**: User already has Outlook email - no need for separate Gmail account

## 🎉 Success Metrics

✅ **Authelia deployed** with SMTP email notifications
✅ **SMTP startup check** sends test email to admin inbox
✅ **Users can self-register TOTP** without admin intervention
✅ **Email verification codes** delivered successfully
✅ **TOTP login** works with authenticator apps
✅ **OIDC clients** (ArgoCD, Grafana, N8N) integrated
✅ **External access** via Cloudflare Tunnel functional
✅ **Multi-user scalability** ready for team onboarding

**Enterprise Authentication = COMPLETE!** 🚀
