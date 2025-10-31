# 🔐 ArgoCD RBAC Security Guide
## Production-Grade Permission Model

**Date**: 2025-10-31
**Status**: Production Security Best Practices

---

## 🎯 Security Principle: Least Privilege

**Regel**: User bekommen nur die Rechte die sie **wirklich brauchen**!

```
┌─────────────────────────────────────────────────────────┐
│  ❌ BAD: Alle können alles (auch löschen!)              │
│  ✅ GOOD: Granulare Rechte nach Rolle                   │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Permission Matrix

| Role           | Create | View | Update | Sync | Delete | Rollback |
|----------------|--------|------|--------|------|--------|----------|
| **admin**      | ✅     | ✅   | ✅     | ✅   | ✅     | ✅       |
| **developer**  | ✅     | ✅   | ✅     | ✅   | ❌     | ✅       |
| **deployer**   | ❌     | ✅   | ❌     | ✅   | ❌     | ❌       |
| **viewer**     | ❌     | ✅   | ❌     | ❌   | ❌     | ❌       |

---

## 🔑 Role Definitions

### 1. Admin (Full Access)

**Who**: Cluster admins, Platform team
**What**: Kann ALLES machen (auch löschen!)

```yaml
# Groups: cluster-admins
# Built-in role: role:admin
```

**Permissions**:
- ✅ Applications erstellen, editieren, löschen
- ✅ Repositories hinzufügen/entfernen
- ✅ Clusters hinzufügen/entfernen
- ✅ Projects erstellen/löschen
- ✅ Settings ändern

---

### 2. Developer (No Delete!)

**Who**: Application developers, DevOps Engineers
**What**: Kann Apps deployen und managen, aber NICHT löschen!

```yaml
# Groups: developers
# Custom role: role:developer
```

**Permissions**:
- ✅ Applications **erstellen** (create)
- ✅ Applications **ansehen** (get)
- ✅ Applications **editieren** (update)
- ✅ Applications **deployen** (sync)
- ✅ Applications **zurückrollen** (rollback)
- ❌ Applications **LÖSCHEN** (delete) ← VERBOTEN!
- ❌ Projects löschen
- ❌ Repositories löschen

**Example Actions**:
```bash
# ✅ Erlaubt
- Neue App deployen
- YAML Manifest ändern
- Sync triggern
- Rollback zu vorheriger Version

# ❌ VERBOTEN
- App löschen
- Project löschen
- Repository entfernen
```

---

### 3. Deployer (CI/CD Bot)

**Who**: CI/CD pipelines, Jenkins, GitHub Actions
**What**: Kann nur syncs triggern (deployment)

```yaml
# Groups: deployers, ci-runners
# Custom role: role:deployer
```

**Permissions**:
- ✅ Applications **ansehen** (get)
- ✅ Applications **deployen** (sync)
- ❌ Applications erstellen/editieren/löschen
- ❌ Settings ändern

**Use Case**: CI/CD Pipeline deployed code → triggert ArgoCD sync

---

### 4. Viewer (Read-Only)

**Who**: Stakeholders, Auditors, Support team
**What**: Kann nur ansehen, nichts ändern

```yaml
# Groups: viewers
# Custom role: role:viewer (or built-in role:readonly)
```

**Permissions**:
- ✅ Applications **ansehen** (get)
- ✅ Logs lesen
- ✅ Deployment status sehen
- ❌ Nichts ändern!

---

## 🛡️ Production RBAC Policy

### Complete ArgoCD RBAC ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # ========================================
  # 🛡️ DEFAULT POLICY: Deny All
  # ========================================
  # Users ohne explizite Group → read-only
  policy.default: role:readonly

  # ========================================
  # 🔐 GROUP-BASED RBAC POLICIES
  # ========================================
  policy.csv: |
    # ==========================================
    # ROLE: ADMIN (Full Access)
    # ==========================================
    # Built-in role:admin has all permissions
    g, cluster-admins, role:admin

    # ==========================================
    # ROLE: DEVELOPER (No Delete!)
    # ==========================================
    # ✅ Create applications
    p, role:developer, applications, create, */*, allow
    # ✅ View applications (get = read single, list = read all)
    p, role:developer, applications, get, */*, allow
    # ✅ Update applications (change YAML)
    p, role:developer, applications, update, */*, allow
    # ✅ Sync applications (deploy)
    p, role:developer, applications, sync, */*, allow
    # ✅ Override application (force sync)
    p, role:developer, applications, override, */*, allow
    # ✅ Rollback to previous version
    p, role:developer, applications, action/*, */*, allow
    # ❌ DELETE IS DENIED (not explicitly allowed → denied by default!)

    # Repository access (read-only)
    p, role:developer, repositories, get, *, allow
    p, role:developer, repositories, list, *, allow

    # Cluster access (read-only)
    p, role:developer, clusters, get, *, allow
    p, role:developer, clusters, list, *, allow

    # Projects access (read-only)
    p, role:developer, projects, get, *, allow

    # Logs access
    p, role:developer, logs, get, */*, allow

    # Exec into pods (optional - enable if needed)
    # p, role:developer, exec, create, */*, allow

    # Map LDAP group → ArgoCD role
    g, developers, role:developer

    # ==========================================
    # ROLE: DEPLOYER (CI/CD Bot)
    # ==========================================
    # ✅ View applications
    p, role:deployer, applications, get, */*, allow
    # ✅ Sync applications (deploy)
    p, role:deployer, applications, sync, */*, allow
    # ✅ View sync status
    p, role:deployer, applications, action/*, */*, allow
    # ❌ NO create/update/delete!

    # Map LDAP groups → ArgoCD role
    g, deployers, role:deployer
    g, ci-runners, role:deployer

    # ==========================================
    # ROLE: VIEWER (Read-Only)
    # ==========================================
    # ✅ View applications
    p, role:viewer, applications, get, */*, allow
    # ✅ View clusters
    p, role:viewer, clusters, get, *, allow
    # ✅ View repositories
    p, role:viewer, repositories, get, *, allow
    # ✅ View projects
    p, role:viewer, projects, get, *, allow
    # ✅ View logs
    p, role:viewer, logs, get, */*, allow
    # ❌ NO write access!

    # Map LDAP group → ArgoCD role
    g, viewers, role:viewer

  # ========================================
  # 🔍 SCOPES FOR OIDC
  # ========================================
  scopes: '[groups, email]'
```

