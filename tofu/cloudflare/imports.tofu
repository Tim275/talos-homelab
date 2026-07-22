# Einmalige Import-Blocks — bringen bestehende, manuell angelegte Cloudflare-
# Ressourcen unter Terraform-Kontrolle, OHNE sie neu zu erstellen. `tofu plan`
# muss danach 0 Changes zeigen (reiner State-Import, keine Live-Änderung).
# IDs per Cloudflare-API ermittelt (2026-07-22).

import {
  to = cloudflare_dns_record.public["drova"]
  id = "${var.zone_id}/84e707913df89622b5844c8a4d8d8e91"
}

import {
  to = cloudflare_dns_record.public["n8n"]
  id = "${var.zone_id}/12c539761a50f86685a21087b026d7c2"
}

import {
  to = cloudflare_dns_record.apex[0]
  id = "${var.zone_id}/dc74853794e05a8cc8aff4b46bd985fc"
}

import {
  to = cloudflare_dns_record.wildcard_internal
  id = "${var.zone_id}/81e58abfe8f7b2e2925e323ea71af561"
}
