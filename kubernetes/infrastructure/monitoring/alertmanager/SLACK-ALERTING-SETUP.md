# 🎯 SLACK ALERTING SETUP - Step-by-Step Guide

**Professional Multi-Channel Alerting wie Production Environment**

---

## 📊 CHANNEL STRUKTUR (Empfohlen)

### **Option 1: Priority-Based (Wie dein Betrieb)** ⭐ EMPFOHLEN

```
🏢 Homelab Monitoring (Category)
├── #alerts-critical     (🔴 P1-P2: API Down, ETCD Failure, Ceph ERROR)
├── #alerts-warning      (🟡 P3: RAM >85%, Disk >90%, HEALTH_WARN)
├── #alerts-info         (📊 P4-P5: Load spikes, deployments)
├── #controller-health   (🎛️ ArgoCD, Sealed Secrets, Cert-Manager)
└── #monitoring-health   (💚 Watchdog, Prometheus/Grafana health)
```

### **Option 2: Component-Based**

```
🏢 Homelab Alerts
├── #alerts-control-plane    (K8s API, ETCD, Nodes)
├── #alerts-storage          (Ceph, PostgreSQL)
├── #alerts-network          (Cilium, DNS, Ingress)
├── #alerts-gitops           (ArgoCD, Sealed Secrets)
└── #alerts-observability    (Prometheus, Grafana, Loki)
```

**ICH EMPFEHLE OPTION 1** - Priority-based ist einfacher und wie dein Production Setup!

---

## 🚀 STEP-BY-STEP: SLACK CHANNELS ERSTELLEN

### **Schritt 1: Workspace vorbereiten**

1. **Slack öffnen** (Desktop App oder Browser)
2. **Dein Workspace auswählen** (oder neuen erstellen)
3. Linke Sidebar → **"Channels"** finden

---

### **Schritt 2: Channel Category erstellen (Optional aber schön!)**

1. **Rechtsklick** auf "Channels" in der Sidebar
2. **"Create section"** oder **"Neue Sektion erstellen"**
3. **Name**: `🏢 Homelab Monitoring`
4. **Enter** drücken

---

### **Schritt 3: Channel #1 erstellen - Critical Alerts**

1. **Klick auf "+"** neben "Channels" (oder Rechtsklick → "Create channel")
2. **Channel Name**: `alerts-critical`
3. **Description**:
   ```
   🚨 P1-P2 CRITICAL & HIGH Priority Alerts
   - API Server Down
   - ETCD Failures
   - Ceph HEALTH_ERROR
   - PostgreSQL Primary Down
   - Response SLA: 5-30 minutes
   ```
4. **Make private**: ❌ (Public, damit alle sehen können)
5. **"Create"** klicken

**Channel Settings anpassen:**
6. **In den Channel gehen** → Oben auf **Channel Name** klicken
7. **"Settings"** → **"Edit channel details"**
8. **Channel topic** (oben im Channel sichtbar):
   ```
   🔴 CRITICAL ALERTS ONLY - Immediate Action Required
   ```
9. **"Save"**

---

### **Schritt 4: Channel #2 - Warning Alerts**

1. **"+" → Create channel**
2. **Name**: `alerts-warning`
3. **Description**:
   ```
   ⚠️ P3 WARNING Priority Alerts
   - RAM usage >85%
   - Disk space >90%
   - Ceph HEALTH_WARN
   - Pod CrashLooping
   - Response SLA: 2 hours
   ```
4. **Public** ✅
5. **"Create"**

**Topic setzen:**
```
🟡 WARNING ALERTS - Monitor & Investigate
```

---

### **Schritt 5: Channel #3 - Info Alerts**

1. **Create channel**
2. **Name**: `alerts-info`
3. **Description**:
   ```
   ℹ️ P4-P5 INFO & TRENDING
   - Load spikes
   - Traffic anomalies
   - Deployment notifications
   - No immediate action required
   ```
4. **Public** ✅
5. **"Create"**

**Topic**:
```
📊 INFO ALERTS - Trends & Events
```

---

### **Schritt 6: Channel #4 - Controller Health**

1. **Create channel**
2. **Name**: `controller-health`
3. **Description**:
   ```
   🎛️ GitOps Controller Health Monitoring
   - ArgoCD Application status
   - Sealed Secrets health
   - Cert-Manager status
   - Sync failures & warnings
   ```
4. **Public** ✅
5. **"Create"**

**Topic**:
```
🎛️ GitOps Controllers - Deployment Pipeline Health
```

---

### **Schritt 7: Channel #5 - Monitoring Health**

