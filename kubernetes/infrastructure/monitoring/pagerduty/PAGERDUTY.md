# PagerDuty Alerting Strategy - Google SRE Production Model

## Current Implementation: 5-Level Priority System (P0-P4)

### Architecture: Multi-Channel Enterprise Model

Following **Google SRE best practices** with 5 specialized channels for team ownership and reduced noise.

| Channel | Alerts | Priority Levels | Who |
|---------|--------|-----------------|-----|
| **#alerts** | Infrastructure (Nodes, K8s, Istio) | P0/P1/P2/P3/P4 | Platform Team |
| **#argocd-deployments** | GitOps (ArgoCD) | P0/P1/P2/P3 | Dev/Deployment Team |
| **#storage-alerts** | Ceph, PVC, Disk | P0/P1/P2 | Storage Team |
| **#database-alerts** | PostgreSQL, Backups | P0/P1/P2 | DBA Team |
| **#security-alerts** | Auth, Certs, Policies | P0/P1/P2 | Security Team |

---

## Priority System - Google SRE Model

### P0: Complete Outage 🚨🚨 (ALL HANDS ON DECK)

**Definition:** Service is completely unavailable. ALL instances down. Total system failure.

**Response:**
- **SLA:** Immediate (0s group_wait)
- **Notification:** Phone + SMS + Push + Slack (ALL 5 channels simultaneously)
- **Escalation:** Page EVERYONE, wake up entire team
- **Repeat:** Every 2 minutes until resolved
- **Impact:** Complete business/service outage

**P0 Outage Scenarios (6 alerts):**
1. **KubernetesAPIServerCompleteOutage** - ALL API servers unreachable → cluster dead
2. **CephCompleteOutage** - ALL monitors down → complete storage failure
3. **PostgreSQLCompleteOutage** - ALL database instances down → no DB access
4. **ClusterCapacityCritical** - >50% nodes down → massive workload failure
5. **IstioGatewayCompleteOutage** - ALL ingress gateways down → no external traffic
6. **ArgoCDCompleteOutage** - ALL ArgoCD components down → no deployments possible

**Example:**
```
🚨🚨 COMPLETE OUTAGE - Kubernetes API Server DOWN - ALL HANDS!
Impact: Complete cluster outage - no workloads accessible
Action: SSH to control plane nodes && systemctl status kubelet
```

---

### P1: Critical 🔴 (Service Degraded)

**Definition:** Partial service failure. Primary systems down but replicas/fallbacks working.

**Response:**
- **SLA:** 15 minutes
- **Notification:** Phone call + SMS + Push + Slack
- **Escalation:** Page primary on-call
- **Repeat:** Every 5 minutes
- **Impact:** Service degraded but partially functional

**Examples:**
- PostgreSQL Primary Down (replicas still serving reads)
- Kubernetes Node NotReady (workloads rescheduled)
- ArgoCD Sync Failed (apps still running)
- Certificate Expiring <7 days (service still works)

---

### P2: High 🟠 (Performance Degraded)

**Definition:** Service working but degraded performance or approaching failure threshold.

**Response:**
- **SLA:** 4 hours
- **Notification:** Push notification + Slack
- **Escalation:** Notify on-call (no phone)
- **Repeat:** Every 15 minutes
- **Impact:** Degraded performance, future risk

**Examples:**
- Ceph Pool Near Full (85% full, not critical yet)
- PostgreSQL Backup Failed (last backup exists but new one failed)
- High Query Latency (p95 > 500ms)
- Disk Pressure (80% full)

---

### P3: Medium 🟡 (Warning)

**Definition:** Potential issue detected. No immediate impact but needs investigation.

**Response:**
- **SLA:** 24 hours
- **Notification:** Slack only
- **Escalation:** None (business hours)
- **Repeat:** Every 1 hour
- **Impact:** No current impact

**Examples:**
- ArgoCD Application OutOfSync >10min
- Ceph Cluster Health Warning
- Memory usage 70%
- Pod restart detected

---

### P4: Low/Info 🔵 (Backlog)

**Definition:** Informational alerts. No action required immediately.

