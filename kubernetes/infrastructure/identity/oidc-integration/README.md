# 🔐 Kubernetes OIDC Integration

**Infrastructure Layer**: kube-apiserver OIDC authentication configuration

---

## 📋 **What This Does**

Configures kube-apiserver to accept OIDC tokens from Authelia instead of X.509 certificates for user authentication.

**Authentication Flow:**
```
User → Authelia (LLDAP) → OIDC Token → kubectl → kube-apiserver → RBAC → Access
```

---

## 🏗️ **Architecture**

### **Components:**
1. **Authelia** (Platform) - OIDC Provider (`https://authelia.homelab.local`)
2. **LLDAP** (Platform) - User Directory (LDAP backend for Authelia)
3. **kube-apiserver** (Infrastructure) - OIDC token validation
4. **RBAC** (Security) - Authorization policies (ClusterRoleBindings)

### **Token Flow:**
```
┌─────────┐      ┌──────────┐      ┌──────────────┐      ┌──────┐
│ Browser │─────▶│ Authelia │─────▶│ kube-apiserver│─────▶│ RBAC │
│  Login  │      │   OIDC   │      │   Validates  │      │Check │
└─────────┘      └──────────┘      └──────────────┘      └──────┘
                      │                    │
                      │                    │
                 ┌────▼─────┐         ┌───▼────┐
                 │  LLDAP   │         │ Groups │
                 │  Users   │         │Mapping │
                 └──────────┘         └────────┘
```

---

## 🚀 **Implementation Steps**

### **1. Apply Talos Machine Config Patch**

**For all control plane nodes:**

```bash
# Control Plane Node 1
talosctl patch mc --nodes cp-01 \
  --patch @kubernetes/infrastructure/identity/oidc-integration/talos-patches/apiserver-oidc.yaml

# Control Plane Node 2 (if HA)
talosctl patch mc --nodes cp-02 \
  --patch @kubernetes/infrastructure/identity/oidc-integration/talos-patches/apiserver-oidc.yaml

# Control Plane Node 3 (if HA)
talosctl patch mc --nodes cp-03 \
  --patch @kubernetes/infrastructure/identity/oidc-integration/talos-patches/apiserver-oidc.yaml
```

**Verification:**
```bash
# Check kube-apiserver logs for OIDC configuration
kubectl logs -n kube-system -l component=kube-apiserver --tail=50 | grep oidc

# Expected output:
# --oidc-issuer-url=https://authelia.homelab.local
# --oidc-client-id=kubernetes
# --oidc-username-claim=preferred_username
# --oidc-groups-claim=groups
```

---

## 🔑 **OIDC Parameters Explained**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `oidc-issuer-url` | `https://authelia.homelab.local` | Authelia OIDC endpoint where kube-apiserver validates tokens |
| `oidc-client-id` | `kubernetes` | Client ID registered in Authelia for kubectl |
| `oidc-username-claim` | `preferred_username` | JWT claim containing username (e.g., "tim275") |
| `oidc-groups-claim` | `groups` | JWT claim containing LDAP groups (e.g., ["admins"]) |
| `oidc-username-prefix` | `oidc:` | Prefix for usernames in RBAC (becomes "oidc:tim275") |
| `oidc-groups-prefix` | `oidc:` | Prefix for groups in RBAC (becomes "oidc:admins") |

**Why Prefixes?**
- Prevents collision with existing Kubernetes users (e.g., ServiceAccounts)
- Makes OIDC users easily identifiable in RBAC policies
- Best practice for multi-auth environments

---

## 🛡️ **Security Considerations**

### **TLS Certificate Validation:**
- Authelia **MUST** use valid HTTPS certificate
- Talos validates against system CA bundle (`/etc/ssl/certs/ca-certificates.crt`)
- Self-signed certificates will be **rejected** (use cert-manager with Let's Encrypt)

### **Token Validation:**
- kube-apiserver validates JWT signature against Authelia's public key
- Tokens expire (default: 1 hour)
- No refresh tokens (user must re-authenticate)

### **RBAC Required:**
- OIDC provides **authentication** (WHO you are)
- RBAC provides **authorization** (WHAT you can do)
- Without RBAC ClusterRoleBindings, OIDC users have **no permissions**

---

## 🔄 **Next Steps**

After applying Talos patches:

1. **Create RBAC mappings** → `kubernetes/security/rbac/oidc-users/`
2. **Setup kubelogin** → Local kubectl OIDC client configuration
3. **Test authentication** → `kubectl get nodes --user=oidc:tim275`

---

## 📚 **References**

- **Talos OIDC Guide**: https://www.talos.dev/v1.8/kubernetes-guides/configuration/oidc/
- **Kubernetes OIDC**: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens
- **Authelia OIDC**: https://www.authelia.com/integration/openid-connect/introduction/
- **kubelogin Plugin**: https://github.com/int128/kubelogin

---

**Status**: Infrastructure patches ready, RBAC mappings pending
**Dependencies**: Authelia (running), LLDAP (running), cert-manager (running)
**Layer**: Infrastructure (authentication mechanism)
