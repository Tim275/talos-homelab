variable "uptime_kuma_url" {
  type        = string
  default     = "https://status.timourhomelab.org"
  description = "Uptime-Kuma-URL"
}

variable "uptime_kuma_username" {
  type        = string
  default     = "Tim"
  description = "Admin-Benutzer"
}

variable "uptime_kuma_password" {
  type        = string
  sensitive   = true
  description = "Admin-Passwort"
}

variable "telegram_bot_token" {
  type        = string
  sensitive   = true
  description = "Telegram-Bot-Token"
}

variable "telegram_chat_id" {
  type        = string
  default     = "8449184586"
  description = "Telegram-Chat-ID"
}

variable "slack_webhook_url" {
  type        = string
  sensitive   = true
  description = "Slack-Webhook"
}
