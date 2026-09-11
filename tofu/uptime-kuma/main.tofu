resource "uptimekuma_notification_telegram" "main" {
  name       = "Telegram"
  bot_token  = var.telegram_bot_token
  chat_id    = var.telegram_chat_id
  is_active  = true
  is_default = true
}

locals {
  groups = ["Anwendungen", "Monitoring", "Plattform"]

  monitors = {
    "Drova"        = { url = "https://drova.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"] }
    "n8n"          = { url = "https://n8n.timourhomelab.org/healthz", group = "Anwendungen", codes = ["200-299"] }
    "Forgejo"      = { url = "https://forgejo.timourhomelab.org/api/healthz", group = "Anwendungen", codes = ["200-299"] }
    "Keycloak"     = { url = "https://iam.timourhomelab.org/realms/kubernetes", group = "Anwendungen", codes = ["200-299"] }
    "Homepage"     = { url = "https://homepage.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"] }
    "LLDAP"        = { url = "https://lldap.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"] }
    "pgAdmin"      = { url = "https://pgadmin.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"] }
    "OpenBao"      = { url = "https://openbao.timourhomelab.org/", group = "Anwendungen", codes = ["200-299"] }
    "Grafana"      = { url = "https://grafana.timourhomelab.org/", group = "Monitoring", codes = ["200-299"] }
    "Prometheus"   = { url = "https://prometheus.timourhomelab.org/", group = "Monitoring", codes = ["200-299"] }
    "Alertmanager" = { url = "https://alertmanager.timourhomelab.org/", group = "Monitoring", codes = ["200-299"] }
    "Kibana"       = { url = "https://kibana.timourhomelab.org/", group = "Monitoring", codes = ["200-299"] }
    "Hubble"       = { url = "https://hubble.timourhomelab.org/", group = "Monitoring", codes = ["200-299"] }
    "Jaeger"       = { url = "https://jaeger.timourhomelab.org/", group = "Monitoring", codes = ["200-299", "401"] }
    "Kiali"        = { url = "https://kiali.timourhomelab.org/", group = "Monitoring", codes = ["200-299", "401"] }
    "ArgoCD"       = { url = "https://argo.timourhomelab.org/", group = "Plattform", codes = ["200-299"] }
    "Ceph"         = { url = "https://ceph.timourhomelab.org/", group = "Plattform", codes = ["200-299"] }
    "Redpanda"     = { url = "https://redpanda.timourhomelab.org/", group = "Plattform", codes = ["200-299", "401"] }
    "Renovate"     = { url = "https://renovate.timourhomelab.org/", group = "Plattform", codes = ["200-299", "401"] }
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
  notification_ids      = [uptimekuma_notification_telegram.main.id]
}

resource "uptimekuma_monitor_http_keyword" "drova_health" {
  name             = "Drova API"
  url              = "https://drova.timourhomelab.org/health"
  keyword          = "i am alive"
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [uptimekuma_notification_telegram.main.id]
}

resource "uptimekuma_monitor_http_keyword" "drova_ready" {
  name             = "Drova Readiness"
  url              = "https://drova.timourhomelab.org/readyz"
  keyword          = "ready"
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [uptimekuma_notification_telegram.main.id]
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
