variable "netbird_api_token" {
  type        = string
  sensitive   = true
  description = "NetBird API-Token"
}

variable "netbird_management_url" {
  type        = string
  default     = "https://api.netbird.io"
  description = "NetBird Management-URL"
}

variable "lan_targets" {
  type = map(string)
  default = {
    envoy_lb       = "192.168.0.152/32" # Envoy-Gateway
    kube_api       = "192.168.0.100/32" # kube-apiserver VIP
    talos_ctrl0    = "192.168.0.101/32" # ctrl-0, talosctl :50000
    proxmox_msa2   = "192.168.0.50/32"  # msa2proxmox — SSH
    proxmox_nipogi = "192.168.0.57/32"  # nipogi — SSH
    proxmox_pve    = "192.168.0.58/32"  # pve/hpdesk — SSH
  }
  description = "Ziel-IPs, die über NetBird erreichbar sind"
}

variable "dns_domain" {
  type        = string
  default     = "timourhomelab.org"
  description = "Match-Domain für Split-DNS"
}
