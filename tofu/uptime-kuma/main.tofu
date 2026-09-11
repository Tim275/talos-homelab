resource "uptimekuma_notification_telegram" "apps" {
  name       = "Telegram"
  bot_token  = var.telegram_bot_token
  chat_id    = var.telegram_chat_id
  is_active  = true
  is_default = false
}

resource "uptimekuma_notification_slack" "admin" {
  name        = "Slack"
  webhook_url = var.slack_webhook_url
  channel     = "#alerts"
  is_active   = true
  is_default  = false
}

locals {
  groups = ["Anwendungen", "Monitoring", "Plattform"]

  monitors = {
    "Drova"        = { url = "https://drova.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"], notify = "telegram" }
    "n8n"          = { url = "https://n8n.timourhomelab.org/healthz", group = "Anwendungen", codes = ["200-299"], notify = "telegram" }
    "Forgejo"      = { url = "https://forgejo.timourhomelab.org/api/healthz", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "Keycloak"     = { url = "https://iam.timourhomelab.org/realms/kubernetes", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "Homepage"     = { url = "https://homepage.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "LLDAP"        = { url = "https://lldap.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "pgAdmin"      = { url = "https://pgadmin.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "OpenBao"      = { url = "https://openbao.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"], notify = "slack" }
    "Grafana"      = { url = "https://grafana.timourhomelab.org/", group = "Monitoring", codes = ["200-299"], notify = "slack" }
    "Prometheus"   = { url = "https://prometheus.timourhomelab.org/", group = "Monitoring", codes = ["200-299"], notify = "slack" }
    "Alertmanager" = { url = "https://alertmanager.timourhomelab.org/", group = "Monitoring", codes = ["200-299"], notify = "slack" }
    "Kibana"       = { url = "https://kibana.timourhomelab.org/", group = "Monitoring", codes = ["200-299"], notify = "slack" }
    "Hubble"       = { url = "https://hubble.timourhomelab.org/", group = "Monitoring", codes = ["200-299"], notify = "slack" }
    "Jaeger"       = { url = "https://jaeger.timourhomelab.org/", group = "Monitoring", codes = ["200-299", "401"], notify = "slack" }
    "Kiali"        = { url = "https://kiali.timourhomelab.org/", group = "Monitoring", codes = ["200-299", "401"], notify = "slack" }
    "ArgoCD"       = { url = "https://argo.timourhomelab.org/", group = "Plattform", codes = ["200-299"], notify = "slack" }
    "Ceph"         = { url = "https://ceph.timourhomelab.org/", group = "Plattform", codes = ["200-299"], notify = "slack" }
    "Redpanda"     = { url = "https://redpanda.timourhomelab.org/", group = "Plattform", codes = ["200-299", "401"], notify = "slack" }
    "Renovate"     = { url = "https://renovate.timourhomelab.org/", group = "Plattform", codes = ["200-299", "401"], notify = "slack" }
  }

  notification_id = {
    telegram = uptimekuma_notification_telegram.apps.id
    slack    = uptimekuma_notification_slack.admin.id
  }
}

resource "uptimekuma_monitor_http" "app" {
  for_each = local.monitors

  name                  = each.key
  url                   = each.value.url
  accepted_status_codes = each.value.codes
  interval              = 60
  timeout               = 30
  max_retries           = 2
  active                = true
  notification_ids      = [local.notification_id[each.value.notify]]
}

resource "uptimekuma_monitor_http_keyword" "drova_health" {
  name             = "Drova API"
  url              = "https://drova.timourhomelab.org/health"
  keyword          = "i am alive"
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [local.notification_id.telegram]
}

resource "uptimekuma_monitor_http_keyword" "drova_ready" {
  name             = "Drova Readiness"
  url              = "https://drova.timourhomelab.org/readyz"
  keyword          = "ready"
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [local.notification_id.telegram]
}

resource "uptimekuma_status_page" "homelab" {
  slug        = "homelab"
  title       = "Homelab Status"
  description = "Anwendungen, Monitoring und Plattform"
  published   = true
  show_tags   = false
  theme       = "auto"

  public_group_list = [
    for i, g in local.groups : {
      name   = g
      weight = i + 1
      monitor_list = concat(
        [for name, m in local.monitors : { id = uptimekuma_monitor_http.app[name].id, send_url = true, url = m.url } if m.group == g],
        g == "Anwendungen" ? [
          { id = uptimekuma_monitor_http_keyword.drova_health.id, send_url = false, url = "" },
          { id = uptimekuma_monitor_http_keyword.drova_ready.id, send_url = false, url = "" },
        ] : []
      )
    }
  ]
}
