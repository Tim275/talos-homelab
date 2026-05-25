# OMS Tenant Authentication Methods

**Namespace:** `oms`
**Status:** ServiceAccount Token (Interim) → OIDC (Planned)

---

## Method 1: ServiceAccount Token (CURRENT - Interim Solution)

**Use Case:** Quick start, temporary until OIDC is ready
**Security Level:** Good for development/early stage
**Rotation:** Manual, every 90 days

### Setup Steps

```bash
# 1. Create ServiceAccount + RBAC (already done via kustomize)
kubectl create serviceaccount oms-admin -n oms

kubectl create rolebinding oms-admin-binding \
  --clusterrole=admin \
  --serviceaccount=oms:oms-admin \
  --namespace=oms

# 2. Generate long-lived token (90 days)
kubectl create token oms-admin -n oms --duration=2160h > oms-token.txt

# 3. Get CA certificate
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt

# 4. Create kubeconfig
kubectl config set-cluster homelab-cluster \
  --server=https://YOUR-API-SERVER:6443 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=oms-kubeconfig.yaml

kubectl config set-credentials oms-admin \
  --token=$(cat oms-token.txt) \
  --kubeconfig=oms-kubeconfig.yaml

kubectl config set-context oms-context \
  --cluster=homelab-cluster \
  --user=oms-admin \
  --namespace=oms \
  --kubeconfig=oms-kubeconfig.yaml

kubectl config use-context oms-context --kubeconfig=oms-kubeconfig.yaml

# 5. Deliver kubeconfig securely (Vault, Sealed Secrets, etc.)
```

### Tenant Usage

```bash
export KUBECONFIG=~/oms-kubeconfig.yaml
kubectl get pods                    #  Works - sees only oms namespace
kubectl get pods -n monitoring      #  Error: Forbidden
```

### Pros & Cons

**Pros:**
-  Quick setup (5 minutes)
-  Simple to rotate (new token, new kubeconfig)
-  Good enough for interim period

**Cons:**
-  No user attribution (all actions as "system:serviceaccount:oms:oms-admin")
-  Manual rotation every 90 days
-  No MFA
-  No automatic revocation

### Rotation Policy

- **Frequency:** Every 90 days
- **Process:** Generate new token, update kubeconfig, distribute to tenant
- **Revocation:** Delete RoleBinding to revoke access immediately

---

## Method 2: OIDC (ENTERPRISE - Planned)

**Use Case:** Production, Tier 0 security
**Security Level:** Enterprise-grade
**Rotation:** Automatic (short-lived tokens)

### Architecture

```
User (oms-developer@company.com)
    ↓ kubectl (with oidc-login plugin)
Keycloak / Azure AD / Okta
    ↓ OIDC Token (1h expiry, auto-refresh)
Kubernetes API Server (Talos)
    ↓ Validates token, maps groups to RBAC
Authorized!
```

### Prerequisites

1. **Keycloak deployed** (or Azure AD/Okta)
2. **OIDC Client configured** in Keycloak
3. **Groups configured** (e.g., `oms-developers`, `oms-admins`)
4. **Talos API Server configured** with OIDC params

### Talos Configuration

```yaml
# Talos Machine Config
cluster:
  apiServer:
    extraArgs:
      oidc-issuer-url: https://keycloak.homelab.local/realms/kubernetes
      oidc-client-id: kubernetes
      oidc-username-claim: preferred_username
      oidc-groups-claim: groups
      oidc-groups-prefix: "keycloak-"
```

### RBAC Configuration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: oms-developers-oidc-binding
  namespace: oms
roleRef:
  kind: ClusterRole
  name: admin
subjects:
  - kind: Group
    name: keycloak-oms-developers  # ← Keycloak Group
    apiGroup: rbac.authorization.k8s.io
```

### Tenant Setup

```bash
# 1. User installs kubectl plugin
kubectl krew install oidc-login

# 2. Configure OIDC
kubectl oidc-login setup \
  --oidc-issuer-url=https://keycloak.homelab.local/realms/kubernetes \
  --oidc-client-id=kubernetes

# 3. Login (opens browser for Keycloak login with MFA)
kubectl oidc-login get-token

# 4. Use kubectl normally
kubectl get pods -n oms  #  Works if user in "oms-developers" group
```

### Tenant Usage

```bash
# First time: Login via browser
kubectl oidc-login get-token

# After that: Normal kubectl usage
kubectl get pods                    #  Works
kubectl logs pod-xyz                #  Works
kubectl delete pod-xyz              #  Works (if RBAC allows)

# Token auto-refreshes every hour!
```

### Pros & Cons

**Pros:**
-  **Centralized Identity** - Single source of truth (Keycloak/Azure AD)
-  **Short-lived tokens** - Auto-expiration (1h), auto-refresh
-  **MFA support** - Multi-Factor Authentication from Identity Provider
-  **Automatic revocation** - User leaves company → account disabled → zero cluster access
-  **Group-based RBAC** - RBAC based on groups, not individual users
-  **Audit trail** - Who did what when (Identity Provider + K8s Audit Logs)
-  **SSO** - Same credentials as Office365, Slack, etc.
-  **No shared secrets** - No kubeconfig files with tokens to distribute

**Cons:**
-  Requires OIDC setup (Keycloak/Azure AD/Okta)
-  More complex initial setup

### Security Features

1. **Token Expiry:** 1 hour (configurable)
2. **Auto-Refresh:** Transparent to user
3. **MFA:** Required by Identity Provider
4. **Revocation:** Instant when user disabled in Keycloak
5. **Audit:** Full audit trail in Keycloak + K8s

---

## Migration Path

### Phase 1: Now (ServiceAccount Token)
```
ServiceAccount Token → kubeconfig → Tenant
```

### Phase 2: Keycloak Setup (Parallel)
- Deploy Keycloak
- Create OIDC Client
- Configure Groups (oms-developers, oms-admins)
- Test OIDC login

### Phase 3: Talos Configuration
- Update Talos Machine Config with OIDC params
- Apply changes to control plane nodes

### Phase 4: RBAC Migration
```bash
# Create new RoleBinding with OIDC groups
kubectl apply -f oidc-rolebinding.yaml

# Test with OIDC users
kubectl oidc-login get-token
kubectl get pods -n oms

# If successful: Revoke ServiceAccount access
kubectl delete rolebinding oms-admin-binding -n oms
```

### Phase 5: Cleanup
- Delete ServiceAccount
- Remove old kubeconfig files
- Document OIDC login process for tenants

---

## Current Status

**Active Method:** ServiceAccount Token
**Token Expiry:** 90 days (manual rotation required)
**Next Steps:**
1. Deploy Keycloak in cluster
2. Configure OIDC client
3. Update Talos API Server config
4. Migrate to OIDC
5. Revoke ServiceAccount tokens

**Last Updated:** 2025-11-20
**Owner:** Platform Team
