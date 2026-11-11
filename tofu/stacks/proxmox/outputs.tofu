output "talos_token" {
  description = "proxmox_api_token für tofu/"
  value       = proxmox_user_token.this["talos"].value
  sensitive   = true
}

output "monitoring_token_value" {
  description = "monitoring.pve-exporter-token.token_value"
  value       = regex("[^=]+$", proxmox_user_token.this["monitoring"].value)
  sensitive   = true
}
