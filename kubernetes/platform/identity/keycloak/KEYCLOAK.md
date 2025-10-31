# Keycloak LDAP Federation Configuration

**Date**: 2025-10-13
**Status**: Production-ready
**LDAP Backend**: LLDAP (lldap.lldap.svc.cluster.local:3890)

---

## Overview

Keycloak uses LDAP User Federation to sync users from LLDAP. Users are managed as **Infrastructure as Code** in LLDAP bootstrap configs, then synced to Keycloak.

---

## Complete LDAP Provider Configuration

### General Options
```yaml
UI display name: ldap
Vendor: Other  # IMPORTANT: NOT "Active Directory"!
```

### Connection and Authentication
```yaml
Connection URL: ldap://lldap.lldap.svc.cluster.local:3890
Enable StartTLS: Off
Use Truststore SPI: Always
Connection pooling: Off
Connection timeout: (default)
Bind type: simple
Bind DN: uid=admin,ou=people,dc=homelab,dc=local
Bind credentials: <LLDAP admin password>
```

### LDAP Searching and Updating
```yaml
Edit mode: WRITABLE
Users DN: ou=people,dc=homelab,dc=local

# CRITICAL: Use LLDAP attributes (NOT Active Directory!)
Username LDAP attribute: uid
RDN LDAP attribute: uid
UUID LDAP attribute: entryUUID

# Object Classes
User object classes: person
User LDAP filter: (leave empty)

# Search Settings
Search scope: Subtree  # NOT "One Level"!
Read timeout: (default)
Pagination: Off
Referral: (default)
```

### Synchronization Settings
```yaml
Import users: On
Sync Registrations: Off
Batch size: 1000

# IMPORTANT: Disable periodic sync (LLDAP doesn't support whenCreated/whenChanged)
Periodic full sync: Off
Periodic changed users sync: Off
```

### Kerberos Integration
```yaml
Allow Kerberos authentication: Off
Use Kerberos for password authentication: Off
```

### Cache Settings
```yaml
Cache policy: NO_CACHE  # Prevents automatic changed-user sync attempts
```

### Advanced Settings
```yaml
Enable LDAPv3 password modify extended operation: Off
Validate password policy: Off
Trust Email: Off
```

---

## Troubleshooting

### Issue: "0 users imported, 0 users updated"

**Symptoms:**
```
Sync all users finished: 0 imported users, 0 updated users
```

**Causes & Fixes:**

1. **Wrong Vendor Setting**
   - Problem: Vendor set to "Active Directory"
   - Fix: Change to **"Other"**
   - Why: LLDAP uses standard LDAP attributes, not AD-specific ones

2. **Wrong LDAP Attributes**
   - Problem: Using AD attributes (cn, objectGUID)
   - Fix: Use LLDAP attributes:
     - Username: **uid** (not cn)
     - UUID: **entryUUID** (not objectGUID)

3. **Wrong Port**
   - Problem: Connection URL uses port 389
   - Fix: Use port **3890** (LLDAP default)

4. **Wrong Search Scope**
   - Problem: Search scope set to "One Level"
   - Fix: Set to **"Subtree"** for recursive search

5. **Wrong Object Classes**
   - Problem: Using AD classes (person, organizationalPerson, user)
   - Fix: Use **"person"** only

### Issue: "NamingError" - whenCreated/whenChanged not supported

**Symptoms:**
```
ERROR: Unsupported user filter: GreaterOrEqual("whenCreated", ...)
Could not sync users: 'NamingError'
```

**Cause:**
- Keycloak tries to use Active Directory operational attributes
- LLDAP doesn't support `whenCreated` or `whenChanged`

**Fix:**
1. Ensure Vendor is set to **"Other"** (not "Active Directory")
2. Disable "Periodic changed users sync"
3. Set Cache policy to **"NO_CACHE"**

### Issue: Users not visible in Keycloak UI

**Symptoms:**
```
Users → "This realm may have a federated provider..."
```

**This is normal!** Federated users are lazy-loaded.

**To see all users:**
- Search for `*` (asterisk) in the Users search box
- Users will show with "Federation Link: ldap"

---

## Manual Sync Procedure

After LLDAP bootstrap job runs (or manual LLDAP changes):

1. **Keycloak Admin Console**
2. **User Federation** → **ldap**
3. Click **"Sync all users"** button
4. Verify: `X imported users, Y updated users, 0 failed`

---

## Email Verification

**IMPORTANT:** Email verification is a Keycloak feature, not LLDAP!

LLDAP stores the email address, but the "verified" status is managed in Keycloak.

### Manual Verification (Per User)

1. **Users** → Search for user → Click username
2. **Details** tab
3. Toggle **"Email verified"** to ON
4. Save

### Disable Email Verification Requirement (Global)

1. **Realm Settings** → **Authentication** → **Required Actions**
2. Find **"Verify Email"**
3. Disable **"Enabled"** or set **"Default Action"** to OFF

---

## IaC User Management Workflow

Users are managed in **Infrastructure as Code** via LLDAP bootstrap.

### Add New User

