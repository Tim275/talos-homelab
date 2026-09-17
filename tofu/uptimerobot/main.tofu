# geparkt
# resource "uptimerobot_integration" "slack" {
#   name                     = "homelab-slack"
#   type                     = "slack"
#   value                    = var.slack_webhook_url
#   enable_notifications_for = 1
#   ssl_expiration_reminder  = true
# }
#
# resource "uptimerobot_monitor" "public" {
#   for_each = var.public_targets
#
#   name     = "homelab-${each.key}"
#   type     = "HTTP"
#   url      = each.value
#   interval = 300 # Minimum im Free-Tier
#
#   ssl_expiration_reminder = true
#   check_ssl_errors        = true
#
#   assigned_alert_contacts = [
#     {
#       alert_contact_id = uptimerobot_integration.slack.id
#       threshold        = 0 # Schema verlangt beide Felder
#       recurrence       = 0
#     },
#   ]
# }