1. **Create channel**
2. **Name**: `monitoring-health`
3. **Description**:
   ```
   💚 Observability Stack Health
   - Prometheus/Grafana status
   - Loki ingestion health
   - Alertmanager notifications
   - Watchdog heartbeat (every 5min = healthy!)
   ```
4. **Public** ✅
5. **"Create"**

**Topic**:
```
💚 WATCHDOG - Monitoring System Heartbeat
```

---

### **Schritt 8: Channels in Category verschieben**

1. **Jeder Channel**: Drag & Drop in die **"🏢 Homelab Monitoring"** section
2. **Reihenfolge** (von oben nach unten):
   ```
   🏢 Homelab Monitoring
   ├── #alerts-critical
   ├── #alerts-warning
   ├── #alerts-info
   ├── #controller-health
   └── #monitoring-health
   ```

---

## 🔗 SLACK WEBHOOKS ERSTELLEN

Jetzt brauchst du **5 Webhooks** (einen pro Channel):

### **Webhook für #alerts-critical erstellen:**

1. **Browser öffnen**: https://api.slack.com/apps
2. **"Create New App"** klicken
3. **"From scratch"** auswählen
4. **App Name**: `Homelab Alertmanager`
5. **Workspace**: Dein Workspace auswählen
6. **"Create App"** klicken

7. **Linkes Menü** → **"Incoming Webhooks"**
8. **Toggle "Activate Incoming Webhooks"** auf **ON** ✅
9. Scroll down → **"Add New Webhook to Workspace"**
10. **Channel auswählen**: `#alerts-critical`
11. **"Allow"** klicken

12. **Webhook URL kopieren** - sieht so aus:
    ```
    https://hooks.slack.com/services/YOUR_WORKSPACE_ID/YOUR_CHANNEL_ID/YOUR_SECRET_TOKEN
    ```

13. **Webhook URL speichern** in einem Textfile:
    ```bash
    # Webhook URLs für AlertManager Config

    # Channel: alerts-critical (P1-P2)
    CRITICAL_WEBHOOK="https://hooks.slack.com/services/YOUR_WORKSPACE_ID/YOUR_CHANNEL_ID/YOUR_SECRET_TOKEN"
    ```

---

### **Webhooks für andere Channels:**

**WICHTIG**: Du brauchst **5 separate Webhooks** (1 pro Channel)!

**Schnelle Methode** - Alle auf einmal erstellen:

1. **Zurück zur App**: https://api.slack.com/apps → Deine App auswählen
2. **"Incoming Webhooks"** (linkes Menü)
3. **"Add New Webhook to Workspace"** → **Channel: `#alerts-warning`** → **Allow**
4. **URL kopieren** → in Textfile speichern als `WARNING_WEBHOOK`
5. **Wiederholen für**:
   - `#alerts-info` → `INFO_WEBHOOK`
   - `#controller-health` → `CONTROLLER_WEBHOOK`
   - `#monitoring-health` → `MONITORING_WEBHOOK`

**Dein Textfile sollte jetzt so aussehen:**

```bash
# Slack Webhook URLs - Homelab Alertmanager

# P1-P2 Critical & High Priority
CRITICAL_WEBHOOK="https://hooks.slack.com/services/T0123/B0123/XXXX1"

# P3 Warning Priority
WARNING_WEBHOOK="https://hooks.slack.com/services/T0123/B0456/XXXX2"

# P4-P5 Info Priority
INFO_WEBHOOK="https://hooks.slack.com/services/T0123/B0789/XXXX3"

# GitOps Controller Health
CONTROLLER_WEBHOOK="https://hooks.slack.com/services/T0123/B0ABC/XXXX4"

# Monitoring Stack Health
MONITORING_WEBHOOK="https://hooks.slack.com/services/T0123/B0DEF/XXXX5"
```

---

## 🧪 WEBHOOKS TESTEN

**Test jeden Webhook einzeln:**

```bash
# Test Critical Channel
curl -X POST 'https://hooks.slack.com/services/T0123/B0123/XXXX1' \
  -H 'Content-Type: application/json' \
  -d '{"text":"🚨 TEST CRITICAL ALERT - Webhook funktioniert!"}'

# Test Warning Channel
curl -X POST 'https://hooks.slack.com/services/T0123/B0456/XXXX2' \
  -H 'Content-Type: application/json' \
  -d '{"text":"⚠️ TEST WARNING - Webhook funktioniert!"}'

# Test Info Channel
curl -X POST 'https://hooks.slack.com/services/T0123/B0789/XXXX3' \
  -H 'Content-Type: application/json' \
  -d '{"text":"ℹ️ TEST INFO - Webhook funktioniert!"}'

# Test Controller Health
curl -X POST 'https://hooks.slack.com/services/T0123/B0ABC/XXXX4' \
  -H 'Content-Type: application/json' \
  -d '{"text":"🎛️ ArgoCD Controller Healthy - Test"}'

# Test Monitoring Health
curl -X POST 'https://hooks.slack.com/services/T0123/B0DEF/XXXX5' \
  -H 'Content-Type: application/json' \
  -d '{"text":"💚 Watchdog Heartbeat - Monitoring OK"}'
```

