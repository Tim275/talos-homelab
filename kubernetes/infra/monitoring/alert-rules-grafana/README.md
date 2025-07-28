# 🚨 Talos Homelab Alert Rules

Alert Rules für Talos Linux Homelab mit Outlook E-Mail Integration.

## 📧 Setup Outlook Authentication

1. **App-spezifisches Passwort erstellen:**
   - Gehe zu https://account.microsoft.com/security
   - Klicke auf "Advanced security options"  
   - Wähle "App passwords"
   - Erstelle neues App-Passwort für "Talos Homelab"

2. **Passwort in Config einsetzen:**
   ```bash
   # Edit alertmanager-config.yaml
   # Ersetze: YOUR_OUTLOOK_APP_PASSWORD
   # Mit: dem generierten App-Passwort
   ```

## 🚀 Deployment

```bash
# 1. Alert Rules deployen
kubectl apply -k kubernetes/infra/monitoring/alert-rules-grafana/

# 2. Verifizieren
kubectl get prometheusrules -n monitoring
kubectl get configmap alertmanager-config -n monitoring

# 3. Alertmanager neu starten (damit Config geladen wird)
kubectl rollout restart deployment alertmanager -n monitoring
```

## 🧪 Alert Testing

```bash
# Test Script ausführen
./test-alert-triggers.sh

# Einzelne Tests:
# 1. Always Firing Test (sofort)
# 2. Memory Stress Test (5 Min)
# 3. CPU Stress Test (10 Min)  
# 4. Crash Loop Test (5 Min)
# 5. Error Log Test (2 Min)
```

## 📊 Alert Kategorien

### 🔴 Critical Alerts
- **TalosNodeDown:** Node unreachable (2 Min)
- **TalosKubeletDown:** Kubelet down (1 Min)
- **TalosKubernetesApiServerDown:** API Server down (1 Min)
- **TalosEtcdDown:** etcd down (1 Min)
- **TalosDiskSpaceCritical:** Disk >90% (5 Min)

### 🟡 Warning Alerts  
- **TalosHighMemoryUsage:** Memory >85% (5 Min)
- **TalosHighCPUUsage:** CPU >80% (10 Min)
- **KubernetesPodCrashLooping:** Pod restarts (5 Min)
- **LokiDown:** Loki service down (2 Min)
- **PromtailDown:** Promtail agent down (2 Min)

### 🔵 Info Alerts (Testing)
- **TestAlertAlwaysFiring:** Always active
- **TestHighCPULoad:** CPU >50% (1 Min)
- **TestMemoryUsage:** Memory >50% (1 Min)

## 📧 E-Mail Konfiguration

**Empfänger:** timour.miagol@outlook.de

**Alert Frequenz:**
- Critical: Alle 15 Minuten
- Warning: Alle 2 Stunden  
- Standard: Alle 4 Stunden

**E-Mail Templates:**
- 🚨 Critical: Rot, hohe Priorität
- ⚠️ Warning: Gelb, normale Priorität
- 🔔 Info: Blau, niedrige Priorität

## 🔍 Monitoring & Troubleshooting

```bash
# Alert Status prüfen
kubectl get alerts -n monitoring

# Alertmanager Logs
kubectl logs deployment/alertmanager -n monitoring

# Prometheus Rules prüfen
kubectl get prometheusrules -n monitoring -o yaml

# Test E-Mail senden
kubectl exec -it deployment/alertmanager -n monitoring -- \
  amtool alert add alertname="TestEmail" \
  instance="test" severity="info"
```

## 🎯 Next Steps

1. **Outlook App-Passwort konfigurieren**
2. **Alert Rules mit ArgoCD deployen**  
3. **Test Script ausführen**
4. **E-Mail Inbox prüfen**
5. **Grafana Alerting Dashboard öffnen**

## 🔗 Useful Links

- **Grafana Alerts:** http://grafana.homelab.local/alerting
- **Prometheus Rules:** http://prometheus.homelab.local/rules
- **Alertmanager:** http://alertmanager.homelab.local
- **Outlook Security:** https://account.microsoft.com/security