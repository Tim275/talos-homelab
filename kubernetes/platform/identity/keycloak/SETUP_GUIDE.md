# 🔐 Keycloak + LLDAP Enterprise SSO Setup

## 🎯 Goal
Configure Keycloak as Enterprise OIDC Provider with LLDAP as user directory backend

## 📍 Access Information

### Keycloak Admin Console
- **URL**: https://iam.timourhomelab.org
- **Username**: `admin`
- **Password**: (Get via: `kubectl get secret -n keycloak keycloak-admin -o jsonpath='{.data.password}' | base64 -d`)

### LLDAP Admin
- **URL**: http://lldap.lldap.svc.cluster.local:17170 (or port-forward)
- **Username**: `admin`
- **Password**: `homelab-admin-2024`

---

## 🔧 STEP 1: Create Realm in Keycloak

1. Open Keycloak Admin Console: https://iam.timourhomelab.org
2. Login with admin credentials
3. Click **"Create Realm"** (top-left dropdown)
4. Enter:
   - **Realm name**: `homelab`
   - **Enabled**: ✅
5. Click **"Create"**

---

## 🔗 STEP 2: Configure LDAP Federation

### 2.1 Add LDAP User Federation

1. In `homelab` realm, go to: **User Federation**
2. Click **"Add LDAP Provider"**
3. Configure **Required Settings**:

```yaml
# Console mode: OFF (we want form view)
Vendor: Other
Connection URL: ldap://lldap-ldap.lldap.svc.cluster.local:389
Users DN: ou=people,dc=homelab,dc=local
Authentication type: simple
Bind DN: uid=admin,ou=people,dc=homelab,dc=local
Bind credentials: homelab-admin-2024

Custom User LDAP Filter: (leave empty)
Search Scope: Subtree

# Important LDAP Attributes
UUID LDAP attribute: entryUUID
RDN LDAP attribute: uid
Username LDAP attribute: uid
User Object Classes: inetOrgPerson, posixAccount

# Sync Settings
Edit Mode: WRITABLE (or READ_ONLY if you want Keycloak to not modify LDAP)
Sync Registrations: ON (if WRITABLE)
Import Users: ON
Batch Size: 1000

# Connection & Authentication
Connection Pooling: ON
Connection Timeout: 10000
Read Timeout: 10000
Pagination: ON
Allow Kerberos authentication: OFF
Use Truststore SPI: LDAP only (no TLS for internal cluster DNS)
```

4. Click **"Test connection"** → Should show "Success"
5. Click **"Test authentication"** → Should show "Success"
6. Click **"Save"**

### 2.2 Sync Users from LLDAP

1. After saving, scroll to bottom
2. Click **"Synchronize all users"**
3. Verify users appear in: **Users** (left menu)

---

## 👥 STEP 3: Configure LDAP Group Mapper

1. In LDAP provider settings, go to **"Mappers"** tab
2. Click **"Create"**
3. Configure:

```yaml
Name: groups
Mapper Type: group-ldap-mapper

LDAP Groups DN: ou=groups,dc=homelab,dc=local
Group Name LDAP Attribute: cn
Group Object Classes: groupOfUniqueNames
Membership LDAP Attribute: uniqueMember
Membership Attribute Type: DN
Membership User LDAP Attribute: uid

Mode: READ_ONLY
User Groups Retrieve Strategy: LOAD_GROUPS_BY_MEMBER_ATTRIBUTE
Member-Of LDAP Attribute: memberOf
Mapped Group Attributes: (leave empty)
Drop non-existing groups during sync: OFF

Groups Path: / (root path for groups)
```

4. Click **"Save"**
5. Click **"Sync LDAP Groups To Keycloak"** at bottom

---

## 🔐 STEP 4: Create OIDC Client for Kubernetes

1. Go to: **Clients** (left menu)
2. Click **"Create client"**
3. **General Settings**:
   ```
   Client type: OpenID Connect
   Client ID: kubernetes
   Name: Kubernetes API Server
   Description: OIDC client for kubectl access
   ```
4. Click **"Next"**

5. **Capability config**:
   ```
   Client authentication: ON (confidential client)
   Authorization: OFF
   Authentication flow:
   ✅ Standard flow
   ✅ Direct access grants
   ❌ Implicit flow
   ❌ Service accounts roles
   ```
6. Click **"Next"**