1. **Edit:** `platform/identity/lldap/bootstrap-config.yaml`

```yaml
{
  "id": "new-user",
  "email": "user@example.com",
  "firstName": "First",
  "lastName": "Last",
  "displayName": "Full Name",
  "password": "changeme",
  "groups": [
    "developers"
  ],
  "argocd": ["viewer"],
  "grafana": ["editor"]
}
```

2. **Commit & Push:**
```bash
git add platform/identity/lldap/bootstrap-config.yaml
git commit -m "feat: add new user to LLDAP"
git push
```

3. **ArgoCD syncs automatically** → Bootstrap job runs → User created in LLDAP

4. **Keycloak Admin Console** → User Federation → ldap → **"Sync all users"**

5. **Done!** User is now in Keycloak

### Update Existing User

Same process - edit `bootstrap-config.yaml`, commit, push.

Bootstrap job will **update** the user (not recreate).

### Remove User

Remove user JSON block from `bootstrap-config.yaml`.

Set `DO_CLEANUP: "true"` in bootstrap-env ConfigMap (already enabled).

Bootstrap job will remove users not in config.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ IaC (Git)                                           │
│ platform/identity/lldap/bootstrap-config.yaml       │
└───────────────────┬─────────────────────────────────┘
                    │ git push
                    ▼
┌─────────────────────────────────────────────────────┐
│ ArgoCD                                              │
│ - Syncs ConfigMaps (bootstrap-users, etc.)         │
│ - Triggers bootstrap job (PostSync hook)           │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ LLDAP Bootstrap Job                                 │
│ - initContainer: wait-for-lldap (port 17170)       │
│ - Container: /app/bootstrap.sh                     │
│   - Creates/updates users from ConfigMap           │
│   - Manages groups and custom attributes           │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ LLDAP (lldap.lldap.svc.cluster.local:3890)         │
│ - Stores users in SQLite database                  │
│ - Exposes LDAP protocol on port 3890               │
└───────────────────┬─────────────────────────────────┘
                    │ LDAP Federation (manual sync)
                    ▼
┌─────────────────────────────────────────────────────┐
│ Keycloak                                            │
│ - Syncs users via LDAP User Federation             │
│ - Users available for OIDC authentication           │
└─────────────────────────────────────────────────────┘
```

---

## Current Users (IaC)

As of 2025-10-13:

| Username  | Email                      | Role             | Groups                        |
|-----------|----------------------------|------------------|-------------------------------|
| admin     | admin@homelab.local        | System Admin     | cluster-admins, argocd-admins |
| tim275    | timour.miagol@outlook.de   | Cluster Admin    | cluster-admins, argocd-admins |
| ci-user   | ci@homelab.local           | CI/CD Bot        | ci-runners                    |

---

## Testing

### Test LDAP Connection

**Keycloak Admin Console** → User Federation → ldap → **"Test connection"**

Should show: ✅ Success

### Test LDAP Authentication

**Keycloak Admin Console** → User Federation → ldap → **"Test authentication"**

Should show: ✅ Success (authenticates with Bind DN credentials)

### Test User Sync

1. Trigger sync: **"Sync all users"**
2. Check logs:
   ```bash
   kubectl logs -n keycloak <keycloak-pod> --tail=50 | grep "Sync all users finished"
   ```
   Should show: `X imported users, Y updated users, 0 users failed`

### Test User Login

1. Logout from Keycloak Admin Console
2. Login with LDAP user credentials (e.g., tim275 + LLDAP password)
3. Should authenticate successfully ✅

---

## References

- LLDAP Documentation: https://github.com/lldap/lldap
- Keycloak LDAP Federation: https://www.keycloak.org/docs/latest/server_admin/#_ldap
- LLDAP Bootstrap Script: `/app/bootstrap.sh` in lldap image

---

## Maintenance

### Periodic Tasks

- **None!** Automatic sync is disabled (LLDAP doesn't support incremental sync)
- Sync manually via Keycloak UI after LLDAP changes

### Monitoring

Check bootstrap job status:
```bash
kubectl get jobs -n lldap
kubectl logs -n lldap <bootstrap-job-pod>
```

Check Keycloak sync errors:
```bash
kubectl logs -n keycloak <keycloak-pod> | grep -i "ldap\|sync"
```

---

## Security Notes

- LDAP connection is **unencrypted** (internal cluster traffic only)
- StartTLS disabled (not needed for cluster-internal communication)
- Bind credentials stored in Kubernetes Secret: `lldap-secrets`
- Bootstrap job runs with restricted securityContext (non-root, read-only filesystem)

---

## Future Improvements

1. **Automatic Keycloak Sync**: Trigger Keycloak sync via API after bootstrap job completes
2. **LDAP Group Mapping**: Map LLDAP groups to Keycloak roles
3. **Email Auto-Verify**: Script to auto-verify emails via Keycloak Admin API
4. **TLS/StartTLS**: Enable encrypted LDAP connections (ldaps:// or StartTLS)

---

**Last Updated**: 2025-10-13
**Maintained By**: Tim275 (timour.miagol@outlook.de)
