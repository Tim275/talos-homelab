variable "seal" {
  type = object({
    seal_key_path = string
  })
  sensitive = true
}

variable "values" {
  type      = map(string)
  sensitive = true
}

variable "etcd_client_cert" {
  type = object({
    ca   = string
    cert = string
    key  = string
  })
  sensitive = true
}
