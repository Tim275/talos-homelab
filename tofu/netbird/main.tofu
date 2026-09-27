# Groups
resource "netbird_group" "routers" {
  name = "homelab-routers"
}

resource "netbird_group" "users" {
  name = "homelab-users"
}

resource "netbird_group" "lan_resource" {
  name = "homelab-lan"
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
  address     = each.value
  groups      = [netbird_group.lan_resource.id]
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
  name                  = "homelab-users-to-lan"
  description           = "users → LAN"
  enabled               = true
  source_posture_checks = [netbird_posture_check.min_client.id]

  rule {
    name          = "users-to-lan"
    action        = "accept"
    bidirectional = true
    protocol      = "tcp"
    sources       = [netbird_group.users.id]
    destinations  = [netbird_group.lan_resource.id]
  }
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

resource "netbird_setup_key" "routers" {
  name           = "homelab-routing-peers"
  type           = "reusable"
  usage_limit    = 0 # unlimited
  auto_groups    = [netbird_group.routers.id]
  expiry_seconds = 7776000 # 90 Tage
}
