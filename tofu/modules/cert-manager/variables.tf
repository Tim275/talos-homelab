variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.3"
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for cert-manager"
  type        = bool
  default     = true
}

variable "issuer_name" {
  description = "Name of the ClusterIssuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "issuer_namespace" {
  description = "Namespace for cert-manager resources"
  type        = string
  default     = "cert-manager"
}

variable "gateway_namespace" {
  description = "Namespace for gateway and certificates"
  type        = string
  default     = "gateway"
}

variable "acme_server" {
  description = "ACME server URL"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_email" {
  description = "Email for ACME registration"
  type        = string
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.acme_email))
    error_message = "Must be a valid email address."
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS challenges"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.cloudflare_api_token) > 20
    error_message = "Cloudflare API token must be provided."
  }
}

variable "dns_zones" {
  description = "DNS zones managed by this issuer"
  type        = list(string)
  default     = ["timourhomelab.org"]
}

variable "certificate_name" {
  description = "Name of the wildcard certificate"
  type        = string
  default     = "wildcard-cert"
}

variable "certificate_secret_name" {
  description = "Name of the certificate secret"
  type        = string
  default     = "wildcard-tls"
}

variable "certificate_domains" {
  description = "Domains for the certificate"
  type        = list(string)
  default     = ["timourhomelab.org", "*.timourhomelab.org"]
}