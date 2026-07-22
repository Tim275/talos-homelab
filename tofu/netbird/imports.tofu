# Einmalige Import-Blocks — bringen die am 2026-06-09 manuell im NetBird-
# Dashboard angelegten Ressourcen unter Terraform-Kontrolle, OHNE sie neu
# zu erstellen. `tofu plan` muss danach 0 Changes zeigen. IDs per NetBird-API
# ermittelt (2026-07-22). Reconciliation-Weg B aus README.md (Import, kein
# Peer-Re-Keying).

import {
  to = netbird_group.routers
  id = "d8k09pafadhs73daptpg"
}

import {
  to = netbird_group.users
  id = "d8k09pbl0ubs73cdok70"
}

import {
  to = netbird_group.lan_resource
  id = "d8k09pbl0ubs73cdok5g"
}

import {
  to = netbird_network.homelab
  id = "d8k09pafadhs73daptn0"
}

import {
  to = netbird_network_resource.lan
  id = "d8k09pafadhs73daptn0/d8k09pafadhs73dapu00"
}

import {
  to = netbird_network_router.lan
  id = "d8k09pafadhs73daptn0/d8k09pafadhs73dapu20"
}

import {
  to = netbird_policy.users_to_lan
  id = "d8k09pafadhs73dapu70"
}

# netbird_setup_key.routers: KEIN Import-Block mehr — durch das expiry_seconds-
# Hardening (2026-07-22) destroy+recreated, State trägt bereits die neue ID
# (Apply lief bereits, kein Re-Import nötig).

import {
  to = netbird_account_settings.hardening
  id = "d8jsbeafadhs73c5f6dg"
}