---

## 🏗️ LLDAP Groups Setup

### Required Groups in LLDAP

Create these groups in LLDAP (via bootstrap or UI):

```yaml
# 1. cluster-admins (Full Admin)
cn: cluster-admins
description: Cluster administrators - full access to everything
members:
  - admin
  - tim275

# 2. developers (No Delete!)
cn: developers
description: Application developers - can deploy but not delete
members:
  - developer1
  - developer2

# 3. deployers (CI/CD)
cn: deployers
description: CI/CD deployment bots
members:
  - ci-user
  - github-actions-bot

# 4. viewers (Read-Only)
cn: viewers
description: Read-only access for stakeholders
members:
  - stakeholder1
  - auditor1
```

---

## 📋 Implementation Steps

### Step 1: Update RBAC ConfigMap

```bash
# 1. Edit ConfigMap
kubectl edit configmap argocd-rbac-cm -n argocd

# 2. Replace with production policy (see above)

# 3. Verify
kubectl get configmap argocd-rbac-cm -n argocd -o yaml | grep -A 50 "policy.csv"
```

### Step 2: Restart ArgoCD Server

```bash
# Restart to load new RBAC policy
kubectl rollout restart deployment argocd-server -n argocd

# Wait for rollout
kubectl rollout status deployment argocd-server -n argocd --timeout=120s
```

### Step 3: Create Groups in LLDAP

**Option A: Via LLDAP UI**

```
1. Open LLDAP: http://localhost:17170 (port-forward)
2. Login as admin
3. Navigate to "Groups"
4. Create: developers, deployers, viewers
5. Add users to groups
```

**Option B: Via Bootstrap (IaC)**

Edit: `kubernetes/platform/identity/lldap/bootstrap-groups.yaml`

```yaml
groups:
  - name: developers
    display_name: Application Developers
    members:
      - developer1
      - developer2

  - name: deployers
    display_name: CI/CD Deployers
    members:
      - ci-user

  - name: viewers
    display_name: Viewers (Read-Only)
    members:
      - stakeholder1
```

### Step 4: Sync LLDAP → Keycloak

```bash
# Keycloak Admin Console
# User Federation → ldap → "Sync all users" button

# Or via CLI:
kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh \
  config credentials --server http://localhost:8080 \
  --realm master --user admin --password "$ADMIN_PWD"

kubectl exec -n keycloak deploy/keycloak -- \
  /opt/keycloak/bin/kcadm.sh \
  push-config --target-realm kubernetes
```

---

## 🧪 Testing RBAC Permissions

### Test as Developer (No Delete!)

```bash
# 1. Login to ArgoCD as developer user
# https://argo.timourhomelab.org

# 2. Try to create app (should work ✅)
# Click "NEW APP" → Should see form

# 3. Try to sync app (should work ✅)
# Click "SYNC" → Should trigger deployment

# 4. Try to delete app (should FAIL ❌)
# Click "DELETE" → Should show error:
# "permission denied: applications, delete, <app-name>"
```

### Test with argocd CLI

