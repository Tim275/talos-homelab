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

variable "offsite_storage_account_name" {
  type    = string
  default = "homelaboffsitebackup"
}

variable "offsite_sas_start" {
  type    = string
  default = "2026-11-26T00:00:00Z"
}

variable "offsite_sas_expiry" {
  type    = string
  default = "2027-11-26T00:00:00Z"
}
