variable "resource_group_name" {
  type    = string
  default = "rg-openbao-unseal"
}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique, 3-24 chars"
  default     = "kv-homelab-unseal"
}
