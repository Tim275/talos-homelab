# Upgrade-Resilience Routine

Procedure to use BEFORE + AFTER any of:
- `talosctl upgrade-k8s` (Kubernetes version bump)
- `talosctl upgrade --image ...` (Talos OS bump)
- `tofu apply` (machineconfig changes)

## Why

Battle-tested 2026-05-09: `talosctl upgrade-k8s` overrode CoreDNS-ConfigMap
→ pods saw SERVFAIL externally → ArgoCD couldn't reach GitHub → KC OIDC backchannel broken → SSO down.

Plus separately: LLDAP bootstrap-Job had ttl + Sync-hook only on delta — after upgrade, users disappeared.

These scripts catch that pattern in <60s.

## Usage

```bash
# 1. Snapshot current state
./kubernetes/scripts/upgrades/pre-upgrade.sh
# → /tmp/pre-upgrade-<timestamp>/ created

# 2. Do the upgrade
talosctl upgrade-k8s --to 1.36.0
# (or talosctl upgrade --image ..., or tofu apply)

# 3. Verify nothing regressed
./kubernetes/scripts/upgrades/post-upgrade-verify.sh /tmp/pre-upgrade-<timestamp>/
# → exits 0 on success, 1 with concrete fixes on failure
```

## What's checked

| # | Check | Auto-Fix Hint |
|---|---|---|
| 1 | CoreDNS iam-rewrite present | apply tofu inline-manifest |
| 2 | CoreDNS forward target = gateway (not /etc/resolv.conf) | re-apply ArgoCD coredns app |
| 3 | github.com resolves from in-cluster pod | restart CoreDNS |
| 4 | KC pods Running ≥1 | restart KC operator |
| 5 | KC users ≥2 (LDAP federation working) | trigger LDAP sync |
| 6 | LLDAP bootstrap CronJob lastSuccessful recent | manually trigger CronJob |
| 7 | ArgoCD apps Synced+Healthy ≥48 | hard-refresh apps |
| 8 | No Missing apps | review specific app |
| 9 | No Pending PVCs | check StorageClass |
| 10 | App-count matches pre-snapshot | check what got pruned |

## Self-Healing already in place

- CoreDNS-ConfigMap is owned by ArgoCD `coredns` app with `selfHeal: true`
  → reverts override within 1-3min automatically (added 2026-05-09)
- LLDAP-Bootstrap is a CronJob (hourly) — re-creates users if lost
  → no manual re-run needed (added 2026-05-09)
- Prometheus alert `LLDAPBootstrapCronJobFailing` fires if CronJob fails 3h+
- Prometheus alert `ArgoCDApplicationMissing` fires P1 if any app=Missing 10min+
