# uptime-kuma

Monitore, Telegram-Benachrichtigung und Status-Seite von Uptime Kuma als Code. Die Instanz selbst kommt
per GitOps (`kubernetes/apps/uptime-kuma`), das Admin-Passwort wird beim ersten Login gesetzt.
Apply läuft über `tofu-cd.yml` nach dem Merge, lokal `tofu plan` mit `TF_VAR_uptime_kuma_password`,
`TF_VAR_telegram_bot_token` (Secret `telegram-bot-token` in `monitoring`) und `TF_VAR_slack_webhook_url`.
Geprüft wird der Weg über Tunnel und Gateway, Drova per Keyword, weil `/health` auch bei totem Backend 200 liefert.
`tofu output status_page_url` ist die URL fürs Homepage-Widget.
