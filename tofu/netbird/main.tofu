# NetBird ZTNA Control-Plane (Netz/Policy/DNS/Keys) — nicht die Peer-Installs

# Groups
resource "netbird_group" "routers" {
  name = "homelab-routers" # Routing-Peers (msa2proxmox, nipogi) landen hier via Setup-Key
}

resource "netbird_group" "users" {
  name = "homelab-users" # Client-Geräte (Laptop, Handy) die aufs LAN dürfen
}

resource "netbird_group" "lan_resource" {
  name = "homelab-lan" # Tag-Gruppe für die LAN-Resource (Policy-Ziel)
}

# Network
resource "netbird_network" "homelab" {
  name        = "homelab"
  description = "Homelab LAN — VPN-only Infra-Zugriff (grafana, argocd, kibana, ...)"
}

resource "netbird_network_resource" "lan" {
  name        = "homelab-lan"
  description = "Heim-LAN — erreicht alle internen Services hinter dem Envoy-Gateway"
  network_id  = netbird_network.homelab.id
  address     = var.lan_cidr
  groups      = [netbird_group.lan_resource.id]
  enabled     = true
}

resource "netbird_network_router" "lan" {
  network_id  = netbird_network.homelab.id
  peer_groups = [netbird_group.routers.id] # msa2 + nipogi → Failover
  masquerade  = true
  metric      = 9999
  enabled     = true
}

# DNS macht der NetBird-Operator (Zone k8s.timourhomelab.org) — dieses Modul nur LAN-Routing

# Account-Settings: Zero-Trust-Hardening
resource "netbird_account_settings" "hardening" {
  peer_approval_enabled         = true # neue Peers brauchen manuelle Freigabe
  peer_login_expiration_enabled = true # User-Peers re-authen alle 30d
  peer_login_expiration         = 2592000
  # Rest unverändert gelassen (Live-Defaults)
  peer_inactivity_expiration_enabled  = false
  peer_inactivity_expiration          = 0
  regular_users_view_blocked          = false
  groups_propagation_enabled          = false
  jwt_groups_enabled                  = false
  jwt_groups_claim_name               = ""
  jwt_allow_groups                    = []
  routing_peer_dns_resolution_enabled = false
}

# Device-Posture: Mindest-Client-Version, bevor ein User-Gerät aufs LAN darf
resource "netbird_posture_check" "min_client" {
  name        = "homelab-min-netbird-version"
  description = "User-Geräte müssen NetBird-Client >= 0.72.0 fahren (Device-Health)"

  netbird_version_check {
    min_version = "0.72.0"
  }
}

# Access-Policy: users → LAN-Resource
resource "netbird_policy" "users_to_lan" {
  name                  = "homelab-users-to-lan"
  description           = "Erlaubt homelab-users den Zugriff auf das LAN-Subnet"
  enabled               = true
  source_posture_checks = [netbird_posture_check.min_client.id]

  rule {
    name          = "users-to-lan"
    action        = "accept"
    bidirectional = true
    # tcp statt all — Apps laufen über Envoy-Gateway (443), Rest ungenutzt
    protocol     = "tcp"
    sources      = [netbird_group.users.id]
    destinations = [netbird_group.lan_resource.id]
  }
}

# Setup-Key für die Routing-Peers (reusable → mehrere Peers + HA)
resource "netbird_setup_key" "routers" {
  name        = "homelab-routing-peers"
  type        = "reusable"
  usage_limit = 0 # unlimited
  auto_groups = [netbird_group.routers.id]
  # Key läuft ab, verbundene Peers bleiben unberührt — nur neue Verbindungsversuche betroffen
  expiry_seconds = 7776000 # 90 Tage
}
