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

# lan_cidr (192.168.0.0/24 als EINE Resource) ENTFERNT — Routing-Konflikt auf fremden
# Netzen, die selbst dieses Subnet nutzen (Hotspot/Hotel-WLAN), netbirdio/netbird#4401:
# die /24-Route wird dort nicht installiert bzw. verliert gegen die lokale Route.
# Ersetzt durch lan_targets (siehe unten) — spezifische /32-Routen gewinnen immer
# gegen die breitere /24-Route eines fremden Netzes.
variable "lan_targets" {
  type = map(string)
  default = {
    envoy_lb       = "192.168.0.152/32" # Envoy-Gateway — ALLE VPN-only Apps (grafana/argocd/kibana/...)
    proxmox_msa2   = "192.168.0.50/32"  # msa2proxmox — SSH
    proxmox_nipogi = "192.168.0.57/32"  # nipogi — SSH
    proxmox_pve    = "192.168.0.58/32"  # pve/hpdesk — SSH
  }
  description = "Einzelne Ziel-IPs statt eines /24-Subnets — vermeidet Routing-Konflikt mit fremden Netzen, die selbst 192.168.0.0/24 nutzen. Neue IP dazu = einfach hier ergänzen."
}

variable "dns_domain" {
  type        = string
  default     = "timourhomelab.org"
  description = "Match-Domain für Split-DNS — wird auf die interne Gateway-IP aufgelöst (nur für VPN-Clients)."
}

# split_dns_ip ENTFERNT — Operator macht DNS (Zone k8s.timourhomelab.org)
