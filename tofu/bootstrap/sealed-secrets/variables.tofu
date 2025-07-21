variable "cert" {
  description = "Certificate for encryption/decryption"
  type = object({
    cert = string
    key  = string
  })
}