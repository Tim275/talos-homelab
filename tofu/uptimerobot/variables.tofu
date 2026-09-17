variable "uptimerobot_api_key" {
  type        = string
  sensitive   = true
  description = "Main API Key aus UptimeRobot (My Settings -> API Settings)."
}

variable "slack_webhook_url" {
  type        = string
  sensitive   = true
  description = "Derselbe Webhook wie im Alertmanager — die Benachrichtigung kommt aber von ausserhalb des Clusters."
}

# Nur die drei Dienste, die wirklich oeffentlich erreichbar sind (Cloudflare-Anycast).
# Die uebrigen 16 aufloesen im oeffentlichen DNS auf 192.168.0.152 und sind von aussen
# gar nicht routbar — ein externer Monitor koennte sie nie pruefen.
variable "public_targets" {
  type = map(string)
  default = {
    drova    = "https://drova.timourhomelab.org/"
    n8n      = "https://n8n.timourhomelab.org/healthz"
    homepage = "https://homepage.timourhomelab.org/"
  }
  description = "Von aussen pruefbare Endpunkte. Neuer oeffentlicher Dienst = hier ergaenzen."
}
