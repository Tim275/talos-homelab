variable "uptime_kuma_url" {
  type        = string
  default     = "https://status.timourhomelab.org"
  description = "Instanz-URL. Auflösung zeigt auf das LAN-Gateway — apply braucht LAN oder NetBird."
}

variable "uptime_kuma_username" {
  type        = string
  default     = "Tim"
  description = "Admin-Benutzer der Uptime-Kuma-Instanz."
}

variable "uptime_kuma_password" {
  type        = string
  sensitive   = true
  description = "Admin-Passwort, via TF_VAR_uptime_kuma_password."
}

variable "telegram_bot_token" {
  type        = string
  sensitive   = true
  description = "Bot-Token, via TF_VAR_telegram_bot_token. Gleicher Bot wie Alertmanager."
}

variable "telegram_chat_id" {
  type        = string
  default     = "8449184586"
  description = "Chat-ID, identisch zu Alertmanager."
}
