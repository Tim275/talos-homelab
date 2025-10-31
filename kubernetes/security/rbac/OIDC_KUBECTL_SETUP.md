# 🔐 kubectl OIDC Authentication Setup

**End-User Guide**: Configure kubectl to authenticate via Authelia OIDC instead of certificates

---

## 📋 **Prerequisites**

✅ Talos OIDC patches applied to control plane nodes
✅ Authelia running with kubernetes OIDC client
✅ RBAC ClusterRoleBindings deployed for your user/group
✅ kubectl installed on local machine

---

## 🚀 **Installation**

### **1. Install kubelogin Plugin**

**macOS (Homebrew):**
```bash
brew install int128/kubelogin/kubelogin
```

**Linux:**
```bash
# Download latest release
VERSION=$(curl -s https://api.github.com/repos/int128/kubelogin/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -LO https://github.com/int128/kubelogin/releases/download/${VERSION}/kubelogin_linux_amd64.zip
unzip kubelogin_linux_amd64.zip
sudo mv kubelogin /usr/local/bin/
```

**Verification:**
```bash
kubectl oidc-login --version
```

---

## ⚙️ **Kubeconfig Setup**

### **Method 1: Add OIDC User to Existing Kubeconfig**

```bash
# Add OIDC user configuration
kubectl config set-credentials oidc-user \
  --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=https://authelia.homelab.local \
  --exec-arg=--oidc-client-id=kubernetes \
  --exec-arg=--oidc-extra-scope=email \
  --exec-arg=--oidc-extra-scope=profile \
  --exec-arg=--oidc-extra-scope=groups

# Create new context using OIDC user
kubectl config set-context oidc-context \
  --cluster=homelab \
  --user=oidc-user

# Switch to OIDC context
kubectl config use-context oidc-context
```

### **Method 2: Complete OIDC Kubeconfig File**

Create `~/.kube/config-oidc`:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: homelab
  cluster:
    server: https://your-cluster-api:6443
    certificate-authority-data: <BASE64_CA_CERT>
users:
- name: oidc-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: kubectl
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://authelia.homelab.local
      - --oidc-client-id=kubernetes
      - --oidc-extra-scope=email
      - --oidc-extra-scope=profile
      - --oidc-extra-scope=groups
      interactiveMode: IfAvailable
contexts:
- name: oidc-context
  context:
    cluster: homelab
    user: oidc-user
current-context: oidc-context
```

**Switch to OIDC kubeconfig:**
```bash
export KUBECONFIG=~/.kube/config-oidc
```

---

## 🔑 **First Login Flow**

### **1. Run kubectl Command**
```bash
kubectl get nodes
```

### **2. Browser Opens Automatically**
- You'll be redirected to Authelia login page
- URL: `https://authelia.homelab.local`

### **3. Authenticate in Browser**
1. Enter LLDAP username (e.g., `tim275`)
2. Enter password
3. Complete 2FA if enabled (TOTP, WebAuthn)
4. Authelia shows: "Authentication successful"
5. Browser can be closed

### **4. Token Cached Locally**
- kubelogin stores token in `~/.kube/cache/oidc-login/`
- Token valid for 1 hour (default)
- Automatic refresh when expired (re-opens browser)

### **5. kubectl Command Succeeds**
```bash
kubectl get nodes
# Output shows cluster nodes (if RBAC permits)
```

---

## 🧪 **Testing RBAC**

### **Verify Your Identity**
```bash
# Check who you are authenticated as
kubectl auth whoami

# Expected output:
# ATTRIBUTE   VALUE
# Username    oidc:tim275
# Groups      [oidc:admins system:authenticated]
```

### **Test Permissions**
```bash
# Check if you can create deployments
kubectl auth can-i create deployments
# Expected: yes (if you have cluster-admin)

# Check if you can list secrets
kubectl auth can-i list secrets
# Expected: yes (if you have cluster-admin)

# Check namespaced access
kubectl auth can-i create pods --namespace=default
# Expected: yes
```

---