**Jeder Test sollte eine Nachricht in seinem Channel posten!** ✅

---

## ⚙️ ALERTMANAGER CONFIG ANPASSEN

Jetzt die Webhooks in deine AlertManager Config einfügen:

### **File öffnen:**

```bash
nano kubernetes/infrastructure/monitoring/alertmanager/enterprise-alertmanager-config.yaml
```

### **Global Slack Config (Zeile 36-37) LÖSCHEN:**

```yaml
# ALTE ZEILE LÖSCHEN:
slack_api_url_file: '/etc/alertmanager/secrets/slack-api-url'
```

### **Receivers anpassen - 5 verschiedene Webhooks:**

#### **1. Critical Receiver (Zeile ~163-173)**

```yaml
- name: 'tier-0-critical-pager'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0123/XXXX1'  # DEIN CRITICAL WEBHOOK
    channel: '#alerts-critical'
    title: '🚨 TIER-0 CRITICAL ALERT 🚨'
    text: |
      *Priority:* P1 - IMMEDIATE ACTION REQUIRED
      *Status:* {{ .Status | toUpper }}
      {{ range .Alerts }}
      *Alert:* {{ .Labels.alertname }}
      *Instance:* {{ .Labels.instance }}
      *Summary:* {{ .Annotations.summary }}
      *Description:* {{ .Annotations.description }}
      {{ end }}
    color: 'danger'
    send_resolved: true
```

#### **2. High Priority Receiver (Zeile ~209-223)**

```yaml
- name: 'tier-1-critical-multi'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0123/XXXX1'  # CRITICAL WEBHOOK (same)
    channel: '#alerts-critical'
    title: '🔴 Critical Alert: {{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.summary }}'
    color: 'danger'
    send_resolved: true
```

#### **3. Warning Receiver (Zeile ~230-238)**

```yaml
- name: 'tier-2-warning'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0456/XXXX2'  # WARNING WEBHOOK
    channel: '#alerts-warning'
    title: '⚠️ Warning: {{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.summary }}'
    color: 'warning'
    send_resolved: true
```

#### **4. Info Receiver (Zeile ~243-250)**

```yaml
- name: 'tier-3-info'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0789/XXXX3'  # INFO WEBHOOK
    channel: '#alerts-info'
    title: 'ℹ️ Info: {{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.summary }}'
    color: 'good'
    send_resolved: false
```

#### **5. Monitoring Health Receiver (Zeile ~283-286)**

```yaml
- name: 'watchdog'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0DEF/XXXX5'  # MONITORING WEBHOOK
    channel: '#monitoring-health'
    title: '💚 Watchdog Heartbeat'
    text: 'Monitoring system healthy - Alert pipeline operational'
    send_resolved: false
```

### **NEUE Receiver für Controller Health hinzufügen:**

**Nach dem "watchdog" receiver (Zeile ~287) EINFÜGEN:**

```yaml
# ====== CONTROLLER HEALTH (GitOps/Secrets/Certs) ======
- name: 'controller-health'
  slack_configs:
  - webhook_url: 'https://hooks.slack.com/services/T0123/B0ABC/XXXX4'  # CONTROLLER WEBHOOK
    channel: '#controller-health'
    title: '🎛️ Controller Alert: {{ .GroupLabels.alertname }}'
    text: |
      *Component:* {{ .CommonLabels.component }}
      *Status:* {{ .Status | toUpper }}
      {{ range .Alerts }}
      {{ .Annotations.summary }}
      {{ end }}
    color: 'warning'
    send_resolved: true
```

---

## 🎯 ROUTING ANPASSEN - Controller Health Route

**In der `route:` section (Zeile ~66-147) HINZUFÜGEN nach den anderen routes:**

```yaml
route:
  receiver: 'tier-3-default'
  group_by: ['cluster', 'alertname', 'namespace', 'service', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
  # ... existing routes ...

  # ====== CONTROLLER HEALTH ALERTS ======
  - matchers:
    - component=~"gitops|secrets|certificates"
    receiver: 'controller-health'
    group_wait: 1m
    group_interval: 5m
    repeat_interval: 30m
    continue: false  # Don't also send to default
```