**Response:**
- **SLA:** 1 week (backlog)
- **Notification:** Slack only
- **Escalation:** None
- **Repeat:** Every 4 hours
- **Impact:** None

**Examples:**
- ConfigMap updated
- Deployment scaled
- Informational metrics

---

## Alert Categories by Channel

### 1. Infrastructure (#alerts)
**P0:** KubernetesAPIServerCompleteOutage, ClusterCapacityCritical
**P1:** Node NotReady, Disk Pressure, High CPU/Memory
**P2:** Memory usage 70%, Disk 80% full
**P3:** Node warnings

### 2. Storage (#storage-alerts)
**P0:** CephCompleteOutage
**P1:** Ceph Health ERROR, OSD Down (multiple)
**P2:** Ceph Health Warning, OSD Near Full, Pool Near Full, PVC Provisioning Failed
**P3:** Slow requests, degraded PGs

### 3. Database (#database-alerts)
**P0:** PostgreSQLCompleteOutage
**P1:** PostgreSQL Primary Down, Replication Lag >30s, Connection Pool >90%
**P2:** Backup Failed, High Query Latency
**P3:** No recent backup (warning)

### 4. Certificates (#security-alerts)
**P1:** TLS expiring <7 days
**P2:** Cert-Manager renewal failures
**P3:** Certificate approaching expiry (>7 days)

### 5. Backups (#database-alerts)
**P0:** VeleroCompleteOutage (if critical)
**P1:** Velero Backup Failed, No backup >24h
**P2:** Restore test failed

### 6. Service Mesh (#alerts)
**P0:** IstioGatewayCompleteOutage
**P1:** High 5xx error rate >10%
**P2:** 5xx rate 5-10%, Circuit breaker triggered
**P3:** mTLS warnings

### 7. Security (#security-alerts)
**P1:** Failed API auth >50/min
**P2:** Pods running as root, No resource limits
**P3:** Policy violations

### 8. GitOps (#argocd-deployments)
**P0:** ArgoCDCompleteOutage
**P1:** Sync failures >5 in 1h, Controller/Repo Server down
**P2:** Git connection failures
**P3:** Application OutOfSync >10min

---

## P0 Broadcast Strategy

**When P0 fires:**
1. **PagerDuty:** Critical severity → page everyone
2. **Slack Broadcast:** Send to ALL 5 channels simultaneously:
   - `#alerts` - Full details + runbook + action buttons
   - `#argocd-deployments` - Summary notification
   - `#storage-alerts` - Summary notification
   - `#database-alerts` - Summary notification
   - `#security-alerts` - Summary notification

**Why broadcast to all channels?**
- Complete outages affect ENTIRE cluster
- All teams need situational awareness
- Enables cross-team collaboration during major incidents
- Prevents "I didn't know we were down" scenarios

---

## PagerDuty Setup

