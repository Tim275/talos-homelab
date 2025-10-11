# 🔐 Zero Trust Architecture - VPN + Authentication

**Enterprise Pattern**: Network Layer (Tailscale VPN) + Identity Layer (Authelia OIDC + 2FA)

This setup implements **true Zero Trust security** for Kubernetes services, following Netflix/Google/Meta best practices.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PUBLIC INTERNET                              │
│                                                                       │
│  ✅ n8n.timourhomelab.org        (Public - No VPN, No Auth)         │
│  ✅ auth.timourhomelab.org       (Public - Login Portal)             │
│  ✅ iam.timourhomelab.org        (Public - Keycloak)                 │
└─────────────────────────────────────────────────────────────────────┘

                               ↓ Cloudflare Tunnel

┌─────────────────────────────────────────────────────────────────────┐
│                      TAILSCALE VPN ONLY                              │
│                    (Network Layer Security)                          │
│                                                                       │
│  🔒 grafana.timourhomelab.org   → Envoy Gateway → Authelia          │
│  🔒 kibana.timourhomelab.org    → Envoy Gateway → Authelia          │
│  🔒 ceph.timourhomelab.org      → Envoy Gateway → Authelia          │
│  🔒 hubble.timourhomelab.org    → Envoy Gateway → Authelia          │
│  🔒 keep.timourhomelab.org      → Envoy Gateway → Authelia          │
│  🔒 velero.timourhomelab.org    → Envoy Gateway → Authelia          │
└─────────────────────────────────────────────────────────────────────┘

                               ↓ SecurityPolicy

┌─────────────────────────────────────────────────────────────────────┐
│                    IDENTITY LAYER SECURITY                           │
│                      (Authelia ForwardAuth)                          │
│                                                                       │
│  ✅ Valid Session Cookie    → Access Granted (200 OK)               │
│  ❌ No/Invalid Cookie       → Redirect to Login (302)               │
│  ✅ LLDAP + 2FA (TOTP/WebAuthn) → Session Created                   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Phase 1: VPN-Only Access (COMPLETED ✅)

### What Was Done:

1. **Tailscale Deployment** (GitOps Pattern)
   - Deployed via `kubernetes/infrastructure/vpn/tailscale/`
   - Pod running on worker-6 with subnet routing enabled
   - Routes advertised: `10.244.0.0/16` (pods), `10.96.0.0/16` (services)

2. **Gateway LoadBalancer**
   - IP: `192.168.68.152` (envoy-gateway-envoy-gateway-ee418b6e)
   - All HTTPRoutes route through this Gateway
   - TLS termination with Let's Encrypt wildcard cert

3. **Split-Horizon DNS** (User Action Required)
   - **Cloudflare Tunnel**: Remove private services from public hostnames
   - **Tailscale MagicDNS**: Add 6 DNS records pointing to `192.168.68.152`
     - grafana.timourhomelab.org
     - kibana.timourhomelab.org
     - ceph.timourhomelab.org
     - hubble.timourhomelab.org
     - keep.timourhomelab.org
     - velero.timourhomelab.org

### Testing Phase 1:

```bash
# With Tailscale VPN connected:
curl -I https://grafana.timourhomelab.org
# Expected: 200 OK (Grafana login page)

# Without Tailscale VPN:
curl -I https://grafana.timourhomelab.org
# Expected: Timeout / No route to host
```

**Status**: ✅ Tailscale pod running (1/1), DNS configuration pending user action

---

## 📋 Phase 2: Zero Trust Authentication (READY TO DEPLOY)

### What Will Be Done:

#### 1. **Authelia External Authorization Service**

**File**: `platform/identity/authelia/ext-authz-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: authelia-ext-authz
  namespace: authelia
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 9091
      targetPort: http
  selector:
    app.kubernetes.io/name: authelia
```

**Purpose**: Exposes Authelia's ForwardAuth endpoint (`/api/authz/forward-auth`) to Envoy Gateway

#### 2. **Envoy Gateway SecurityPolicy**

**File**: `infrastructure/network/gateway/authelia-securitypolicy.yaml`

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: authelia-forwardauth
  namespace: gateway
