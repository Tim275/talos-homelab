variable "seal" {
  type = object({
    seal_key_path = string
  })
  sensitive = true
}

variable "values" {
  type = object({
    dir = string
  })
}
