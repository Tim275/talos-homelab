output "public_fqdns" {
  value       = [for h in var.public_hosts : "${h}.${var.zone_name}"]
  description = "Die einzigen public Hostnames (resolven zum Tunnel)."
}

output "tunnel_cname" {
  value       = local.tunnel_cname
  description = "Tunnel-CNAME-Ziel, auf das die public Records zeigen."
}
