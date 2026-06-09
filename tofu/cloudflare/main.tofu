# ─────────────────────────────────────────────────────────────────────────────
# Cloudflare Public-Exposure als Code
# Managed NUR die public DNS-Records → cloudflared-Tunnel.
# Allowlist (Tunnel-Ingress) bleibt GitOps (cloudflared/base/config.yaml).
# Prinzip: explizite Records statt Wildcard → Infra-Subdomains resolven NICHT public.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  tunnel_cname = "${var.tunnel_id}.cfargotunnel.com"
}

# ── Public Subdomains → Tunnel (proxied) ─────────────────────────────────────
# drova · n8n · iam · status — der Rest existiert hier bewusst NICHT.
resource "cloudflare_dns_record" "public" {
  for_each = toset(var.public_hosts)

  zone_id = var.zone_id
  name    = "${each.value}.${var.zone_name}"
  type    = "CNAME"
  content = local.tunnel_cname
  proxied = true # orange-cloud = WAF/DDoS-Schutz + verbirgt Origin
  ttl     = 1    # 1 = automatic (Pflicht wenn proxied)
  comment = "public via tunnel — managed by tofu/cloudflare"
}

# ── Apex (optional) ──────────────────────────────────────────────────────────
resource "cloudflare_dns_record" "apex" {
  count = var.publish_apex ? 1 : 0

  zone_id = var.zone_id
  name    = var.zone_name
  type    = "CNAME"
  content = local.tunnel_cname
  proxied = true
  ttl     = 1
  comment = "apex via tunnel — managed by tofu/cloudflare"
}

# ── Zero Trust Access (optional, auskommentiert) ─────────────────────────────
# Falls du public Apps zusätzlich mit SSO-Gate schützen willst (statt nur App-Auth):
#
# resource "cloudflare_zero_trust_access_application" "n8n" {
#   account_id = var.account_id
#   name       = "n8n"
#   domain     = "n8n.${var.zone_name}"
#   type       = "self_hosted"
#   session_duration = "24h"
# }
# resource "cloudflare_zero_trust_access_policy" "n8n_allow" {
#   account_id = var.account_id
#   name       = "allow-team"
#   decision   = "allow"
#   include = [{ email_domain = { domain = "outlook.de" } }]
# }
