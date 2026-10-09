# Groups
resource "netbird_group" "routers" {
  name = "homelab-routers"
}

resource "netbird_group" "users" {
  name = "homelab-users"
}

locals {
  lan_port_sets = toset([for t in var.lan_targets : join(",", t.ports)])
}

resource "netbird_group" "lan" {
  for_each = local.lan_port_sets
  name     = "homelab-lan-${replace(each.key, ",", "-")}"
}

# Network
resource "netbird_network" "homelab" {
  name        = "homelab"
  description = "Homelab LAN"
}

resource "netbird_network_resource" "lan" {
  for_each = var.lan_targets

  name        = "homelab-${each.key}"
  description = "Homelab ${each.key}"
  network_id  = netbird_network.homelab.id
  address     = each.value.address
  groups      = [netbird_group.lan[join(",", each.value.ports)].id]
  enabled     = true
}

resource "netbird_network_router" "lan" {
  network_id  = netbird_network.homelab.id
  peer_groups = [netbird_group.routers.id]
  masquerade  = true
  metric      = 9999
  enabled     = true
}

resource "netbird_account_settings" "hardening" {
  peer_approval_enabled               = true
  peer_login_expiration_enabled       = true
  peer_login_expiration               = 2592000
  peer_inactivity_expiration_enabled  = false
  peer_inactivity_expiration          = 0
  regular_users_view_blocked          = false
  groups_propagation_enabled          = false
  jwt_groups_enabled                  = false
  jwt_groups_claim_name               = ""
  jwt_allow_groups                    = []
  routing_peer_dns_resolution_enabled = false
}

resource "netbird_posture_check" "min_client" {
  name        = "homelab-min-netbird-version"
  description = "NetBird-Client >= 0.72.0"

  netbird_version_check {
    min_version = "0.72.0"
  }
}

# Access-Policy: users → LAN-Resource
resource "netbird_policy" "users_to_lan" {
  for_each = local.lan_port_sets

  name                  = "homelab-users-to-lan-${replace(each.key, ",", "-")}"
  description           = "users → LAN (${each.key})"
  enabled               = true
  source_posture_checks = [netbird_posture_check.min_client.id]

  rule {
    name          = "users-to-lan-${replace(each.key, ",", "-")}"
    action        = "accept"
    bidirectional = false
    protocol      = "tcp"
    ports         = split(",", each.key)
    sources       = [netbird_group.users.id]
    destinations  = [netbird_group.lan[each.key].id]
  }
}

moved {
  from = netbird_policy.users_to_lan
  to   = netbird_policy.users_to_lan["80,443"]
}

# Access-Policy: users → Routing-Peers selbst
resource "netbird_policy" "users_to_routers" {
  name                  = "homelab-users-to-routers"
  description           = "users → Routing-Peers"
  enabled               = true
  source_posture_checks = [netbird_posture_check.min_client.id]

  rule {
    name          = "users-to-routers"
    action        = "accept"
    bidirectional = false
    protocol      = "tcp"
    ports         = ["22", "8006"]
    sources       = [netbird_group.users.id]
    destinations  = [netbird_group.routers.id]
  }
}
