variable "harbor_url" {
  type        = string
  default     = "https://harbor.timourhomelab.org"
  description = "Harbor-URL"
}

variable "harbor_username" {
  type        = string
  default     = "admin"
  description = "Admin-Benutzer"
}

variable "harbor_password" {
  type        = string
  sensitive   = true
  description = "Admin-Passwort"
}