## 🔄 **Token Refresh Behavior**

### **Automatic Refresh**
- kubelogin automatically detects expired tokens
- Opens browser for re-authentication
- User must login again (no refresh tokens)

### **Manual Token Refresh**
```bash
kubectl oidc-login get-token \
  --oidc-issuer-url=https://authelia.homelab.local \
  --oidc-client-id=kubernetes \
  --oidc-extra-scope=email \
  --oidc-extra-scope=profile \
  --oidc-extra-scope=groups
```

### **Clear Cached Tokens**
```bash
rm -rf ~/.kube/cache/oidc-login/
```

---

## 🛠️ **Troubleshooting**

### **Problem: "No RBAC policy matched"**
**Symptom:**
```
Error from server (Forbidden): nodes is forbidden: User "oidc:tim275" cannot list resource "nodes"
```

**Solution:**
1. Check if ClusterRoleBinding exists:
   ```bash
   kubectl get clusterrolebinding oidc-tim275-cluster-admin
   ```
2. Verify subject matches your username:
   ```bash
   kubectl get clusterrolebinding oidc-tim275-cluster-admin -o yaml | grep -A3 subjects
   ```
3. Expected output:
   ```yaml
   subjects:
   - kind: User
     name: oidc:tim275  # ⚠️ Must match exactly!
   ```

### **Problem: "Failed to refresh token"**
**Symptom:**
```
error: failed to refresh token: oauth2: cannot fetch token
```

**Solution:**
1. Check Authelia is accessible:
   ```bash
   curl https://authelia.homelab.local/.well-known/openid-configuration
   ```
2. Verify OIDC client configuration in Authelia
3. Check kube-apiserver OIDC flags:
   ```bash
   kubectl logs -n kube-system -l component=kube-apiserver | grep oidc
   ```

### **Problem: Browser doesn't open**
**Symptom:**
```
Please visit the following URL in your browser: https://authelia.homelab.local/...
```

**Solution:**
1. Copy URL manually and paste in browser
2. Or add `--oidc-use-pkce=false` to skip PKCE (less secure)

### **Problem: Certificate validation error**
**Symptom:**
```
x509: certificate signed by unknown authority
```

**Solution:**
1. Ensure Authelia uses valid TLS certificate (not self-signed)
2. Or add CA certificate to system trust store
3. Or use `--certificate-authority=/path/to/ca.crt` in kubelogin args (NOT recommended)

---

## 📊 **Comparison: Certificates vs OIDC**

| Feature | X.509 Certificates | OIDC (Authelia) |
|---------|-------------------|-----------------|
| **Expiration** | 1 year (manual renewal) | 1 hour (auto refresh) |
| **Revocation** | Difficult (need CRL) | Easy (LDAP user disable) |
| **2FA** | Not supported | Supported (TOTP, WebAuthn) |
| **Group Mapping** | Manual CN parsing | Automatic (LDAP groups) |
| **Audit Logging** | kubectl audit logs only | Authelia + kubectl logs |
| **User Management** | Manual CSR signing | LLDAP central management |
| **Best For** | CI/CD, automation | Human users |

---

## 🔐 **Security Best Practices**

### **DO:**
✅ Use OIDC for human users (developers, admins)
✅ Use certificates for CI/CD pipelines (GitHub Actions)
✅ Enable 2FA in Authelia for all users
✅ Set short token expiration (1 hour)
✅ Review RBAC policies regularly

### **DON'T:**
❌ Share OIDC credentials between users
❌ Disable certificate validation for Authelia
❌ Use `cluster-admin` for all users (use least privilege)
❌ Store OIDC tokens in version control
❌ Use OIDC for service accounts (use Kubernetes SA tokens)

---

## 📚 **References**

- **kubelogin GitHub**: https://github.com/int128/kubelogin
- **Kubernetes OIDC**: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens
- **Authelia OIDC**: https://www.authelia.com/integration/openid-connect/introduction/
- **RBAC Authorization**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

---

**Next Steps**: After successful login, configure additional RBAC policies for granular access control.
