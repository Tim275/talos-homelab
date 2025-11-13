# 🚨 ENTERPRISE ALERTING SETUP GUIDE

Complete guide to configure professional alerting like your production environment.

---

## 📋 TABLE OF CONTENTS

1. [Alert Overview](#alert-overview)
2. [Discord Setup](#discord-setup)
3. [Slack Setup](#slack-setup)
4. [Email Setup](#email-setup)
5. [Testing Alerts](#testing-alerts)
6. [Ceph Health Fix](#ceph-health-fix)

---

## 🎯 ALERT OVERVIEW

**Your Current Alerts:**

### ✅ **Already Configured:**
- ✅ Kubernetes Control Plane (API Server, ETCD)
- ✅ Node Health & Resource Saturation
- ✅ Storage (Ceph) - Cluster health, OSD, PG status
- ✅ PostgreSQL/CNPG - Primary failover, replication lag
- ✅ Certificate Expiry
- ✅ Load Spikes & System Performance

### ⭐ **NEW - Just Added:**
- 🆕 **ArgoCD Controller Health** - GitOps deployment monitoring
- 🆕 **Ceph Cluster Health** - HEALTH_WARN/HEALTH_ERROR states
- 🆕 **EFK Stack** - Elasticsearch cluster RED/YELLOW states
- 🆕 **System Load Alerts** - Like your production (P1-P5 priorities)

---

## 🎮 DISCORD SETUP

### Step 1: Create Discord Webhook

1. Open your Discord server
2. Go to **Server Settings → Integrations → Webhooks**
3. Click **"New Webhook"**
4. Configure webhook:
   - **Name**: `Homelab Alerts`
   - **Channel**: `#alerts` (create if doesn't exist)
5. Click **"Copy Webhook URL"**

### Step 2: Create Discord Channels (Recommended)

Create these channels for priority-based routing:

```
📢 Alerts (Category)
├── #alerts-critical   (🔴 P1-P2 - Critical/High priority)
├── #alerts-warning    (🟡 P3 - Warnings)
├── #alerts-info       (📊 P4-P5 - Informational)
└── #monitoring-health (Watchdog/System health)
```

### Step 3: Configure AlertManager with Discord Webhook

Edit `enterprise-alertmanager-config.yaml` and replace:

```yaml
# Line 166 - Critical alerts
- webhook_url: 'YOUR_DISCORD_WEBHOOK_URL_HERE'
```

With your Discord webhook URL:

```yaml
- webhook_url: 'https://discord.com/api/webhooks/123456789/abcdefghijklmnop'
```

**Do this for ALL receivers** (lines 166, 208, 240, 248 in the config).

---

## 💬 SLACK SETUP

### Step 1: Create Slack App

1. Go to https://api.slack.com/apps
2. Click **"Create New App"** → **"From scratch"**
3. Name: `Homelab Alertmanager`
4. Choose your workspace

### Step 2: Enable Incoming Webhooks

1. In your app, go to **"Incoming Webhooks"**
2. Activate **"Activate Incoming Webhooks"**
3. Click **"Add New Webhook to Workspace"**
4. Select channel (e.g., `#alerts-critical`)
5. Copy the Webhook URL

### Step 3: Create Multiple Webhooks for Priority Routing

Create separate webhooks for:
- `#alerts-critical` (P1-P2)
- `#alerts-warning` (P3)
- `#alerts-info` (P4-P5)

### Step 4: Update AlertManager Config

In `enterprise-alertmanager-config.yaml`, update Slack configs:

```yaml
global:
  slack_api_url_file: '/etc/alertmanager/secrets/slack-api-url'
```

Create a secret:

```bash
kubectl create secret generic alertmanager-slack \
  -n monitoring \
  --from-literal=slack-api-url='https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

**OR** use plain URL in config (less secure):

```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

---

## 📧 EMAIL SETUP

### Option 1: Outlook/Office365 (Recommended)

Already configured in `enterprise-alertmanager-config.yaml`:

```yaml
global:
  smtp_smarthost: 'smtp-mail.outlook.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'your-email@outlook.com'
  smtp_auth_password: 'YOUR_APP_PASSWORD'  # Use App Password, not regular password!
  smtp_require_tls: true
```

**Get Outlook App Password:**
1. Go to https://account.microsoft.com/security
2. **Advanced security options** → **App passwords**
3. Create new app password for "Alertmanager"
4. Copy the generated password

### Option 2: Gmail

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'YOUR_APP_PASSWORD'  # From Google Account Security
  smtp_require_tls: true
```

**Get Gmail App Password:**
1. Go to https://myaccount.google.com/security
2. **2-Step Verification** → **App passwords**
3. Generate app password for "Alertmanager"

### Option 3: SealedSecret for Email Credentials (Most Secure)

```bash
# Create sealed secret for SMTP credentials
kubectl create secret generic alertmanager-smtp \
  -n monitoring \
  --from-literal=smtp-username='your-email@outlook.com' \
  --from-literal=smtp-password='YOUR_APP_PASSWORD' \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  --format yaml > alertmanager-smtp-sealed.yaml
```

Then reference in AlertManager config:

```yaml
global:
  smtp_auth_username_file: '/etc/alertmanager/secrets/smtp-username'
  smtp_auth_password_file: '/etc/alertmanager/secrets/smtp-password'
```

---

## 🧪 TESTING ALERTS

### Test 1: Fire a Test Alert

Create a test PrometheusRule:

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestAlert
      expr: vector(1)
      labels:
        severity: warning
        priority: P3
      annotations:
        summary: "This is a test alert"
        description: "Testing alerting system - you should receive this in Discord/Slack/Email"
EOF
```

Wait 2-3 minutes, then check:
- Discord/Slack channels for notifications
- Email inbox

Delete test after verification:

```bash
kubectl delete prometheusrule test-alert -n monitoring
```

### Test 2: Verify Alertmanager Status

```bash
# Check if Alertmanager is running
kubectl get pods -n monitoring | grep alertmanager

# Check Alertmanager config
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep "Completed loading of configuration file"

# Port-forward to Alertmanager UI
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093

# Open browser: http://localhost:9093
```

### Test 3: Silence Alerts (Optional)

In Alertmanager UI (http://localhost:9093):

1. Go to **"Silences"**
2. Click **"New Silence"**
3. Set matcher: `alertname=TestAlert`
4. Duration: 1 hour
5. **"Create"**

---

## 🔧 CEPH HEALTH FIX

**Your Current Issue:**

```
HEALTH_WARN - Cluster created successfully
```

This is a **normal warning** after cluster creation! Let's check what the actual warning is:

### Check Ceph Health Details

```bash
# Get detailed Ceph status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail

# Check OSD status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd status

# Check PG status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph pg stat
```

### Common HEALTH_WARN Causes & Fixes

#### 1. **Too Few PGs** (Most Common)

```bash
# Check if this is the warning
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail | grep "too few PGs"

# Fix: Increase PG count
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool set <pool-name> pg_num 64
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool set <pool-name> pgp_num 64
```

#### 2. **Clock Skew**

```bash
# Check for clock skew
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail | grep "clock skew"

# Fix: Sync time on all nodes (Talos does this automatically via NTP)
```

#### 3. **OSD Nearfull**

```bash
# Check OSD usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd df

# Fix: Add more OSDs or delete old data
```

#### 4. **Degraded Objects**

```bash
# Check PG status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph pg stat

# Usually auto-heals after a few minutes
# Force recovery: ceph pg force_recovery_start <pg-id>
```

### Auto-Fix Common Warnings

Run this to auto-optimize your cluster:

```bash
# Enable autoscaler (automatically sets optimal PG counts)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph mgr module enable pg_autoscaler
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool set <pool-name> pg_autoscale_mode on

# Enable balancer (distribute data evenly)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph balancer on
```

---

## 📊 ALERT PRIORITY MAPPING

Match your production environment:

| **Priority** | **Severity** | **Response SLA** | **Channels** | **Example Alerts** |
|-------------|-------------|-----------------|--------------|-------------------|
| **P1** | Critical | 5 minutes | Discord + Email + Page | API Server Down, Ceph HEALTH_ERROR, Control Plane Failure |
| **P2** | High | 30 minutes | Discord + Email | Node Down, ArgoCD Degraded, PostgreSQL Primary Down |
| **P3** | Warning | 2 hours | Discord + Email | Memory >85%, Ceph HEALTH_WARN, Disk >90% |
| **P4** | Info | No SLA | Discord only | Load spikes, Pod restarts |
| **P5** | Info | No SLA | Discord only | Deployment notifications, config changes |

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] **Discord webhook** created and added to config
- [ ] **Slack webhooks** created (optional) and added to config
- [ ] **Email SMTP** credentials configured (Outlook/Gmail app password)
- [ ] **Test alert** fired successfully
- [ ] **Alertmanager UI** accessible (port-forward 9093)
- [ ] **Ceph health** warning resolved or understood
- [ ] **All PrometheusRules** deployed: `kubectl get prometheusrules -n monitoring`
- [ ] **Silence test alerts** after verification

---

## 🚀 QUICK DEPLOYMENT

```bash
# 1. Update Discord/Slack/Email in enterprise-alertmanager-config.yaml
# 2. Deploy all alerts
kubectl apply -k kubernetes/infrastructure/monitoring/alertmanager/

# 3. Verify PrometheusRules loaded
kubectl get prometheusrules -n monitoring

# 4. Check Prometheus picked up rules
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/rules

# 5. Verify Alertmanager config
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0

# 6. Fire test alert (see "Testing Alerts" section above)
```

---

## 📞 SUPPORT & TROUBLESHOOTING

### Alertmanager not sending alerts?

```bash
# Check Alertmanager logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -i error

# Check Prometheus connectivity
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 | grep alertmanager

# Verify webhook URLs are reachable
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- \
  wget -O- https://discord.com/api/webhooks/YOUR_WEBHOOK
```

### Discord/Slack not receiving messages?

1. **Check webhook URL** - Copy-paste error?
2. **Check channel permissions** - Webhook has access?
3. **Check Alertmanager logs** - `grep discord` or `grep slack`
4. **Test webhook manually**:

```bash
curl -X POST 'YOUR_DISCORD_WEBHOOK_URL' \
  -H 'Content-Type: application/json' \
  -d '{"content":"Test from curl"}'
```

### Email not working?

1. **Check SMTP credentials** - Use app password, not regular password!
2. **Check TLS settings** - `smtp_require_tls: true`
3. **Check firewall** - Port 587 outbound allowed?
4. **Test SMTP manually**:

```bash
kubectl run smtp-test --rm -it --image=alpine --restart=Never -- sh
apk add curl
curl --url 'smtp://smtp-mail.outlook.com:587' \
  --mail-from 'your-email@outlook.com' \
  --mail-rcpt 'recipient@example.com' \
  --upload-file - \
  --user 'your-email@outlook.com:YOUR_APP_PASSWORD' \
  --ssl-reqd
```

---

## 🎉 DONE!

You now have **enterprise-grade alerting** matching your production environment:

✅ Multi-channel routing (Discord/Slack/Email)
✅ Priority-based alerting (P1-P5)
✅ ArgoCD controller health monitoring
✅ Ceph cluster health alerts (HEALTH_WARN/ERROR)
✅ EFK stack monitoring
✅ Load spike detection
✅ System performance alerts

**Your homelab now alerts like Netflix/Google/Uber!** 🚀
