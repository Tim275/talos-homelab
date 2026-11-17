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

output "iac_token" {
  description = "PROXMOX_VE_API_TOKEN für diesen Stack"
  value       = proxmox_user_token.this["iac"].value
  sensitive   = true
}