### Integration Key
- Service: Homelab Kubernetes
- Region: EU (https://events.eu.pagerduty.com)
- Integration: Events API v2

### Escalation Policy

**P0 - Complete Outage:**
- Level 1: ALL team members simultaneously (0s timeout)
- ALL HANDS notification

**P1 - Critical:**
- Level 1: Primary On-Call (15min timeout)
- Level 2: Secondary On-Call (15min timeout)
- Level 3: Manager/Team Lead (15min timeout)

**P2 - High:**
- Level 1: Primary On-Call (push notification only)
- No escalation (4h SLA)

**P3/P4:**
- Slack only (no PagerDuty)

### On-Call Schedule
- Weekly rotation
- 24/7 coverage for P0/P1
- Business hours for P2
- Vacation/Override support

---

## TODO: Future Email Alerting Enhancement

### Current Status: PagerDuty Phone/SMS + Slack (Sufficient)

**Current P0/P1 Notification Channels:**
- ✅ PagerDuty: Phone calls + SMS for immediate wake-up
- ✅ Slack: 5 channels for team visibility

**Future Enhancement: Add Email Alerts**

**Why not implemented yet:**
- Requires SMTP password/API key setup
- PagerDuty phone calls + Slack already provide comprehensive coverage
- Email would be nice-to-have, not critical

**When to implement:**
- When team grows beyond 3 people
- When email distribution list is needed
- When PagerDuty cost becomes an issue

**Implementation Options:**

**Option 1: Outlook SMTP (Simple)**
- SMTP Server: smtp-mail.outlook.com:587
- Requires: App Password from https://account.microsoft.com/security
- Distribution List: homelab-oncall@outlook.com
- Cost: Free

**Option 2: SendGrid API (Recommended - No Password!)**
- Free tier: 100 emails/day
- API Key authentication (more secure than password)
- Better deliverability
- Email analytics included
- Cost: Free

**Option 3: Mailgun API**
- Free tier: 5000 emails/month
- EU servers available
- API Key authentication
- Cost: Free

**Email Strategy (when implemented):**
- P0/P1: Email + PagerDuty + Slack
- P2/P3/P4: Slack only (no email spam)
- Distribution list for easy team management

**Implementation Files:**
```bash
# Create email secret (example with Outlook)
kubernetes/infrastructure/monitoring/pagerduty/email-config-sealed.yaml

# Add to values.yaml:
config:
  global:
    smtp_from: 'alertmanager@timourhomelab.org'
    smtp_smarthost: 'smtp-mail.outlook.com:587'
    smtp_auth_username: 'your-email@outlook.com'
    smtp_auth_password_file: '/etc/alertmanager/secrets/email-config/smtp-password'
    smtp_require_tls: true

# Add email_configs to P0/P1 receivers in values.yaml
```

**Priority:** Low (PagerDuty + Slack is sufficient for now)

---

## Alert Routing Configuration

### Alertmanager Route Priority

```yaml
routes:
  # 1. P0: COMPLETE OUTAGE (highest priority)
  - matchers: [priority="P0"]
    receiver: 'p0-outage'
    group_wait: 0s           # INSTANT
    repeat_interval: 2m      # Every 2 minutes
    continue: false          # Stop processing

  # 2. P1: CRITICAL
  - matchers: [priority="P1"]
    receiver: 'p1-critical'
    group_wait: 10s
    repeat_interval: 5m
    continue: false

  # 3. P2: HIGH
  - matchers: [priority="P2"]
    receiver: 'p2-high'
    group_wait: 30s
    repeat_interval: 15m
    continue: false

  # 4. P3: WARNING
  - matchers: [priority="P3"]
    receiver: 'p3-warning'
    group_wait: 5m
    repeat_interval: 1h
    continue: false

  # 5. P4: INFO/BACKLOG
  - matchers: [priority="P4"]
    receiver: 'p4-info'
    group_wait: 15m
    repeat_interval: 4h
    continue: false
```

### Inhibit Rules

```yaml
# P0 suppresses all lower priorities
- source_matchers: [priority="P0"]
  target_matchers: [priority=~"P1|P2|P3|P4"]
  equal: ['namespace', 'job']

# P1 suppresses P2/P3/P4
- source_matchers: [priority="P1"]
  target_matchers: [priority=~"P2|P3|P4"]
  equal: ['namespace', 'job']

# Critical severity suppresses warnings
- source_matchers: [severity="critical"]
  target_matchers: [severity="warning"]
  equal: ['namespace', 'alertname', 'instance']
```

---

## Runbooks

### P0 Complete Outage Response

1. **Acknowledge PagerDuty** (stops repeat notifications)
2. **Join Incident Bridge** (Slack channel or call)
3. **Assess Impact:** Which P0 alert fired?
   - API Server → SSH to control plane nodes
   - Ceph → Check monitor quorum
   - PostgreSQL → Check all cluster pods
   - Cluster Capacity → Check node status
   - Istio Gateway → Check ingress pods
   - ArgoCD → Check all ArgoCD components
4. **Run diagnostic commands** from alert annotations
5. **Declare Major Incident** if >15min to resolve
6. **Escalate** to vendor support if needed
7. **Communicate status** to stakeholders
8. **Post-mortem** required for all P0s

### P1 Critical Response

1. **Acknowledge in PagerDuty**
2. **Check Slack** for detailed context
3. **Run diagnostic commands** from alert
4. **Check Grafana dashboards**
5. **Fix or escalate** within 15min SLA
6. **Document resolution**
7. **Mark as resolved**

---

## Metrics & Coverage

### Current Alert Coverage

- ✅ **P0 Complete Outages:** 6 alerts
- ✅ **Kubernetes Infrastructure:** 10 alerts (P1/P2/P3)
- ✅ **ArgoCD GitOps:** 8 alerts (P1/P2/P3)
- ✅ **Ceph Storage:** 10 alerts (P1/P2)
- ✅ **PostgreSQL Database:** 9 alerts (P1/P2)
- ✅ **Certificate Management:** 2 alerts (P1/P2)
- ✅ **Velero Backups:** 3 alerts (P1/P2)
- ✅ **Istio Service Mesh:** 5 alerts (P1/P2/P3)
- ✅ **Security:** 6 alerts (P1/P2)

**Total: ~60 Production Alerts**

### SLO Targets

**Response Time:**
- P0: Immediate acknowledgment, <15min resolution target
- P1: <15min response, <1h resolution target
- P2: <4h response, <24h resolution target
- P3: <24h response, <1 week resolution
- P4: Backlog (best effort)

**Alert Quality:**
- False Positive Rate: <5%
- Alert Fatigue: <30 alerts/day
- P0 incidents: <1 per month (target: 0)
- P1 incidents: <5 per week

---

## Useful Commands

### Check PagerDuty Integration
```bash
kubectl exec -n monitoring alertmanager-0 -c alertmanager -- \
  cat /etc/alertmanager/secrets/pagerduty-integration-key/integration-key
```

### Test P0 Alert Manually
```bash
curl -X POST https://events.eu.pagerduty.com/v2/enqueue \
  -H 'Content-Type: application/json' \
  -d '{
    "routing_key": "YOUR_INTEGRATION_KEY",
    "event_action": "trigger",
    "payload": {
      "summary": "🚨🚨 TEST P0 OUTAGE - Kubernetes API Server DOWN",
      "severity": "critical",
      "source": "kubectl-test"
    }
  }'
```

### Check Alertmanager Active Alerts
```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.priority=="P0")'
```

### Check All PrometheusRules
```bash
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule p0-outage-alerts -n monitoring
```

### Test Slack Webhooks
```bash
# Test #alerts channel
curl -X POST "https://hooks.slack.com/services/YOUR_WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d '{"text":"🚨🚨 TEST P0 ALERT - This is a drill"}'
```

---

## Migration from 4-Level to 5-Level System

### What Changed

**Before (4 levels):**
- P1 (Critical) - Mixed complete outages + partial failures
- P2 (High) - Everything else important
- P3 (Warning) - Warnings
- P5 (Info) - Backlog

**After (5 levels - Google SRE):**
- **P0 (Outage)** - NEW: Complete service unavailable scenarios only
- P1 (Critical) - Partial failures, service degraded
- P2 (High) - Performance degraded, approaching limits
- P3 (Warning) - No immediate impact
- **P4 (Info)** - Renamed from P5 for consistency

### Alert Re-Triage

**Downgraded P1 → P2:**
- `CephPoolNearFull` - Pool 85% full is high priority but not critical (can still write)
- `PostgreSQLBackupFailed` - Backup failure is serious but old backups exist

**Promoted to P0:**
- Complete system failures extracted from P1 into dedicated P0 category

---

## Contact & Escalation

**Primary On-Call:** Check PagerDuty schedule
**Secondary On-Call:** Check PagerDuty schedule
**Escalation Manager:** TBD

**Emergency Contacts:**
- PagerDuty: https://eu.pagerduty.com
- Slack Workspace: https://[your-workspace].slack.com
- ArgoCD: https://argocd.homelab.local
- Grafana: https://grafana.homelab.local

---

## References

**Industry Standards:**
- Google SRE Book: https://sre.google/sre-book/monitoring-distributed-systems/
- Google SRE Workbook: https://sre.google/workbook/alerting-on-slos/
- PagerDuty Incident Response: https://response.pagerduty.com/

**Why 5 Levels?**
- Google, Microsoft, Amazon use P0-P4
- Clear distinction between complete outage (P0) vs partial failure (P1)
- Room to grow as homelab scales
- Industry standard for enterprise monitoring
