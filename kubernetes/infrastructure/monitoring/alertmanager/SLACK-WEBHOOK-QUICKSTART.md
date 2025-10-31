# ⚡ SLACK WEBHOOK QUICKSTART - 10 Minuten Setup

**Minimale Slack Setup für Alerting** - Keine Extras, nur das Nötigste!

---

## 🎯 WAS DU BRAUCHST

**Minimum Setup**: 1 Channel, 1 Webhook
**Empfohlen**: 2 Channels (Critical + Warning)

---

## 📋 OPTION 1: MINIMAL (1 Channel)

**Für**: Schnell testen, alles in einem Channel

### **Schritt 1: Channel erstellen**

1. **Slack öffnen**
2. **Channels** → **"+" klicken**
3. **Name**: `homelab-alerts`
4. **Description**: `All monitoring alerts`
5. **Public** ✅ → **Create**

### **Schritt 2: Webhook erstellen**

1. **Browser**: https://api.slack.com/apps
2. **"Create New App"** → **"From scratch"**
3. **Name**: `Homelab Alerts`
4. **Workspace**: Dein Workspace
5. **Create App**

6. **Linkes Menü** → **"Incoming Webhooks"**
7. **Toggle ON** ✅
8. **"Add New Webhook to Workspace"**
9. **Channel**: `#homelab-alerts`
10. **"Allow"**

11. **Webhook URL kopieren**:
    ```
    https://hooks.slack.com/services/T0000/B0000/XXXX
    ```

### **Schritt 3: Webhook testen**

```bash
curl -X POST 'https://hooks.slack.com/services/T0000/B0000/XXXX' \
  -H 'Content-Type: application/json' \
  -d '{"text":"🚨 TEST ALERT - Webhook works!"}'
```

**Nachricht in #homelab-alerts?** ✅ Perfect!

### **Schritt 4: AlertManager Config**

```bash
# Config öffnen
nano kubernetes/infrastructure/monitoring/alertmanager/enterprise-alertmanager-config.yaml
```

**Suchen nach Zeile 36-37 und LÖSCHEN:**
```yaml
# DIESE ZEILE LÖSCHEN:
slack_api_url_file: '/etc/alertmanager/secrets/slack-api-url'
```

**Suchen nach Zeile 164 und ERSETZEN:**
```yaml
# ALT:
- webhook_url: 'YOUR_DISCORD_WEBHOOK_URL_HERE'

# NEU:
- webhook_url: 'https://hooks.slack.com/services/T0000/B0000/XXXX'  # DEINE URL!
```

**Diese Zeile MEHRMALS ersetzen** (kommt ~8x vor im File):
```bash
# Schnell alle auf einmal:
cd kubernetes/infrastructure/monitoring/alertmanager/
sed -i.bak "s|YOUR_DISCORD_WEBHOOK_URL_HERE|https://hooks.slack.com/services/T0000/B0000/XXXX|g" enterprise-alertmanager-config.yaml
```

**Speichern & Schließen**

### **Schritt 5: Deployen**

```bash
kubectl apply -k kubernetes/infrastructure/monitoring/alertmanager/
kubectl rollout restart statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager
```

**Warte 2-3 Minuten, dann solltest du Watchdog alert in #homelab-alerts sehen!** ✅

---

## 📋 OPTION 2: EMPFOHLEN (2 Channels)

**Für**: Bessere Organisation - Critical vs Normal

### **Schritt 1: 2 Channels erstellen**

**Channel 1:**
- Name: `alerts-critical`
- Description: `🚨 P1-P2 Critical alerts only`

**Channel 2:**
- Name: `alerts-all`
- Description: `All monitoring alerts (P3-P5)`

### **Schritt 2: 2 Webhooks erstellen**

**Zurück zur App**: https://api.slack.com/apps → Deine App

**Webhook 1** (Critical):
1. **"Incoming Webhooks"**
2. **"Add New Webhook to Workspace"**
3. **Channel**: `#alerts-critical`
4. **Allow**
5. **URL kopieren** → Speichern als `CRITICAL_WEBHOOK`

**Webhook 2** (All):
1. **"Add New Webhook to Workspace"** (nochmal)
2. **Channel**: `#alerts-all`
3. **Allow**
4. **URL kopieren** → Speichern als `ALL_WEBHOOK`

### **Schritt 3: Beide testen**

```bash
# Test Critical
curl -X POST 'CRITICAL_WEBHOOK' \
  -H 'Content-Type: application/json' \
  -d '{"text":"🚨 Critical test"}'

# Test All
curl -X POST 'ALL_WEBHOOK' \
  -H 'Content-Type: application/json' \
  -d '{"text":"ℹ️ Info test"}'
```

### **Schritt 4: AlertManager Config - 2 Webhooks**

```bash
nano kubernetes/infrastructure/monitoring/alertmanager/enterprise-alertmanager-config.yaml
```

**Zeile 36-37 LÖSCHEN** (slack_api_url_file)

