output "routing_peer_setup_key" {
  value       = netbird_setup_key.routers.key
  sensitive   = true
  description = "Reusable Setup-Key für die Routing-Peers. Abruf: tofu output -raw routing_peer_setup_key"
}

output "network_id" {
  value       = netbird_network.homelab.id
  description = "NetBird Network ID (homelab)"
}

# split_dns_nameserver_id ENTFERNT — Operator macht DNS
