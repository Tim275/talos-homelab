output "routing_peer_setup_key" {
  value       = netbird_setup_key.routers.key
  sensitive   = true
  description = "Setup-Key für die Routing-Peers"
}

output "network_id" {
  value       = netbird_network.homelab.id
  description = "NetBird Network ID (homelab)"
}
