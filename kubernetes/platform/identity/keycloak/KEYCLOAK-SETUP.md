# Keycloak OIDC Authentication for Kubernetes

**PRIVATE DOCUMENTATION - NOT IN GIT**

This document covers everything about Keycloak authentication setup for kubectl access with Google OAuth and MFA.

---

## Table of Contents

1. [What is Keycloak?](#what-is-keycloak)
2. [Alternatives to Keycloak](#alternatives-to-keycloak)
3. [Architecture Overview](#architecture-overview)
4. [From Scratch Setup](#from-scratch-setup)
5. [How to Activate OIDC kubectl](#how-to-activate-oidc-kubectl)
6. [Google OAuth Integration](#google-oauth-integration)
7. [MFA/2FA Best Practices](#mfa2fa-best-practices)
8. [Disaster Recovery](#disaster-recovery)
9. [Troubleshooting](#troubleshooting)

---

## What is Keycloak?

**Keycloak** is an open-source Identity and Access Management (IAM) solution that provides:

- **Single Sign-On (SSO)** - Login once, access multiple services
- **OpenID Connect (OIDC)** - Modern authentication protocol
- **Identity Brokering** - Login via Google, GitHub, Microsoft, etc.
- **User Federation** - LDAP/Active Directory integration
- **Multi-Factor Authentication (MFA)** - OTP, WebAuthn, SMS
- **Fine-grained Authorization** - Role-based access control
- **User Management** - Self-service registration, password reset

**Why Keycloak for Kubernetes?**
- Kubernetes API Server supports OIDC natively (no extra components!)
- Provides audit trail: WHO did WHAT (certificate auth = always "admin")
- Enables centralized user management across all cluster applications
- Supports enterprise features: MFA, SSO, identity brokering

---

## Alternatives to Keycloak

| Solution | Type | Pros | Cons | Best For |
|----------|------|------|------|----------|
| **Dex** | OIDC connector | Lightweight, Kubernetes-native | No built-in user database, basic UI | Proxy for existing identity providers |
| **Authelia** | Auth proxy | Lightweight, MFA support | Not a full IdP, limited OIDC | Homelab SSO for web apps |
| **Auth0** | Cloud SaaS | Managed, easy setup | Costs money, external dependency | Production cloud apps |
| **Okta** | Cloud SaaS | Enterprise features, compliance | Expensive, vendor lock-in | Large enterprises |
| **Google Cloud Identity** | Cloud SaaS | Integrates with GCP, Workspace SSO | GCP-specific, costs money | GCP/Google Workspace users |
| **Azure AD** | Cloud SaaS | Enterprise features, Microsoft SSO | Azure-specific, costs money | Microsoft shop |
| **LLDAP** | LDAP server | Ultra lightweight, simple | Not OIDC (needs Authelia/Dex) | Simple user database |
| **Keycloak** | Full IdP | Full-featured, self-hosted, free | Heavy resource usage (~2GB RAM) | Production homelabs, enterprises |

**Why we chose Keycloak:**
- ✅ Self-hosted (no external dependencies, no costs)
- ✅ Full IdP features (MFA, Google OAuth, user management)
- ✅ Production-grade (used by Red Hat, Cisco, Netflix)
- ✅ Kubernetes-native OIDC support
- ✅ Open-source and actively maintained

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│                     kubectl Authentication Flow                 │
└────────────────────────────────────────────────────────────────┘

1. User runs kubectl command
   │
   ├─> Certificate Auth (kube-config.yaml)
   │   └─> Direct API Server access with admin cert
   │       ✅ Works: Always (even if Keycloak down)
   │       ❌ Audit: No user identity (always "admin")
   │
   └─> OIDC Auth (kube-config-oidc.yaml)
       │
       ├─> kubelogin plugin opens browser
       │   └─> Redirect to Keycloak login page
       │       │
       │       ├─> Option 1: Username + Password
       │       │   └─> timour / test123 (kubernetes realm)
       │       │
       │       └─> Option 2: Google OAuth (Identity Brokering)
       │           └─> "Sign in with Google" button
       │               └─> Google login → Keycloak receives user info
       │
       ├─> User authenticates successfully
       │   └─> Keycloak returns ID Token with claims:
       │       - email: timour@timourhomelab.org
       │       - groups: ["cluster-admins"]
       │
       ├─> kubelogin caches token locally (~/.kube/cache/)
       │
       └─> kubectl sends token to API Server
           │
           └─> API Server validates token:
               ├─> Checks issuer: https://iam.timourhomelab.org/realms/kubernetes
               ├─> Extracts username from email claim
               ├─> Extracts groups from groups claim
               └─> Applies RBAC:
                   ClusterRoleBinding "oidc-cluster-admin"
                   ├─> Group: cluster-admins
                   └─> Role: cluster-admin ✅
```

**Key Files:**

| File | Location | Purpose |
|------|----------|---------|
| `kube-config.yaml` | `tofu/output/` | Certificate auth (break-glass, always works) |
| `kube-config-oidc.yaml` | `tofu/output/` | OIDC auth (normal use, audit trail) |
| `control-plane.yaml.tftpl` | `tofu/talos/machine-config/` | API Server OIDC flags |
| `kubernetes-realm-setup.yaml` | `kubernetes/infrastructure/authentication/keycloak/` | IaC Job for realm setup |
| `oidc-clusterrolebinding.yaml` | `kubernetes/infrastructure/authentication/keycloak/` | RBAC binding |
| `deployment.yaml` | `kubernetes/platform/identity/keycloak/` | Keycloak deployment |
| `postgres-cluster.yaml` | `kubernetes/platform/identity/keycloak/` | PostgreSQL database |

---

## From Scratch Setup

### Prerequisites

1. **Talos Cluster** deployed via OpenTofu
2. **ArgoCD** installed and configured
3. **CloudNativePG** operator deployed
4. **Sealed Secrets** controller deployed
5. **Envoy Gateway** with TLS certificate for `iam.timourhomelab.org`
6. **kubelogin** installed: `brew install int128/kubelogin/kubelogin`

---

### Step 1: Configure Talos API Server OIDC

**File:** `tofu/talos/machine-config/control-plane.yaml.tftpl`

```yaml
cluster:
  apiServer:
    extraArgs:
      # OIDC authentication via Keycloak
      oidc-issuer-url: "https://iam.timourhomelab.org/realms/kubernetes"
      oidc-client-id: "kubectl"
      oidc-username-claim: "email"
      oidc-groups-claim: "groups"
```

**Apply changes:**

```bash
cd tofu
tofu apply -auto-approve
```

This regenerates Talos machine configs with OIDC flags. API Server will restart with new config.

---

### Step 2: Create Sealed Secrets

**Admin credentials:**

```bash
# Generate random password
ADMIN_PASSWORD=$(openssl rand -base64 32)

# Create sealed secret
kubectl create secret generic keycloak-admin \
  --from-literal=username=admin \
  --from-literal=password="$ADMIN_PASSWORD" \
  --namespace keycloak \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > kubernetes/platform/identity/keycloak/admin-sealed-secret.yaml
```

**Database credentials:**

```bash
# Generate random password
DB_PASSWORD=$(openssl rand -base64 32)

# Create sealed secret
kubectl create secret generic keycloak-db-credentials \
  --from-literal=username=keycloak \
  --from-literal=password="$DB_PASSWORD" \
  --namespace keycloak \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > kubernetes/platform/identity/keycloak/db-credentials-sealed.yaml
```

**S3 credentials (for PostgreSQL backups):**

```bash
# Use Ceph RGW credentials from rook-ceph-object-user secret
kubectl get secret -n rook-ceph rook-ceph-object-user-homelab-objectstore-keycloak-backups \
  -o jsonpath='{.data.AccessKey}' | base64 -d > /tmp/access_key
kubectl get secret -n rook-ceph rook-ceph-object-user-homelab-objectstore-keycloak-backups \
  -o jsonpath='{.data.SecretKey}' | base64 -d > /tmp/secret_key

# Create sealed secret
kubectl create secret generic keycloak-s3-credentials \
  --from-literal=ACCESS_KEY_ID=$(cat /tmp/access_key) \
  --from-literal=ACCESS_SECRET_KEY=$(cat /tmp/secret_key) \
  --namespace keycloak \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > kubernetes/platform/identity/keycloak/s3-credentials-sealed.yaml

# Cleanup
rm /tmp/access_key /tmp/secret_key
```

---

### Step 3: Deploy Keycloak via ArgoCD

**File structure:**

```
kubernetes/
├── platform/
│   └── identity/
│       └── keycloak/
│           ├── kustomization.yaml          # Main kustomize file
│           ├── application.yaml            # ArgoCD application
│           ├── admin-sealed-secret.yaml    # Admin credentials
│           ├── db-credentials-sealed.yaml  # DB credentials
│           ├── s3-credentials-sealed.yaml  # S3 backup credentials
│           ├── postgres-cluster.yaml       # CloudNativePG cluster
│           ├── deployment.yaml             # Keycloak deployment
│           ├── service.yaml                # Kubernetes service
│           └── httproute.yaml              # Gateway API route
│
└── infrastructure/
    └── authentication/
        └── keycloak/
            ├── kustomization.yaml              # OIDC resources
            ├── kubernetes-realm-setup.yaml     # Realm setup Job
            └── oidc-clusterrolebinding.yaml    # RBAC binding
```

**Deploy ArgoCD Application:**

```bash
kubectl apply -f kubernetes/platform/identity/keycloak/application.yaml
```

**ArgoCD will automatically deploy:**
1. CloudNativePG PostgreSQL cluster (single instance, 10GB storage)
2. Keycloak deployment (PostgreSQL backend, 1 replica)
3. Service + HTTPRoute (accessible at https://iam.timourhomelab.org)

**Wait for deployment:**

```bash
# Watch ArgoCD sync
kubectl get application keycloak -n argocd -w

# Wait for Keycloak pod
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=keycloak -n keycloak --timeout=300s

# Check Keycloak logs
kubectl logs -f -n keycloak -l app.kubernetes.io/name=keycloak
```

---

### Step 4: Configure Kubernetes Realm (IaC)

**The Realm Setup Job automatically creates:**

1. **Realm:** `kubernetes`
2. **Client:** `kubectl` (PUBLIC client for CLI auth)
3. **Client Scope:** `groups` with Group Membership mapper
4. **Group:** `cluster-admins`
5. **User:** `timour` (email: timour@timourhomelab.org, password: test123)
6. **Group Membership:** timour → cluster-admins

**File:** `kubernetes/infrastructure/authentication/keycloak/kubernetes-realm-setup.yaml`

**Deploy:**

```bash
kubectl apply -k kubernetes/infrastructure/authentication/keycloak/
```

**Verify Job completed:**

```bash
kubectl get jobs -n keycloak
kubectl logs -n keycloak job/keycloak-kubernetes-realm-setup
```

Expected output:
```
=== Keycloak kubernetes realm setup complete! ===
```

---

### Step 5: Apply RBAC Binding

The ClusterRoleBinding grants `cluster-admin` role to Keycloak's `cluster-admins` group.

**File:** `kubernetes/infrastructure/authentication/keycloak/oidc-clusterrolebinding.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: cluster-admins
```

This was already applied in Step 4 via `kubectl apply -k`.

**Verify:**

```bash
kubectl get clusterrolebinding oidc-cluster-admin
```

---

## How to Activate OIDC kubectl

### Method 1: Switch kubeconfig with export

**Use Certificate Auth (break-glass):**

```bash
export KUBECONFIG=/path/to/tofu/output/kube-config.yaml
kubectl get nodes  # Works immediately, no login
```

**Use OIDC Auth (normal operations):**

```bash
export KUBECONFIG=/path/to/tofu/output/kube-config-oidc.yaml
kubectl get nodes  # Opens browser for Keycloak login
```

---

### Method 2: kubectl config use-context

**Merge both kubeconfigs:**

```bash
export KUBECONFIG=/path/to/tofu/output/kube-config.yaml:/path/to/tofu/output/kube-config-oidc.yaml
kubectl config view --flatten > ~/.kube/config
```

**Switch contexts:**

```bash
# List contexts
kubectl config get-contexts

# Use certificate auth
kubectl config use-context admin@homelab-k8s

# Use OIDC auth
kubectl config use-context homelab-k8s-oidc
kubectl get nodes  # Opens browser for login
```

---

### Method 3: Wrapper Script (Smart Auto-Switch)

**File:** `~/.local/bin/kubectl-smart`

```bash
#!/bin/bash
# Smart kubectl wrapper - auto-switches between OIDC and certificate auth

if [[ -f "$HOME/.kube/oidc-enabled" ]]; then
  export KUBECONFIG=/path/to/tofu/output/kube-config-oidc.yaml
else
  export KUBECONFIG=/path/to/tofu/output/kube-config.yaml
fi

kubectl "$@"
```

**Enable/disable OIDC:**

```bash
# Enable OIDC
touch ~/.kube/oidc-enabled

# Disable OIDC (use certificate)
rm ~/.kube/oidc-enabled
```

**Add alias:**

```bash
echo 'alias k=kubectl-smart' >> ~/.zshrc
source ~/.zshrc
```

---

### OIDC Login Flow

1. **First kubectl command:**
   ```bash
   kubectl get nodes
   ```

2. **kubelogin opens browser automatically:**
   ```
   Opening browser for authentication...
   ```

3. **Keycloak login page appears:**
   - Username: `timour@timourhomelab.org`
   - Password: `test123`
   - OR: Click "Sign in with Google" (if configured)

4. **Success page:**
   ```
   Authentication successful!
   You can close this window.
   ```

5. **Token cached locally:**
   ```
   ~/.kube/cache/oidc-login/
   ```

6. **kubectl command executes:**
   ```bash
   NAME      STATUS   ROLES           AGE   VERSION
   ctrl-0    Ready    control-plane   10d   v1.32.0
   work-0    Ready    <none>          10d   v1.32.0
   work-1    Ready    <none>          10d   v1.32.0
   ```

7. **Subsequent commands use cached token (no login for ~24 hours)**

---

## Google OAuth Integration

### Why Google OAuth?

- ✅ No password management (Keycloak stores no passwords)
- ✅ Leverages Google's security (2FA, suspicious login detection)
- ✅ Single Sign-On across all services
- ✅ Automatic user provisioning from Google account

---

### Prerequisites

1. **Google Cloud Project** (free, no costs for OAuth)
2. **OAuth 2.0 Client ID** with Keycloak redirect URI
3. **Keycloak configured as Identity Broker**

---

### Step 1: Create Google OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create a project
3. Navigate to: **APIs & Services > Credentials**
4. Click **Create Credentials > OAuth client ID**
5. Application type: **Web application**
6. Name: `Keycloak Homelab`
7. **Authorized redirect URIs:**
   ```
   https://iam.timourhomelab.org/realms/kubernetes/broker/google/endpoint
   ```
8. Click **Create**
9. **Save Client ID and Client Secret** (you'll need these!)

---

### Step 2: Configure Keycloak Identity Provider

**Via Keycloak Admin Console:**

1. Login to https://iam.timourhomelab.org
2. Select **kubernetes** realm (top-left dropdown)
3. Navigate to: **Identity Providers**
4. Click **Add provider > Google**
5. Fill in:
   - **Alias:** `google` (must match redirect URI!)
   - **Display Name:** `Sign in with Google`
   - **Client ID:** `<your-google-client-id>`
   - **Client Secret:** `<your-google-client-secret>`
6. **Advanced Settings:**
   - **Sync Mode:** `Import`
   - **Store Tokens:** `OFF` (privacy)
   - **Trust Email:** `ON`
   - **Hide on Login Page:** `OFF`
7. Click **Save**

---

### Step 3: Create Google OAuth Secret (GitOps)

**Store Google OAuth credentials as SealedSecret:**

```bash
kubectl create secret generic keycloak-google-oauth \
  --from-literal=client-id="<your-google-client-id>" \
  --from-literal=client-secret="<your-google-client-secret>" \
  --namespace keycloak \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > kubernetes/platform/identity/keycloak/google-oauth-sealed.yaml
```

**Add to kustomization.yaml:**

```yaml
resources:
  - google-oauth-sealed.yaml
```

---

### Step 4: Configure Identity Provider via IaC (Optional)

**Keycloak REST API approach:**

Create a Job that runs after realm setup to configure Google Identity Provider:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-google-idp-setup
  namespace: keycloak
spec:
  template:
    spec:
      containers:
      - name: setup
        image: quay.io/keycloak/keycloak:26.0.7
        env:
          - name: KEYCLOAK_URL
            value: "http://keycloak:8080"
          - name: GOOGLE_CLIENT_ID
            valueFrom:
              secretKeyRef:
                name: keycloak-google-oauth
                key: client-id
          - name: GOOGLE_CLIENT_SECRET
            valueFrom:
              secretKeyRef:
                name: keycloak-google-oauth
                key: client-secret
        command:
          - /bin/bash
          - -c
          - |
            # Login to Keycloak admin
            /opt/keycloak/bin/kcadm.sh config credentials \
              --server "$KEYCLOAK_URL" \
              --realm master \
              --user admin \
              --password "$KEYCLOAK_ADMIN_PASSWORD"

            # Create Google Identity Provider
            /opt/keycloak/bin/kcadm.sh create identity-provider/instances -r kubernetes \
              -s alias=google \
              -s providerId=google \
              -s enabled=true \
              -s trustEmail=true \
              -s storeToken=false \
              -s config.clientId="$GOOGLE_CLIENT_ID" \
              -s config.clientSecret="$GOOGLE_CLIENT_SECRET" \
              -s config.syncMode=IMPORT

            echo "Google Identity Provider configured!"
```

---

### Step 5: Test Google OAuth Login

1. **Logout from current session:**
   ```bash
   rm -rf ~/.kube/cache/oidc-login/
   ```

2. **Run kubectl command:**
   ```bash
   kubectl get nodes
   ```

3. **Browser opens with Keycloak login page**

4. **Click "Sign in with Google"** button

5. **Google login page appears:**
   - Select Google account
   - Grant permissions (email, profile)

6. **Redirected back to Keycloak:**
   - User automatically created in kubernetes realm
   - Email: `<your-google-email>`
   - Username: Auto-generated from email

7. **Success! kubectl command executes**

---

### Step 6: Add Google User to cluster-admins Group

**Via Keycloak Admin Console:**

1. Login to https://iam.timourhomelab.org
2. Select **kubernetes** realm
3. Navigate to: **Users**
4. Find your Google user (email address)
5. Click on username → **Groups** tab
6. Click **Join Group**
7. Select **cluster-admins**
8. Click **Join**

**Via kcadm.sh:**

```bash
# Get Google user ID
USER_ID=$(kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get users -r kubernetes \
  --query email=your-google-email@gmail.com \
  --fields id --format csv --noquotes)

# Get cluster-admins group ID
GROUP_ID=$(kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get groups -r kubernetes \
  --query name=cluster-admins \
  --fields id --format csv --noquotes)

# Add user to group
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh update "users/$USER_ID/groups/$GROUP_ID" \
  -r kubernetes -s realm=kubernetes -n
```

---

## MFA/2FA Best Practices

### Why MFA for Kubernetes?

- ✅ **Defense in depth:** Even if password leaked, attacker needs second factor
- ✅ **Compliance:** Many regulations require MFA (SOC 2, HIPAA, PCI-DSS)
- ✅ **Audit trail:** Tracks MFA enrollment and usage
- ✅ **Phishing protection:** FIDO2/WebAuthn prevents phishing attacks

**Threat Model:**
- Password compromise → MFA blocks unauthorized access
- Stolen kubectl token → Short expiry (24h) + MFA on refresh
- Shared credentials → MFA enforces individual accountability

---

### MFA Methods Comparison

| Method | Security | User Experience | Phishing Resistant | Cost |
|--------|----------|-----------------|-------------------|------|
| **TOTP (Authenticator App)** | Medium | Good | No | Free |
| **WebAuthn/FIDO2 (YubiKey)** | High | Excellent | Yes | $25-50 |
| **SMS** | Low | Poor | No | Costs money |
| **Email** | Low | Poor | No | Free |
| **Push Notification** | Medium | Good | No | Requires app |

**Recommended Stack:**
1. **Primary:** WebAuthn/FIDO2 (YubiKey, Touch ID, Windows Hello)
2. **Fallback:** TOTP Authenticator (Google Authenticator, Authy, 1Password)
3. **Avoid:** SMS (SIM swap attacks), Email (account compromise)

---

### Enable TOTP MFA in Keycloak

**Step 1: Configure Authentication Flow**

1. Login to Keycloak Admin Console: https://iam.timourhomelab.org
2. Select **kubernetes** realm
3. Navigate to: **Authentication > Flows**
4. Select **Browser Flow** (used for kubectl OIDC login)
5. Click **Copy** to duplicate flow
6. Name: `Browser with MFA`
7. Click **Add execution**
8. Select: **OTP Form**
9. Requirement: **REQUIRED**
10. Click **Save**

**Step 2: Set as Default Flow**

1. Navigate to: **Authentication > Bindings**
2. **Browser Flow:** Select `Browser with MFA`
3. Click **Save**

**Step 3: Require MFA for All Users**

1. Navigate to: **Authentication > Required Actions**
2. Check **Enabled** for: `Configure OTP`
3. Check **Default Action** (forces setup on next login)

---

### Enable WebAuthn MFA (YubiKey, Touch ID)

**Step 1: Enable WebAuthn Authenticator**

1. Navigate to: **Authentication > Flows**
2. Edit your `Browser with MFA` flow
3. Click **Add execution**
4. Select: **WebAuthn Authenticator**
5. Requirement: **ALTERNATIVE** (allows choice between TOTP or WebAuthn)
6. Click **Save**

**Step 2: Configure WebAuthn Policy**

1. Navigate to: **Authentication > WebAuthn Policy**
2. **Relying Party Name:** `Timour Homelab Kubernetes`
3. **Signature Algorithms:** Keep defaults
4. **Attestation Preference:** `Not specified`
5. **Authenticator Attachment:** `Cross-platform` (allows YubiKey)
6. **Require Resident Key:** `Not required`
7. **User Verification Requirement:** `Preferred`
8. **Timeout:** `60` seconds
9. **Avoid Same Authenticator:** `OFF`
10. Click **Save**

**Step 3: Enable WebAuthn Required Action**

1. Navigate to: **Authentication > Required Actions**
2. Check **Enabled** for: `WebAuthn Register`
3. Check **Default Action** (forces setup on next login)

---

### User MFA Enrollment Flow

**First login after MFA enabled:**

1. Run `kubectl get nodes`
2. Browser opens Keycloak login
3. Enter username + password
4. **MFA Setup Page appears:**

**Option 1: TOTP Authenticator**
- QR code displayed
- Scan with Google Authenticator / Authy / 1Password
- Enter 6-digit code to verify
- **Recovery codes** displayed (save these!)

**Option 2: WebAuthn (YubiKey / Touch ID)**
- Click "Register Security Key"
- Browser prompts for security key
- Insert YubiKey and tap button
- OR: Use Touch ID on Mac
- Device registered successfully

**Subsequent logins:**
- Enter username + password
- Enter TOTP code OR tap YubiKey
- Access granted ✅

---

### MFA Enforcement via Group Policy

**Enforce MFA for cluster-admins group only:**

1. Navigate to: **Groups**
2. Select **cluster-admins**
3. Click **Attributes** tab
4. Add attribute:
   - **Key:** `require-mfa`
   - **Value:** `true`
5. Click **Save**

**Create Conditional Authentication Flow:**

```javascript
// Script: Require MFA for cluster-admins group
var user = context.getUser();
var groups = user.getGroupsStream().map(function(g) { return g.getName(); }).toArray();

if (groups.includes("cluster-admins")) {
    // Check if user has MFA configured
    var credentials = user.getCredentialsStream().toArray();
    var hasTOTP = credentials.some(function(c) { return c.getType() === "otp"; });
    var hasWebAuthn = credentials.some(function(c) { return c.getType() === "webauthn"; });

    if (!hasTOTP && !hasWebAuthn) {
        // Force MFA enrollment
        context.addRequiredAction("CONFIGURE_TOTP");
    } else {
        // Require MFA challenge
        context.forceChallenge("mfa-challenge");
    }
}
```

---

### MFA Best Practices for Production

1. **Recovery Codes**
   - Generate 10 one-time recovery codes per user
   - Store securely (password manager, printed in safe)
   - Invalidate after use

2. **Multiple MFA Devices**
   - Register 2+ WebAuthn devices (primary YubiKey + backup)
   - Register TOTP on multiple devices

3. **Admin Break-Glass**
   - Keep one admin account WITHOUT MFA requirement
   - Use only in emergencies (Keycloak down, lost devices)
   - Store credentials in physical safe

4. **Audit Logging**
   - Enable Keycloak event logging
   - Monitor failed MFA attempts
   - Alert on suspicious patterns

5. **Session Management**
   - **SSO Session Idle:** 30 minutes
   - **SSO Session Max:** 10 hours
   - **Client Session Idle:** 30 minutes
   - **Access Token Lifespan:** 5 minutes

   **Configure:**
   - Navigate to: **Realm Settings > Sessions**
   - Set timeouts as above

6. **MFA Skip for Local Network (Optional)**
   - Configure IP allowlisting for home network
   - Skip MFA if connecting from `192.168.68.0/24`
   - Useful for local kubectl access

---

### Production MFA Configuration (IaC)

**Example: Enforce MFA via Terraform Keycloak Provider**

```hcl
# terraform/keycloak/mfa.tf

resource "keycloak_authentication_flow" "browser_with_mfa" {
  realm_id = keycloak_realm.kubernetes.id
  alias    = "Browser with MFA"
}

resource "keycloak_authentication_execution" "totp_form" {
  realm_id          = keycloak_realm.kubernetes.id
  parent_flow_alias = keycloak_authentication_flow.browser_with_mfa.alias
  authenticator     = "auth-otp-form"
  requirement       = "REQUIRED"
}

resource "keycloak_authentication_execution" "webauthn" {
  realm_id          = keycloak_realm.kubernetes.id
  parent_flow_alias = keycloak_authentication_flow.browser_with_mfa.alias
  authenticator     = "webauthn-authenticator"
  requirement       = "ALTERNATIVE"
}

resource "keycloak_authentication_bindings" "browser_bindings" {
  realm_id     = keycloak_realm.kubernetes.id
  browser_flow = keycloak_authentication_flow.browser_with_mfa.alias
}
```

**Note:** Terraform Keycloak provider is NOT production-ready for authentication flows (API limitations). Recommended approach: Configure MFA via Admin Console, export realm JSON, store in Git.

---

## Disaster Recovery

### Scenario 1: tofu destroy + tofu apply

**What happens:**

1. `tofu destroy` → Cluster deleted, all data lost
2. `tofu apply` → New cluster created, kubeconfigs regenerated in `tofu/output/`
3. Keycloak namespace + data GONE (PostgreSQL PVC deleted)
4. ArgoCD re-deploys Keycloak from Git
5. Realm Setup Job runs → Recreates kubernetes realm + users

**Recovery Time Objective (RTO):** ~20 minutes

**Workflow:**

```bash
# 1. Destroy cluster
cd tofu
tofu destroy -auto-approve

# 2. Create new cluster
tofu apply -auto-approve

# 3. Bootstrap with certificate auth
export KUBECONFIG=$(pwd)/output/kube-config.yaml

# 4. Wait for ArgoCD
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s

# 5. Deploy Keycloak application
kubectl apply -f ../kubernetes/platform/identity/keycloak/application.yaml

# 6. Wait for Keycloak
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=keycloak -n keycloak --timeout=600s

# 7. Realm Setup Job runs automatically
kubectl wait --for=condition=complete job/keycloak-kubernetes-realm-setup -n keycloak --timeout=300s

# 8. Switch to OIDC
export KUBECONFIG=$(pwd)/output/kube-config-oidc.yaml
kubectl get nodes  # Login with timour / test123
```

---

### Scenario 2: Keycloak Database Corruption

**What happens:**

1. PostgreSQL pod crashes or data corruption
2. Keycloak cannot start (database connection errors)
3. OIDC kubectl fails (cannot reach issuer URL)

**Recovery:**

```bash
# Use certificate auth (break-glass!)
export KUBECONFIG=/path/to/tofu/output/kube-config.yaml

# Option 1: Restore from Velero backup
velero restore create --from-backup keycloak-daily-20251030

# Option 2: Restore from CNPG S3 backup
kubectl cnpg backup keycloak-db --method barmanObjectStore

# Option 3: Delete and recreate (data loss!)
kubectl delete -k kubernetes/platform/identity/keycloak/
kubectl apply -k kubernetes/platform/identity/keycloak/
```

---

### Scenario 3: Lost Keycloak Admin Password

**Recovery:**

```bash
# Reset admin password via Keycloak pod
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh set-password \
  --server http://localhost:8080 \
  --realm master \
  --username admin \
  --new-password "new-secure-password"
```

---

### Scenario 4: MFA Lockout

**User lost MFA device and recovery codes:**

```bash
# Remove MFA requirement for user
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password "$ADMIN_PASSWORD"

# Get user ID
USER_ID=$(kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get users -r kubernetes \
  --query username=timour --fields id --format csv --noquotes)

# Remove OTP credential
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh delete users/$USER_ID/credentials/otp -r kubernetes
```

---

## Troubleshooting

### Issue 1: kubectl OIDC login fails with "Unauthorized"

**Symptoms:**
```
Error from server (Unauthorized): ...
```

**Diagnosis:**

```bash
# Check API Server has OIDC config
export TALOSCONFIG=/path/to/tofu/output/talos-config.yaml
talosctl -n 192.168.68.101 get staticpods kube-apiserver -o yaml | grep oidc-issuer-url

# Should output:
# oidc-issuer-url: https://iam.timourhomelab.org/realms/kubernetes
```

**If missing:**

```bash
# Regenerate Talos config
cd tofu
tofu apply -auto-approve

# Wait for API Server restart (~30 seconds)
sleep 30

# Verify
talosctl -n 192.168.68.101 get staticpods kube-apiserver -o yaml | grep oidc
```

---

### Issue 2: Browser doesn't open during kubectl login

**Symptoms:**
```
Opening browser for authentication...
(nothing happens)
```

**Fix:**

```bash
# Manual login
kubelogin get-token \
  --oidc-issuer-url=https://iam.timourhomelab.org/realms/kubernetes \
  --oidc-client-id=kubectl \
  --oidc-extra-scope=email \
  --oidc-extra-scope=profile \
  --oidc-extra-scope=groups

# Copy token from output, then:
kubectl --token="<paste-token-here>" get nodes
```

---

### Issue 3: "Invalid redirect URI" in Keycloak

**Symptoms:**
Keycloak error page: "Invalid parameter: redirect_uri"

**Fix:**

```bash
# Login to Keycloak Admin Console
# Navigate to: Clients > kubectl > Settings
# Ensure "Valid Redirect URIs" contains:
#   http://localhost:8000
#   http://localhost:18000
# Click Save
```

---

### Issue 4: User not in cluster-admins group

**Symptoms:**
```
Error from server (Forbidden): nodes is forbidden: User "timour@timourhomelab.org" cannot list resource "nodes"
```

**Fix:**

```bash
# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding oidc-cluster-admin

# Check user's groups in Keycloak
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get users -r kubernetes \
  --query username=timour --fields id,username,groups

# Add user to cluster-admins group (see Step 6 in Google OAuth section)
```

---

### Issue 5: Keycloak pod CrashLoopBackOff

**Symptoms:**
```
keycloak-xxxx-xxxx   0/1     CrashLoopBackOff
```

**Diagnosis:**

```bash
# Check logs
kubectl logs -n keycloak -l app.kubernetes.io/name=keycloak

# Common errors:
# 1. Database connection failed → Check PostgreSQL pod
# 2. Invalid hostname config → Check KC_HOSTNAME env var
# 3. Certificate issues → Check Gateway TLS cert
```

---

### Issue 6: Token expired

**Symptoms:**
```
Unable to connect to the server: failed to refresh token: ...
```

**Fix:**

```bash
# Clear cached token
rm -rf ~/.kube/cache/oidc-login/

# Re-authenticate
kubectl get nodes  # Opens browser for fresh login
```

---

## Production Checklist

### Security Hardening

- [ ] **Enable MFA** for all cluster-admin users
- [ ] **Configure WebAuthn** (YubiKey / Touch ID)
- [ ] **Set session timeouts** (SSO Max: 10h, Idle: 30min)
- [ ] **Enable Kubernetes audit logging** (track who did what)
- [ ] **Rotate admin password** quarterly
- [ ] **Backup SealedSecrets master key** to secure location
- [ ] **Enable PostgreSQL backups** to Ceph RGW S3
- [ ] **Test disaster recovery** quarterly
- [ ] **Monitor failed login attempts** (Prometheus + Alertmanager)
- [ ] **Restrict Keycloak admin access** (IP allowlist or VPN-only)

### Compliance Requirements

**SOC 2 Type II:**
- [ ] MFA required for privileged access
- [ ] Audit logs retained 90+ days
- [ ] Password complexity enforced
- [ ] Session timeouts configured
- [ ] Break-glass access documented

**HIPAA:**
- [ ] MFA required
- [ ] Audit logs include user identity
- [ ] Encryption at rest (PostgreSQL PVC)
- [ ] Encryption in transit (TLS)
- [ ] Access controls via RBAC

**PCI-DSS:**
- [ ] MFA required
- [ ] Password min 12 chars
- [ ] Account lockout after 6 failed attempts
- [ ] Audit logs retained 1+ year

---

## Additional Resources

- **Keycloak Docs:** https://www.keycloak.org/documentation
- **Kubernetes OIDC Guide:** https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens
- **kubelogin Plugin:** https://github.com/int128/kubelogin
- **WebAuthn Guide:** https://webauthn.guide/
- **Talos OIDC Setup:** https://www.talos.dev/v1.10/kubernetes-guides/configuration/oidc/

---

**Last Updated:** 2025-10-30
**Author:** Timour (timour@timourhomelab.org)
**Status:** Production-Ready ✅
