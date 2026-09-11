# Uptime-Kuma-Monitore + Status-Seite — unabhängig von Prometheus/Alertmanager

resource "uptimekuma_notification_telegram" "main" {
  name       = "Telegram"
  bot_token  = var.telegram_bot_token
  chat_id    = var.telegram_chat_id
  is_active  = true
  is_default = true
}

locals {
  # öffentlicher Weg: Tunnel → Gateway → App
  public_monitors = {
    "Drova Frontend" = "https://drova.timourhomelab.org/"
    "n8n"            = "https://n8n.timourhomelab.org/healthz"
    "Keycloak"       = "https://iam.timourhomelab.org/realms/kubernetes"
    "Forgejo"        = "https://forgejo.timourhomelab.org/api/healthz"
    "Homepage"       = "https://homepage.timourhomelab.org/"
  }

  # intern, ohne Ingress dazwischen
  internal_monitors = {
    "Alertmanager" = "http://alertmanager-operated.monitoring.svc.cluster.local:9093/-/healthy"
    "Prometheus"   = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/-/healthy"
    "Grafana"      = "http://grafana-service.grafana.svc.cluster.local:3000/api/health"
    "ArgoCD"       = "http://argocd-server.argocd.svc.cluster.local:80/healthz"
  }
}

resource "uptimekuma_monitor_http" "public" {
  for_each = local.public_monitors

  name             = each.key
  url              = each.value
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [uptimekuma_notification_telegram.main.id]
}

resource "uptimekuma_monitor_http" "internal" {
  for_each = local.internal_monitors

  name             = each.key
  url              = each.value
  interval         = 60
  timeout          = 30
  max_retries      = 2
  active           = true
  notification_ids = [uptimekuma_notification_telegram.main.id]
}

# /health antwortet bei totem Backend trotzdem mit 200 (Frontend-HTML) — deshalb Keyword
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
  description = "Anwendungen und Monitoring-Stack"
  published   = true
  show_tags   = false
  theme       = "auto"

  public_group_list = [
    {
      name   = "Anwendungen"
      weight = 1
      monitor_list = concat(
        [for k, m in uptimekuma_monitor_http.public : { id = m.id, send_url = true, url = m.url }],
        [
          { id = uptimekuma_monitor_http_keyword.drova_health.id, send_url = false, url = "" },
          { id = uptimekuma_monitor_http_keyword.drova_ready.id, send_url = false, url = "" },
        ]
      )
    },
    {
      name         = "Monitoring"
      weight       = 2
      monitor_list = [for k, m in uptimekuma_monitor_http.internal : { id = m.id, send_url = false, url = "" }]
    },
  ]
}