---

## 📋 FINAL WEBHOOK CONFIG SUMMARY

**Deine 5 Channels und ihre Verwendung:**

| **Channel** | **Webhook** | **Alerts** | **SLA** |
|------------|------------|-----------|---------|
| **#alerts-critical** | `CRITICAL_WEBHOOK` | P1-P2: API Down, ETCD Failure, Ceph ERROR | 5-30min |
| **#alerts-warning** | `WARNING_WEBHOOK` | P3: RAM >85%, Disk >90%, HEALTH_WARN | 2h |
| **#alerts-info** | `INFO_WEBHOOK` | P4-P5: Load spikes, Deployments | No SLA |
| **#controller-health** | `CONTROLLER_WEBHOOK` | ArgoCD, Sealed Secrets, Cert-Manager | 30min |
| **#monitoring-health** | `MONITORING_WEBHOOK` | Watchdog, Prometheus/Grafana health | 5min |

---

## 🚀 DEPLOYMENT

```bash
# 1. Config speichern und schließen
# (nano: Ctrl+X → Y → Enter)

# 2. Änderungen deployen
kubectl apply -k kubernetes/infrastructure/monitoring/alertmanager/

# 3. Alertmanager neu laden
kubectl rollout restart statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager

# 4. Logs checken
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -f | grep -i slack
```

**Erfolgsmeldung suchen:**
```
level=info msg="Completed loading of configuration file"
```

---

## 🧪 ALERTS TESTEN

### **Test 1: Watchdog (erscheint alle 5min in #monitoring-health)**

```bash
# Warte 2-3 Minuten, dann solltest du sehen:
# 💚 Watchdog Heartbeat - Monitoring OK
```

### **Test 2: Manual P3 Warning Alert**

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-warning
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestWarningAlert
      expr: vector(1)
      labels:
        severity: warning
        priority: P3
      annotations:
        summary: "⚠️ TEST WARNING - Should appear in #alerts-warning"
        description: "This is a test - ignore and delete PrometheusRule"
EOF

# Warte 2-3 Minuten
# Check #alerts-warning channel für die Nachricht

# Cleanup:
kubectl delete prometheusrule test-warning -n monitoring
```

### **Test 3: Manual P1 Critical Alert**

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-critical
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestCriticalAlert
      expr: vector(1)
      labels:
        severity: critical
        tier: "0"
        priority: P1
      annotations:
        summary: "🚨 TEST CRITICAL - Should appear in #alerts-critical"
        description: "P1 test alert - immediate action would be required"
EOF

# Check #alerts-critical channel
# Cleanup:
kubectl delete prometheusrule test-critical -n monitoring
```

---

## 📱 MOBILE NOTIFICATIONS (Optional)

**Für echtes On-Call Setup:**

1. **Slack Mobile App** installieren
2. **Channel Notifications einstellen**:
   - **#alerts-critical**: **ALL messages** + **Push notifications**
   - **#alerts-warning**: **Mentions only** (oder ALL wenn du willst)
   - **#alerts-info**: **Nothing** (nur Desktop checken)

**So einstellen:**
1. In jedem Channel → **Channel Name** oben klicken
2. **"Notifications"** → **"Notify me about..."**
3. **#alerts-critical**: **"All new messages"** ✅
4. **"Mobile push notifications"**: **ON** ✅

---

## 🎉 FERTIG!

**Du hast jetzt:**

✅ **5 Slack Channels** mit klarer Struktur
✅ **5 Webhooks** für priority-based routing
✅ **Multi-tier alerting** wie Production
✅ **Controller health monitoring** (ArgoCD etc.)
✅ **Watchdog heartbeat** (alle 5min = healthy!)

**GENAU WIE BEI DEINEM BETRIEB!** 🚀

---

## 💡 PRO TIPS

1. **Channel Bookmarks** hinzufügen:
   - Grafana Dashboard URL
   - Prometheus URL
   - ArgoCD URL
   - Runbook Links

2. **Slack Reminders** für regelmäßige Checks:
   ```
   /remind #alerts-critical to "Check Ceph health" every Monday at 9am
   ```

3. **Channel Descriptions** up-to-date halten mit aktuellen SLAs

4. **Slack Workflows** (Advanced):
   - Auto-create incidents from P1 alerts
   - Tag on-call person automatically
   - Update status page

**VIEL ERFOLG MIT DEINEM ENTERPRISE ALERTING!** 🎊