spec:
  targetRef:
    kind: Gateway
    name: envoy-gateway
  extAuth:
    http:
      backendRef:
        name: authelia-ext-authz
        namespace: authelia
        port: 9091
      path: /api/authz/forward-auth
      headersToBackend:
        - Remote-User
        - Remote-Groups
        - Remote-Email
        - Remote-Name
```

**Purpose**: Every request to `envoy-gateway` Gateway will be validated by Authelia

#### 3. **Authelia Access Control** (Already Configured ✅)

**File**: `platform/identity/authelia/configmap.yaml` (lines 102-130)

```yaml
access_control:
  default_policy: deny
  rules:
    - domain: "auth.timourhomelab.org"
      policy: bypass  # Public login portal

    - domain: "*.timourhomelab.org"
      policy: one_factor  # LLDAP + 2FA
      subject:
        - "group:cluster-admins"
        - "group:developers"
```

**Current**: `one_factor` (password + TOTP/WebAuthn)
**Can upgrade to**: `two_factor` for critical services

---

## 🚀 Deployment Steps (Phase 2)

### Step 1: Enable SecurityPolicy (GitOps)

```bash
# Edit kustomization.yaml
cd kubernetes/infrastructure/network/gateway/
vim kustomization.yaml

# Change:
# - authelia-securitypolicy.yaml  # ⚠️ DISABLED
# To:
- authelia-securitypolicy.yaml  # ✅ ENABLED

# Commit and push
git add .
git commit -m "feat: enable Zero Trust authentication with Authelia SecurityPolicy"
git push
```

### Step 2: Verify ArgoCD Sync

```bash
# Check ArgoCD Applications
kubectl get applications -n argocd | grep -E "gateway|authelia"

# Should see:
# gateway         Synced   Healthy
# authelia        Synced   Healthy
```

### Step 3: Verify SecurityPolicy Applied

```bash
# Check SecurityPolicy resource
kubectl get securitypolicy -n gateway

# Expected output:
# NAME                   AGE
# authelia-forwardauth   1m
```

### Step 4: Test Zero Trust Flow

#### Test 1: Unauthenticated Access (Should Redirect)
```bash
# With VPN connected, but no Authelia session:
curl -I https://grafana.timourhomelab.org

# Expected: 302 Found
# Location: https://auth.timourhomelab.org/login?rd=https://grafana.timourhomelab.org
```

#### Test 2: Login to Authelia
```bash
# Open browser (with VPN connected)
open https://auth.timourhomelab.org

# Login with LLDAP credentials:
# Username: tim275 (or your LLDAP user)
# Password: (your LLDAP password)
# 2FA: TOTP code (Google Authenticator) OR WebAuthn (Fingerprint/YubiKey)
```

#### Test 3: Authenticated Access (Should Work)
```bash
# After successful login, browser has session cookie:
curl -H "Cookie: authelia_session=<cookie>" https://grafana.timourhomelab.org

# Expected: 200 OK (Grafana dashboard)
# Or just open in browser: https://grafana.timourhomelab.org
```

### Step 5: Verify User Headers Passed

```bash
# Check Grafana logs for Authelia headers
kubectl logs -n grafana deploy/grafana | grep -i remote

