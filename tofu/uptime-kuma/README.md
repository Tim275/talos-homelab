# tofu/uptime-kuma — Monitore als Code

Zweite Überwachung neben Prometheus/Alertmanager, mit eigenem Telegram-Sender und
öffentlicher Status-Seite. **Eigener State** (`uptime-kuma.tfstate`).

## Was es managed / NICHT managed
```
✅ Uptime-Kuma-Inhalt:  Monitore, Telegram-Notification, Status-Seite
❌ NICHT:  die Uptime-Kuma-Instanz selbst (Deployment/PVC/HTTPRoute)  → GitOps
           Admin-User + Passwort (beim ersten Login gesetzt)          → manuell
           externer Dead-Man's-Switch                                 → healthchecks.io
```

Uptime-Kuma läuft im Cluster und fällt bei einem Totalausfall mit aus — das deckt nur
healthchecks.io ab. Was es dafür kann und Alertmanager nicht: dessen eigenen Ausfall melden.

## Voraussetzungen
1. **Admin-Passwort** der Instanz (beim ersten Login vergeben, liegt in keinem Secret).
2. **Telegram-Bot-Token:** derselbe wie bei Alertmanager —
   `kubectl get secret telegram-bot-token -n monitoring -o jsonpath='{.data.token}' | base64 -d`
3. **LAN oder NetBird** — `status.timourhomelab.org` zeigt auf 192.168.0.152, nicht ins Internet.

## Apply
```bash
cd tofu/uptime-kuma
export TF_VAR_uptime_kuma_password='...'       # NIE committen
export TF_VAR_telegram_bot_token="$(kubectl get secret telegram-bot-token -n monitoring -o jsonpath='{.data.token}' | base64 -d)"
tofu init
tofu plan      # 1 Notification, 11 Monitore, 1 Status-Seite
tofu apply
```

`tofu output status_page_url` liefert danach die URL fürs Homepage-Widget
(`type: uptime-kuma`, slug `homelab`).

## Was überwacht wird
| Gruppe | Was | Warum so |
|---|---|---|
| Anwendungen | Drova (API · Readiness · Frontend), n8n, Keycloak, Forgejo, Homepage | öffentlicher Weg — prüft Tunnel, Gateway und App zusammen |
| Monitoring | Alertmanager, Prometheus, Grafana, ArgoCD | intern — zeigt beim Ausfall, wo es klemmt |

Drova läuft als Keyword-Check: `/health` antwortet auch bei totem Backend mit 200
(Frontend-HTML), ein reiner Status-Check wäre dann fälschlich grün. Geprüft wird der
Inhalt (`i am alive` bzw. `ready`).
