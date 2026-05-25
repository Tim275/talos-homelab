variable "resource_group_name" {
  type    = string
  default = "rg-tofu-state"
}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

variable "storage_account_name" {
  type        = string
  description = "Must be globally unique, 3-24 chars, lowercase letters and numbers only"
  default     = "tofustatehomelab"
}
