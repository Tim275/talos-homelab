# ACME-Konto "default" legt `mise run pve-acme` an, die API erlaubt das nur root@pam
resource "proxmox_acme_dns_plugin" "cloudflare" {
  plugin = "cloudflare"
  api    = "cf"
  data_wo = {
    CF_Token   = var.cloudflare_token
    CF_Zone_ID = "657020c127a01375590ba87f8ed61a52"
  }
  data_wo_version = 1
}

resource "proxmox_acme_certificate" "this" {
  for_each = toset(["msa2proxmox", "nipogi", "aoostar"])

  node_name = each.key
  account   = "default"
  domains = [{
    domain = "${each.key}.timourhomelab.org"
    plugin = proxmox_acme_dns_plugin.cloudflare.plugin
  }]
}
