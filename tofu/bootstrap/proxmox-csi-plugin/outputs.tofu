output "proxmox_csi_config" {
  description = "Proxmox CSI configuration for creating SealedSecret"
  sensitive   = true
  value = {
    token_id     = proxmox_virtual_environment_user_token.kubernetes-csi-token.id
    token_secret = element(split("=", proxmox_virtual_environment_user_token.kubernetes-csi-token.value), length(split("=", proxmox_virtual_environment_user_token.kubernetes-csi-token.value)) - 1)
    config_yaml = <<EOF
clusters:
- url: "${var.proxmox.endpoint}/api2/json"
  insecure: ${var.proxmox.insecure}
  token_id: "${proxmox_virtual_environment_user_token.kubernetes-csi-token.id}"
  token_secret: "${element(split("=", proxmox_virtual_environment_user_token.kubernetes-csi-token.value), length(split("=", proxmox_virtual_environment_user_token.kubernetes-csi-token.value)) - 1)}"
  region: ${var.proxmox.cluster_name}
EOF
  }
}