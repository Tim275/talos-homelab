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
