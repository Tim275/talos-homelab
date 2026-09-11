output "status_page_url" {
  value       = "${var.uptime_kuma_url}/status/${uptimekuma_status_page.homelab.slug}"
  description = "Für das Homepage-Widget (type: uptime-kuma, slug: homelab)."
}

output "monitor_count" {
  value = length(uptimekuma_monitor_http.app) + 2
}
