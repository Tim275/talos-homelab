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