```bash
# Login as developer
argocd login argo.timourhomelab.org --sso --grpc-web

# ✅ Should work
argocd app get my-app
argocd app sync my-app

# ❌ Should FAIL
argocd app delete my-app
# Error: permission denied: applications, delete, my-app
```

---

## 🔍 RBAC Audit Commands

### Check Current Policy

```bash
# Get RBAC policy
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Check specific user permissions
argocd account can-i sync applications '*'
argocd account can-i delete applications '*'
```

### Test Policy for User

```bash
# Login as specific user
argocd login argo.timourhomelab.org --sso --username developer1

# Check what user can do
argocd account can-i '*' applications '*'
```

### View Audit Logs

```bash
# Check ArgoCD logs for permission denials
kubectl logs -n argocd deployment/argocd-server | grep "permission denied"
```

---

## ⚠️ Common Mistakes

### Mistake 1: Wildcard Permissions

```yaml
# ❌ BAD - Gives DELETE access!
p, role:developer, applications, *, */*, allow

# ✅ GOOD - Explicitly list allowed actions
p, role:developer, applications, create, */*, allow
p, role:developer, applications, get, */*, allow
p, role:developer, applications, sync, */*, allow
```

### Mistake 2: Missing Group Mapping

```yaml
# ❌ BAD - Permissions defined but no group mapping
p, role:developer, applications, sync, */*, allow
# Missing: g, developers, role:developer

# ✅ GOOD - Map LDAP group to role
p, role:developer, applications, sync, */*, allow
g, developers, role:developer  # ← REQUIRED!
```

### Mistake 3: Wrong Default Policy

```yaml
# ❌ BAD - Everyone has admin by default!
policy.default: role:admin

# ✅ GOOD - Deny by default, explicit allow
policy.default: role:readonly
```

---

## 📚 ArgoCD Permission Actions

### Application Actions

```
create   - Create new application
get      - View single application
list     - List all applications
update   - Update application spec
delete   - Delete application ← CRITICAL!
sync     - Trigger deployment
override - Force sync
action/* - Execute actions (rollback, restart, etc.)
```

### Project Actions

```
create   - Create project
get      - View project
update   - Update project
delete   - Delete project ← CRITICAL!
```

### Repository Actions

```
create   - Add repository
get      - View repository
update   - Update repository
delete   - Remove repository ← CRITICAL!
```

### Cluster Actions

```
create   - Add cluster
get      - View cluster
update   - Update cluster
delete   - Remove cluster ← CRITICAL!
```

---

## 🔐 Production Security Checklist

- [ ] Default policy set to `role:readonly`
- [ ] Admin role limited to `cluster-admins` group
- [ ] Developer role **cannot delete** applications
- [ ] Deployer role **only** has sync permission
- [ ] Viewer role is **read-only**
- [ ] All groups exist in LLDAP
- [ ] Groups synced to Keycloak
- [ ] RBAC policy tested with real users
- [ ] Audit logging enabled
- [ ] Permission denials logged and monitored

---

## 📊 Example User Scenarios

### Scenario 1: New Developer

```
User: developer-sarah
Group: developers
Access:
  ✅ View all applications
  ✅ Create new application for her service
  ✅ Update application YAML
  ✅ Trigger deployment (sync)
  ✅ Rollback if deployment fails
  ❌ Cannot delete applications
  ❌ Cannot add/remove repositories
```

### Scenario 2: CI/CD Pipeline

```
User: github-actions-bot
Group: deployers, ci-runners
Access:
  ✅ View application status
  ✅ Trigger deployment after successful build
  ❌ Cannot create applications
  ❌ Cannot modify application spec
  ❌ Cannot delete anything
```

### Scenario 3: Stakeholder

```
User: product-owner-mike
Group: viewers
Access:
  ✅ View all deployments
  ✅ See deployment status
  ✅ Read application logs
  ❌ Cannot change anything
  ❌ Cannot trigger deployments
```

---

## 🚨 Emergency: Restore Deleted App

If someone accidentally deletes an application:

```bash
# 1. Check Git history (apps are in Git!)
cd kubernetes/apps
git log -- path/to/deleted-app/

# 2. Restore from Git
git checkout HEAD~1 -- path/to/deleted-app/

# 3. Commit and push
git add path/to/deleted-app/
git commit -m "fix: restore accidentally deleted app"
git push

# 4. ArgoCD auto-sync will restore the app!
```

**This is why Git is your source of truth!** 🎯

---

## 📝 Summary

**3 Critical Rules**:

1. **Default Deny**: `policy.default: role:readonly`
2. **No Wildcard**: Never use `applications, *, */*, allow`
3. **Explicit Allow**: List exact actions: `create, get, update, sync`

**Result**: Developers can deploy, but only admins can delete! ✅

---

**Last Updated**: 2025-10-31
**Author**: Tim275 + Claude
**Status**: ✅ Production Security Best Practices
