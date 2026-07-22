# ─────────────────────────────────────────────────────────────────────────────
# NetBird ZTNA — Infra VPN-only (Phase 2 IaC)
# Kodifiziert was am 2026-06-09 manuell im Dashboard eingerichtet wurde.
# Managed die NetBird-CONTROL-PLANE (Netz/Policy/DNS/Keys), NICHT die Peer-Installs.
# ─────────────────────────────────────────────────────────────────────────────

# ── Groups ───────────────────────────────────────────────────────────────────
resource "netbird_group" "routers" {
  name = "homelab-routers" # Routing-Peers (msa2proxmox, nipogi) landen hier via Setup-Key
}

resource "netbird_group" "users" {
  name = "homelab-users" # Client-Geräte (Laptop, Handle) die aufs LAN dürfen
}

resource "netbird_group" "lan_resource" {
  name = "homelab-lan" # Tag-Gruppe für die LAN-Resource (Policy-Ziel)
}

# ── Network ──────────────────────────────────────────────────────────────────
resource "netbird_network" "homelab" {
  name        = "homelab"
  description = "Homelab LAN — VPN-only Infra-Zugriff (grafana, argocd, kibana, ...)"
}

# ── Resource: das LAN-Subnet ─────────────────────────────────────────────────
resource "netbird_network_resource" "lan" {
  name        = "homelab-lan"
  description = "Heim-LAN — erreicht alle internen Services hinter dem Envoy-Gateway"
  network_id  = netbird_network.homelab.id
  address     = var.lan_cidr
  groups      = [netbird_group.lan_resource.id]
  enabled     = true
}

# ── Router: die Routing-Peers servieren das Netz (HA via peer_groups) ─────────
resource "netbird_network_router" "lan" {
  network_id  = netbird_network.homelab.id
  peer_groups = [netbird_group.routers.id] # msa2 + nipogi → Failover
  masquerade  = true
  metric      = 9999
  enabled     = true
}

# Split-DNS aus tofu ENTFERNT (2026-06-09) — der NetBird-Operator macht jetzt DNS
# (Zone k8s.timourhomelab.org, Records pro exposed Service). Dieses Modul = nur noch LAN-Routing.

# ── Access-Policy: users → LAN-Resource (Least-Privilege) ────────────────────
resource "netbird_policy" "users_to_lan" {
  name        = "homelab-users-to-lan"
  description = "Erlaubt homelab-users den Zugriff auf das LAN-Subnet"
  enabled     = true

  rule {
    name          = "users-to-lan"
    action        = "accept"
    bidirectional = true
    protocol      = "all"
    sources       = [netbird_group.users.id]
    destinations  = [netbird_group.lan_resource.id]
  }
}

# ── Setup-Key: für die Routing-Peers (reusable → mehrere Peers + HA) ──────────
resource "netbird_setup_key" "routers" {
  name        = "homelab-routing-peers"
  type        = "reusable"
  usage_limit = 0 # unlimited
  auto_groups = [netbird_group.routers.id]
}