**Dann diese Receivers anpassen:**

**1. Critical (Zeile ~164-173)**:
```yaml
- name: 'tier-0-critical-pager'
  slack_configs:
  - webhook_url: 'CRITICAL_WEBHOOK_HIER'  # Channel: #alerts-critical
    channel: '#alerts-critical'
    title: '🚨 CRITICAL'
```

**2. High (Zeile ~209)**:
```yaml
- name: 'tier-1-critical-multi'
  slack_configs:
  - webhook_url: 'CRITICAL_WEBHOOK_HIER'  # Gleicher webhook!
    channel: '#alerts-critical'
```

**3. Warning (Zeile ~230)**:
```yaml
- name: 'tier-2-warning'
  slack_configs:
  - webhook_url: 'ALL_WEBHOOK_HIER'  # Channel: #alerts-all
    channel: '#alerts-all'
```

**4. Info (Zeile ~243)**:
```yaml
- name: 'tier-3-info'
  slack_configs:
  - webhook_url: 'ALL_WEBHOOK_HIER'  # Gleicher webhook!
    channel: '#alerts-all'
```

**5. Watchdog (Zeile ~283)**:
```yaml
- name: 'watchdog'
  slack_configs:
  - webhook_url: 'ALL_WEBHOOK_HIER'  # Gleicher webhook!
    channel: '#alerts-all'
```

**Speichern!**

### **Schritt 5: Deployen**

```bash
kubectl apply -k kubernetes/infrastructure/monitoring/alertmanager/
kubectl rollout restart statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager
```

---

## 🧪 TEST ALERTS

### **Watchdog (erscheint automatisch alle 5min)**

Warte 3-4 Minuten nach deployment → Sollte in **#alerts-all** erscheinen:
```
💚 Watchdog Heartbeat - Monitoring OK
```

**Wenn Watchdog NICHT kommt** = Alerting pipeline broken! 🚨

### **Manual Test Alert (P3 Warning)**

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
        summary: "⚠️ TEST - Erscheint in #alerts-all"
EOF
```

Warte 2-3 Minuten → Check **#alerts-all**

**Cleanup:**
```bash
kubectl delete prometheusrule test-alert -n monitoring
```

### **Manual Test Alert (P1 Critical)**

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
    - alert: TestCritical
      expr: vector(1)
      labels:
        severity: critical
        tier: "0"
        priority: P1
      annotations:
        summary: "🚨 CRITICAL TEST - Erscheint in #alerts-critical"
EOF
```

Warte 2-3 Minuten → Check **#alerts-critical**

**Cleanup:**
```bash
kubectl delete prometheusrule test-critical -n monitoring
```

---

## 🔧 TROUBLESHOOTING

### **"Keine Nachrichten in Slack"**

```bash
# 1. Check AlertManager logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -i slack

# 2. Check für errors
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -i error

# 3. Check ob config geladen wurde
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep "Completed loading"
```

**Sollte sehen:**
```
level=info msg="Completed loading of configuration file"
```

### **"Webhook 404 Error"**

- Webhook URL falsch kopiert?
- Teste manuell mit curl (siehe oben)

### **"Channel nicht gefunden"**

- Channel Name korrekt in config? (mit #)
- Channel ist Public? (nicht Private)

---

## 📱 MOBILE NOTIFICATIONS

**Wichtig für On-Call!**

1. **Slack Mobile App** installieren
2. **Settings** → **Notifications**
3. **#alerts-critical**:
   - **"All new messages"** ✅
   - **"Push notifications"** ✅
4. **#alerts-all**:
   - **"Mentions only"** (oder aus)

**Jetzt bekommst du P1/P2 alerts auf dein Phone!** 📱

---

## ✅ FERTIG!

**Option 1 (Minimal)**:
- ✅ 1 Channel (#homelab-alerts)
- ✅ 1 Webhook
- ✅ Alle alerts in einem Channel
- ⏱️ Setup: 10 Minuten

**Option 2 (Empfohlen)**:
- ✅ 2 Channels (#alerts-critical, #alerts-all)
- ✅ 2 Webhooks
- ✅ Critical alerts getrennt
- ⏱️ Setup: 15 Minuten

**DU HAST JETZT PRODUCTION-READY ALERTING!** 🚀

---

## 📊 WAS KOMMT IN WELCHEN CHANNEL?

### **#alerts-critical** (Option 2 only)
- 🚨 API Server Down
- 🚨 ETCD Failures
- 🚨 Prometheus Down
- 🚨 Ceph HEALTH_ERROR
- 🚨 PostgreSQL Primary Down
- 🚨 Brute Force Attacks

### **#alerts-all** (oder #homelab-alerts in Option 1)
- ⚠️ RAM >85%
- ⚠️ Disk >90%
- ⚠️ Ceph HEALTH_WARN
- ℹ️ Load Spikes
- 💚 Watchdog Heartbeat (alle 5min)

---

**VIEL ERFOLG!** 🎉
