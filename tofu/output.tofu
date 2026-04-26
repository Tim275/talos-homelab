resource "local_file" "machine_configs" {
  for_each        = module.talos.machine_config
  content         = each.value.machine_configuration
  filename        = "output/talos-machine-config-${each.key}.yaml"
  file_permission = "0600"
}

resource "local_file" "talos_config" {
  content         = module.talos.client_configuration.talos_config
  filename        = "output/talos-config.yaml"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.talos.kube_config.kubeconfig_raw
  filename        = "output/kube-config.yaml"
  file_permission = "0600"
}

output "kube_config" {
  value     = module.talos.kube_config.kubeconfig_raw
  sensitive = true
}

output "talos_config" {
  value     = module.talos.client_configuration.talos_config
  sensitive = true
}

# ==============================================================================
# SECURITY OUTPUTS — copy these after first apply
# ==============================================================================
output "proxmox_tofu_token" {
  description = "API token for tofu@pve — already in id=secret format, copy directly to proxmox_api_token"
  value       = proxmox_virtual_environment_user_token.tofu.value
  sensitive   = true
}

output "proxmox_tofu_token_id" {
  description = "Token ID (non-sensitive part) — for reference"
  value       = proxmox_virtual_environment_user_token.tofu.id
}