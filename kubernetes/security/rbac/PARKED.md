# security/rbac/oidc-users — PARKED 2026-05-09

**Status:** Application "rbac" auskommentiert in `security/kustomization.yaml`. Dead-Code von Authelia-Era.

## Warum entfernt

Diese OIDC-Bindings nutzten WRONG Prefix-Pattern:
```yaml
# admins-group-binding.yaml — FALSCH
subjects:
  - kind: Group
    name: oidc:admins              # ❌ no JWT emits this prefix anymore

# tim275-cluster-admin.yaml — FALSCH
subjects:
  - kind: User
    name: oidc:tim275              # ❌ user-direct binding (anti-pattern)
```

**Korrekte aktive Version:** `kubernetes/security/foundation/rbac/oidc-bindings.yaml`
```yaml
subjects:
  - kind: Group
    name: oidc-grp:cluster-admins  # ✓ matches Talos oidc-groups-prefix
```

## Was kaputt war

1. **Wrong group-prefix:** Talos config hat `oidc-groups-prefix=oidc-grp:`. Diese Bindings erwarten `oidc:` Prefix → matchen nichts → keine Permissions.

2. **User-direct subject (Anti-Pattern):** `oidc:tim275` hardcoded → bei Mitarbeiter-Wechsel git-commit nötig. Pattern: Group-Membership in LLDAP setzen, Group-Binding in K8s.

3. **References Authelia:** Wir nutzen Keycloak. Authelia ist deinstalliert.

## Restore (NICHT empfohlen)

```bash
# Falls jemand wirklich User-direct-bindings will (warum?):
# 1. security/kustomization.yaml einkommentieren:
#    - rbac/application.yaml
# 2. Subjects-Names in admins-group-binding.yaml + tim275-cluster-admin.yaml fixen:
#    oidc:admins → oidc-grp:cluster-admins (group-prefix correction)
# 3. Sicherstellen: wird parallel zu foundation/rbac NICHT same-named ClusterRoleBinding
# 4. git push → ArgoCD synct
```

## Source-of-Truth für RBAC

→ `kubernetes/security/foundation/rbac/oidc-bindings.yaml`

Mehr in CLAUDE.md → "Phase 3 — RBAC für jede Gruppe definieren" (ULTIMATE Identity Guide).
