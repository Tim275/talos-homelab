variable "admin_password" {
  type      = string
  sensitive = true
}

variable "cloudflare_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "insecure" {
  type        = bool
  default     = false
  description = "true nur beim ersten apply, bevor das ACME-Zertifikat da ist"
}
