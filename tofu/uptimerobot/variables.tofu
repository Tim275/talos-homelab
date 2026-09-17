variable "uptimerobot_api_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Main API Key, UptimeRobot > My Settings > API Settings."
}

variable "slack_webhook_url" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Derselbe Webhook wie im Alertmanager."
}

variable "public_targets" {
  type = map(string)
  default = {
    drova    = "https://drova.timourhomelab.org/"
    n8n      = "https://n8n.timourhomelab.org/healthz"
    homepage = "https://homepage.timourhomelab.org/"
  }
  description = "Von aussen erreichbare Endpunkte — die uebrigen 16 zeigen im oeffentlichen DNS auf 192.168.0.152."
}
