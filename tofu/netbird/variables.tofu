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
  type = map(object({
    address = string
    ports   = list(string)
  }))
  default = {
    envoy_lb       = { address = "192.168.0.152/32", ports = ["80", "443"] }
    kube_api       = { address = "192.168.0.100/32", ports = ["6443"] }
    talos_ctrl0    = { address = "192.168.0.101/32", ports = ["50000"] }
    proxmox_msa2   = { address = "192.168.0.50/32", ports = ["22", "8006"] }
    proxmox_nipogi = { address = "192.168.0.57/32", ports = ["22", "8006"] }
    proxmox_pve    = { address = "192.168.0.58/32", ports = ["22", "8006"] }
  }
  description = "Ziele im LAN mit den erlaubten TCP-Ports"
}

variable "dns_domain" {
  type        = string
  default     = "timourhomelab.org"
  description = "Match-Domain für Split-DNS"
}
