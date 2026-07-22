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

# ── Account-Settings: Zero-Trust-Hardening (2026-07-22) ───────────────────────
# "continuously authenticating" (NIST SP 800-207) — peer_approval + periodische
# Re-Auth statt einmal verbinden und für immer vertrauen.
resource "netbird_account_settings" "hardening" {
  peer_approval_enabled         = true # neue Peers brauchen manuelle Freigabe
  peer_login_expiration_enabled = true # User-Peers re-authen alle 24h
  peer_login_expiration         = 86400
  # unverändert gelassen (Live-Defaults, keine Absicht dahinter zu ändern):
  peer_inactivity_expiration_enabled  = false
  peer_inactivity_expiration          = 0
  regular_users_view_blocked          = false
  groups_propagation_enabled          = false
  jwt_groups_enabled                  = false
  jwt_groups_claim_name               = ""
  jwt_allow_groups                    = []
  routing_peer_dns_resolution_enabled = false
}

# ── Access-Policy: users → LAN-Resource (Least-Privilege) ────────────────────
resource "netbird_policy" "users_to_lan" {
  name        = "homelab-users-to-lan"
  description = "Erlaubt homelab-users den Zugriff auf das LAN-Subnet"
  enabled     = true

  rule {
    name          = "users-to-lan"
    action        = "accept"
    bidirectional = true
    # tcp statt all (Hardening 2026-07-22): entfernt ungeprüften ICMP/UDP-Raw-Zugriff.
    # Alle Homelab-Apps laufen über Envoy-Gateway (TCP/443) — bleibt voll funktionsfähig.
    # Port-Scope (nur 443/22 etc.) bewusst NICHT verengt — fehlende Traffic-Telemetrie,
    # Risiko ungeprüft etwas zu sperren > Nutzen; Folge-Schritt für einen ruhigen Tag.
    protocol     = "tcp"
    sources      = [netbird_group.users.id]
    destinations = [netbird_group.lan_resource.id]
  }
}

# ── Setup-Key: für die Routing-Peers (reusable → mehrere Peers + HA) ──────────
resource "netbird_setup_key" "routers" {
  name        = "homelab-routing-peers"
  type        = "reusable"
  usage_limit = 0 # unlimited
  auto_groups = [netbird_group.routers.id]
  # Ablauf 2026-07-22 hinzugefügt (Hardening): Key selbst läuft ab, bereits
  # verbundene Peers (msa2/nipogi) bleiben unberührt — Ablauf wirkt nur auf
  # NEUE Verbindungsversuche mit dem Key (NetBird-Doku bestätigt).
  expiry_seconds = 7776000 # 90 Tage
}
