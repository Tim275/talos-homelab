variable "proxmox" {
  type = object({
    cluster_name = string
    endpoint     = string
    insecure     = bool
  })
}

variable "proxmox_api_token" {
  description = "API token for Proxmox"
  type        = string
  sensitive   = true
}