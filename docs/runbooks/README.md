# Runbooks Index

Quick reference for all alert runbooks. Each Critical/Warning alert MUST have a matching runbook here.

## Drova Tenant

| Alert | Runbook | Severity |
|---|---|---|
| DrovaSLOPageFastBurn | [drova-slo-burn.md](./drova-slo-burn.md) | P1 |
| DrovaSLOPageSlowBurn | [drova-slo-burn.md](./drova-slo-burn.md) | P1 |
| DrovaSLOTicketSlowBurn | [drova-slo-burn.md](./drova-slo-burn.md) | P2 |
| DrovaLatencyP99High | [drova-latency-high.md](./drova-latency-high.md) | P2 |

## Storage / Ceph

| Alert | Runbook | Severity |
|---|---|---|
| PVCPendingTooLong | (TODO) | P2 |
| PVCPendingCritical | (TODO) | P1 |
| CSIProvisionerDown | (TODO) | P1 |
| CephOSDFlapping | (TODO) | P2 |
| ReleasedPVsAccumulating | (TODO) | P2 |

## CNPG / Postgres

| Alert | Runbook | Severity |
|---|---|---|
| CNPGWALArchivingFailed | (TODO) | P1 |
| CNPGLastFailedArchiveTime | (TODO) | P2 |
| CNPGPrimaryDown | (TODO) | P1 |

## Kafka

| Alert | Runbook | Severity |
|---|---|---|
| KafkaBrokersDown | (TODO) | P1 |
| KafkaConsumerLagHigh | (TODO) | P2 |
| KafkaUnderReplicatedPartitions | (TODO) | P2 |

## Runbook Template

Use this structure for new runbooks (siehe `drova-slo-burn.md` als Referenz):

```markdown
# Runbook: <AlertName>

**Severity:** Critical/Warning (P1/P2/P3)
**Trigger:** Alert-name + bedingung kurz

## Was ist passiert
What the alert means in plain language

## Sofort-Diagnose
1. Step-by-step diagnostic commands
2. Where to look first
3. PromQL queries

## Häufige Root-Causes
A) Cause 1 + fix
B) Cause 2 + fix
C) ...

## Mitigation
| Situation | Action |
|---|---|

## Eskalation
- 15min: Slack
- 30min: Page
- 1h: Incident response

## Post-Mortem Pflicht
When required + what to capture

## Verwandte Dashboards
- Links to Grafana
```
