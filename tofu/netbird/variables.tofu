variable "netbird_api_token" {
  type        = string
  sensitive   = true
  description = "NetBird Personal Access Token (Dashboard → User → Settings → API Keys). NIE committen — via TF_VAR_netbird_api_token oder Key Vault."
}

variable "netbird_management_url" {
  type        = string
  default     = "https://api.netbird.io"
  description = "Cloud-Default. Self-hosted: https://netbird.deine-domain"
}

variable "lan_cidr" {
  type        = string
  default     = "192.168.0.0/24"
  description = "Das Homelab-LAN, das die Routing-Peers ins Mesh announcen."
}

variable "dns_domain" {
  type        = string
  default     = "timourhomelab.org"
  description = "Match-Domain für Split-DNS — wird auf die interne Gateway-IP aufgelöst (nur für VPN-Clients)."
}

# split_dns_ip ENTFERNT — Operator macht DNS (Zone k8s.timourhomelab.org)
