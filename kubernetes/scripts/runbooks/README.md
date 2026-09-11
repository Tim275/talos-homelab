# Runbooks

Ziel des `Runbook`-Buttons in den Slack-Alerts. Ein Alert ohne `runbook_url`-Annotation
landet hier.

| Runbook | Wofür |
|---|---|
| [node-memory-ballooning.md](node-memory-ballooning.md) | Node-Restarts/OOM-Kills über mehrere Namespaces, Ceph `OSD_SLOW_PING_TIME`, `PrometheusPodMissing` flappt |
| [dr-drill-log.md](dr-drill-log.md) | Velero/CNPG Restore-Drills, RTO-Messung |
| [cloudflare-setup.md](cloudflare-setup.md) | Tunnel + DNS |
| [cloudflare-access-setup.md](cloudflare-access-setup.md) | Zugriffsrichtlinien |

Alert-spezifische Anleitungen stehen direkt in der Regel (`annotations.action`) — hier
landet nur, was mehr als zwei Befehle braucht.