7. **Login settings**:
   ```
   Root URL: https://k8s.homelab.local
   Valid redirect URIs:
     http://localhost:8000
     http://localhost:18000
     http://localhost:8080
     urn:ietf:wg:oauth:2.0:oob

   Web origins: *
   ```
8. Click **"Save"**

9. Go to **"Credentials"** tab → Copy **Client Secret** (save for later!)

10. Go to **"Client scopes"** tab → Click on `kubernetes-dedicated`
11. Click **"Add mapper"** → **"By configuration"** → **"Group Membership"**
12. Configure:
    ```
    Name: groups
    Token Claim Name: groups
    Full group path: OFF
    Add to ID token: ON
    Add to access token: ON
    Add to userinfo: ON
    ```
13. Click **"Save"**

---

## 📊 STEP 5: Create OIDC Client for Grafana

1. **Clients** → **"Create client"**
2. **General Settings**:
   ```
   Client ID: grafana
   Name: Grafana
   ```

3. **Capability config**:
   ```
   Client authentication: ON
   Standard flow: ✅
   Direct access grants: ✅
   ```

4. **Login settings**:
   ```
   Root URL: https://grafana.timourhomelab.org
   Valid redirect URIs:
     https://grafana.timourhomelab.org/login/generic_oauth

   Web origins: https://grafana.timourhomelab.org
   ```

5. Save → Get **Client Secret** from Credentials tab

6. Add **groups mapper** (same as Kubernetes)

---

## 🚀 STEP 6: Create OIDC Client for ArgoCD

1. **Clients** → **"Create client"**
2. **General Settings**:
   ```
   Client ID: argocd
   Name: ArgoCD
   ```

3. **Capability config**:
   ```
   Client authentication: ON
   Standard flow: ✅
   Direct access grants: ✅
   ```

4. **Login settings**:
   ```
   Root URL: https://argocd.timourhomelab.org
   Valid redirect URIs:
     https://argocd.timourhomelab.org/auth/callback
     https://argocd.timourhomelab.org/api/dex/callback

   Web origins: https://argocd.timourhomelab.org
   ```

5. Save → Get **Client Secret**

6. Add **groups mapper**

---

## 🧪 STEP 7: Test LDAP Integration

### Verify Users Synced

1. Go to **Users** (left menu)
2. You should see users from LLDAP (e.g., `admin`, etc.)
3. Click on a user → **Groups** tab → Should show LDAP groups

### Verify Groups Synced

1. Go to **Groups** (left menu)
2. You should see groups from LLDAP (e.g., `admins`, `lldap_strict_readonly`, etc.)

---

## 📝 NEXT STEPS

After Keycloak is configured:

1. **Configure Kubernetes API Server** for OIDC authentication
2. **Update Grafana** values with Keycloak OIDC config
3. **Update ArgoCD** with Keycloak OIDC config
4. **Test kubectl** with OIDC login

---

## 🔑 Quick Reference

### Keycloak OIDC Endpoints (homelab realm)

```
Issuer URL: https://iam.timourhomelab.org/realms/homelab
Authorization: https://iam.timourhomelab.org/realms/homelab/protocol/openid-connect/auth
Token: https://iam.timourhomelab.org/realms/homelab/protocol/openid-connect/token
UserInfo: https://iam.timourhomelab.org/realms/homelab/protocol/openid-connect/userinfo
JWKS: https://iam.timourhomelab.org/realms/homelab/protocol/openid-connect/certs
```

### LLDAP Connection Info

```
LDAP Host: lldap-ldap.lldap.svc.cluster.local
LDAP Port: 389
Base DN: dc=homelab,dc=local
Admin DN: uid=admin,ou=people,dc=homelab,dc=local
Users DN: ou=people,dc=homelab,dc=local
Groups DN: ou=groups,dc=homelab,dc=local
```

---

## ✅ Verification Checklist

- [ ] Keycloak accessible at https://iam.timourhomelab.org
- [ ] Realm "homelab" created
- [ ] LDAP federation configured
- [ ] Users synced from LLDAP
- [ ] Groups synced from LLDAP
- [ ] OIDC client "kubernetes" created with groups mapper
- [ ] OIDC client "grafana" created
- [ ] OIDC client "argocd" created
- [ ] Test user login works in Keycloak

---

**Status**: Ready for integration! 🚀
