# Import-Blocks für manuell im NetBird-Dashboard angelegte Ressourcen — tofu plan muss 0 Changes zeigen

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

# netbird_setup_key.routers: kein Import-Block mehr — State trägt bereits die aktuelle ID

import {
  to = netbird_account_settings.hardening
  id = "d8jsbeafadhs73c5f6dg"
}
