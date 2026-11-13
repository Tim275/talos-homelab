variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token, Zone:DNS:Edit"
}

variable "zone_id" {
  type        = string
  description = "Zone-ID von timourhomelab.org"
}

variable "zone_name" {
  type        = string
  default     = "timourhomelab.org"
  description = "Domain"
}

variable "tunnel_id" {
  type        = string
  default     = "b5f4258e-8cd9-4454-b46e-6f4f34219bb4"
  description = "cloudflared-Tunnel-ID"
}

variable "public_hosts" {
  type        = list(string)
  default     = ["drova", "n8n", "homepage"]
  description = "Subdomains mit CNAME auf den Tunnel"
}

variable "publish_apex" {
  type        = bool
  default     = false
  description = "Apex auch auf den Tunnel"
}

variable "envoy_lb_ip" {
  type        = string
  default     = "192.168.0.152"
  description = "LoadBalancer-IP des Envoy-Gateway"
}

variable "proxmox_hosts" {
  type = map(string)
  default = {
    msa2proxmox = "192.168.0.50"
    nipogi      = "192.168.0.57"
    aoostar     = "192.168.0.59"
  }
  description = "Proxmox-Hosts und ihre LAN-IP"
}
