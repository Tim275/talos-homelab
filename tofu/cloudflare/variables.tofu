variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API-Token (Zone:DNS:Edit + Account:Cloudflare Tunnel:Read). NIE committen → TF_VAR_cloudflare_api_token."
}

variable "zone_id" {
  type        = string
  description = "Cloudflare Zone-ID von timourhomelab.org (Dashboard → Domain → Overview, rechts unten)."
}

variable "zone_name" {
  type        = string
  default     = "timourhomelab.org"
  description = "Die Domain."
}

variable "tunnel_id" {
  type        = string
  default     = "b5f4258e-8cd9-4454-b46e-6f4f34219bb4"
  description = "cloudflared-Tunnel-ID (aus cloudflared/base/config.yaml)."
}

variable "public_hosts" {
  type        = list(string)
  default     = ["drova", "n8n", "iam", "status"]
  description = "NUR diese Subdomains sind public (resolven zum Tunnel). Alles andere (grafana, argocd, ...) = NICHT public → nur via NetBird-VPN."
}

variable "publish_apex" {
  type        = bool
  default     = false
  description = "true wenn timourhomelab.org (apex) auch public sein soll (Landing-Page)."
}
