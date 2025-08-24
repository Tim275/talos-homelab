# Add these to your existing variables.tf file

variable "domain" {
  description = "Primary domain for certificates"
  type        = string
  default     = "timourhomelab.org"
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
  default     = "admin@timourhomelab.org"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS challenges"
  type        = string
  sensitive   = true
}