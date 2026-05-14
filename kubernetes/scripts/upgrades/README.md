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

## What's checked (13 sections, post-upgrade-verify.sh)

| # | Check | Auto-Fix Hint |
|---|---|---|
| 1 | CoreDNS iam-rewrite present | apply tofu inline-manifest |
| 2 | github.com resolves from in-cluster pod | restart CoreDNS |
| 3 | KC pods Running + ≥2 users + MFA enforced | restart KC operator / set CONFIGURE_TOTP |
| 4 | LLDAP bootstrap CronJob lastSuccessful recent | manually trigger CronJob |
| 5 | ArgoCD apps Synced+Healthy + no Missing | hard-refresh / review specific app |
| 6 | No Pending PVCs | check StorageClass |
| 7 | **SPIRE-Agents Running** (2026-05-14 new) | `rollout restart ds/spire-agent` |
| 8 | **No zombie Phase=Succeeded pods** (2026-05-14 new) | `delete pod --force` |
| 9 | **PDB at full health** (2026-05-14 new) | scale up missing pods |
| 10 | **Velero schedules backed up <26h** (2026-05-14 new) | check schedule + log |
| 11 | **CNPG backups completed today** (2026-05-14 new) | check ObjectStore creds |
| 12 | **No Degraded Argo Rollouts** (2026-05-14 new) | check AnalysisTemplate |
| 13 | App-count matches pre-snapshot | check what got pruned |

## Bug-pattern catching matrix (was die neuen Checks heute gefangen hätten)

| Was passierte 2026-05-14 | Welcher Check würde es catchen |
|---|---|
| SPIRE-agents 26h in CrashLoopBackOff | #7 SPIRE-Agents Running |
| Alertmanager-0 17h Phase=Succeeded | #8 Zombie pods |
| Prometheus-0 28h Phase=Succeeded | #8 Zombie pods |
| Envoy-gateway 40 restarts via Exit 0 | #8 (Deployment-RS owns it) |
| KC-DB CNPG-backups 12d stale | #11 CNPG backups today |
| Drova api-gateway Rollout aborted | #12 Rollouts Degraded |
| TOTP-loop für Mitarbeiter | #3 MFA enforced (existing) |

## Self-Healing already in place

- CoreDNS-ConfigMap is owned by ArgoCD `coredns` app with `selfHeal: true`
  → reverts override within 1-3min automatically (added 2026-05-09)
- LLDAP-Bootstrap is a CronJob (hourly) — re-creates users if lost
  → no manual re-run needed (added 2026-05-09)
- **PDBs on Prometheus + AM + Keycloak** (added 2026-05-14)
  → Talos kann nicht mehr alle Replicas gleichzeitig evicten
- **SPIRE PSAT-token-TTL 600s → 3600s** (added 2026-05-14)
  → übersteht jeden realistischen Talos-upgrade-Zyklus
- **KC-DB CNPG-Backup aktiviert** (added 2026-05-14, 12d-Lücke)
  → daily 03:00 UTC zu Ceph-RGW S3
- Prometheus alert `LLDAPBootstrapCronJobFailing` fires if CronJob fails 3h+
- Prometheus alert `ArgoCDApplicationMissing` fires P1 if any app=Missing 10min+
- **Prometheus alerts: AlertmanagerPodMissing / PrometheusPodMissing / SPIREAgentDown / RolloutAborted** (added 2026-05-14)
  → catches future silent-death in 5-10min