# Expected headers from Authelia:
# Remote-User: tim275
# Remote-Groups: cluster-admins
# Remote-Email: tim275@homelab.local
# Remote-Name: Tim 275
```

---

## 🔐 Security Benefits

### Layer 1: Network Security (Tailscale VPN)
- ✅ **Zero Trust Network**: No firewall rules, no port forwarding
- ✅ **Encrypted Tunnel**: WireGuard-based mesh VPN
- ✅ **Device Authentication**: Only authorized devices can connect
- ✅ **Split DNS**: Private services only resolve on VPN

### Layer 2: Identity Security (Authelia + LLDAP)
- ✅ **Multi-Factor Authentication**: TOTP (Google Auth) or WebAuthn (YubiKey)
- ✅ **Centralized User Management**: LLDAP directory with RBAC groups
- ✅ **Session Management**: Redis-backed sessions with expiration
- ✅ **Brute-Force Protection**: Rate limiting (5 attempts, 10min ban)
- ✅ **Audit Logging**: All authentication events logged

### Combined Benefits (Zero Trust)
- ✅ **Defense in Depth**: Both network AND identity verification required
- ✅ **Least Privilege**: Group-based access control (cluster-admins, developers)
- ✅ **Short-lived Sessions**: 1 hour access tokens, 5min inactivity timeout
- ✅ **Revocation**: Disable LLDAP user → instant access loss across all services
- ✅ **OIDC Ready**: Can integrate with Grafana, ArgoCD, N8N SSO

---

## 🎯 Service Access Matrix

| Service | Public Access | VPN Required | Auth Required | Group Required |
|---------|---------------|--------------|---------------|----------------|
| **n8n.timourhomelab.org** | ✅ Yes | ❌ No | ❌ No | - |
| **auth.timourhomelab.org** | ✅ Yes | ❌ No | ❌ No | - |
| **iam.timourhomelab.org** | ✅ Yes | ❌ No | ❌ No | - |
| **grafana.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins, developers |
| **kibana.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins, developers |
| **ceph.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins |
| **hubble.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins, developers |
| **keep.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins |
| **velero.timourhomelab.org** | ❌ No | ✅ Yes | ✅ Yes | cluster-admins |

---

## 🛠️ Troubleshooting

### Issue 1: SecurityPolicy Not Applied

```bash
# Check SecurityPolicy status
kubectl describe securitypolicy authelia-forwardauth -n gateway

# Check if Envoy Gateway recognized it
kubectl logs -n envoy-gateway-system deploy/envoy-gateway | grep -i security

# Verify BackendRef is reachable
kubectl get svc -n authelia authelia-ext-authz
```

### Issue 2: Redirect Loop (Login → Service → Login)

**Cause**: Session cookie not being set/read correctly

**Fix**:
```bash
# Check Authelia session domain in configmap
kubectl get cm authelia-config -n authelia -o yaml | grep -A5 "session:"

# Should have:
# cookies:
#   - domain: timourhomelab.org
#     authelia_url: https://auth.timourhomelab.org
```

### Issue 3: 401 Unauthorized After Login

**Cause**: LLDAP group membership issue

**Fix**:
```bash
# Check user's groups in LLDAP
kubectl exec -n lldap deploy/lldap-ldap -- \
  ldapsearch -x -H ldap://localhost:389 \
  -D "uid=admin,ou=people,dc=homelab,dc=local" \
  -w <admin-password> \
  -b "ou=groups,dc=homelab,dc=local" \
  "(member=uid=tim275,ou=people,dc=homelab,dc=local)"

# User must be in "cluster-admins" or "developers" group
```

### Issue 4: ForwardAuth Endpoint Not Responding

```bash
# Test Authelia's ForwardAuth endpoint directly
kubectl port-forward -n authelia svc/authelia-ext-authz 9091:9091

# In another terminal:
curl -v http://localhost:9091/api/authz/forward-auth

# Expected: 302 Found (redirect to login)
# Should NOT be 404 or 500
```

---

## 📚 References

- **Envoy Gateway SecurityPolicy**: https://gateway.envoyproxy.io/docs/api/extension_types/#securitypolicy
- **Authelia ForwardAuth**: https://www.authelia.com/integration/proxies/envoy/
- **Tailscale Split DNS**: https://tailscale.com/kb/1054/dns/
- **Zero Trust Architecture**: https://www.nist.gov/publications/zero-trust-architecture (NIST SP 800-207)

---

## 🚀 Status

- ✅ **Phase 1 Complete**: Tailscale VPN deployment (DNS config pending)
- ✅ **Phase 2 Ready**: SecurityPolicy + ExtAuth service created (disabled)
- ⏳ **Deployment**: Waiting for Phase 1 DNS confirmation before enabling Phase 2

**Next Action**: User confirms Phase 1 (VPN-only access works), then uncomment SecurityPolicy in kustomization.yaml
