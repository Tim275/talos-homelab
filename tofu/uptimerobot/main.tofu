# Aussen-Sicht auf die oeffentlichen Dienste. Blackbox-Exporter und Uptime-Kuma laufen
# beide IM Cluster und loesen die Hostnames intern auf die ClusterIP auf — sie pruefen
# also nie den Weg ueber cloudflared und Cloudflare. Faellt der aus, bleiben beide gruen.
# UptimeRobot prueft von ausserhalb und alarmiert auch dann, wenn das Haus dunkel ist.

resource "uptimerobot_integration" "slack" {
  name                     = "homelab-slack"
  type                     = "slack"
  value                    = var.slack_webhook_url
  enable_notifications_for = 1
  ssl_expiration_reminder  = true
}

resource "uptimerobot_monitor" "public" {
  for_each = var.public_targets

  name = "homelab-${each.key}"
  type = "HTTP"
  url  = each.value

  # 300s ist das Minimum im Free-Tier
  interval = 300

  ssl_expiration_reminder = true
  check_ssl_errors        = true

  # threshold/recurrence sind laut Schema Pflicht: 0/0 = sofort melden, nicht wiederholen
  assigned_alert_contacts = [
    {
      alert_contact_id = uptimerobot_integration.slack.id
      threshold        = 0
      recurrence       = 0
    },
  ]
}
