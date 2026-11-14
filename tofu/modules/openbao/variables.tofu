variable "unseal" {
  type      = map(string)
  sensitive = true
}

variable "values" {
  type      = map(string)
  sensitive = true
}
