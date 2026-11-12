output "public_fqdns" {
  value       = [for h in var.public_hosts : "${h}.${var.zone_name}"]
  description = "public Hostnames"
}

output "tunnel_cname" {
  value       = local.tunnel_cname
  description = "Tunnel-CNAME"
}
