# tofu/cloudflare — Public-Exposure als Code

Managed die **public DNS-Records** → cloudflared-Tunnel. Eigener State (`cloudflare.tfstate`),
isoliert von Cluster + NetBird.

## Scope (bewusst klein gehalten)
```
✅ DNS-Records:  drova · n8n · iam · status → Tunnel (proxied/WAF)   ← die echte manuelle Lücke
🟢 Allowlist (Tunnel-Ingress)  → bleibt GitOps (cloudflared/base/config.yaml, schon IaC)
⚪ Zero Trust Access           → Scaffold in main.tofu (auskommentiert, optional)
```
**Sicherheits-Plus:** explizite Records statt Wildcard → `grafana.timourhomelab.org` &
Co. resolven **gar nicht mehr public** (NXDOMAIN) — Infra ist via DNS unsichtbar, nur
über NetBird-VPN + Split-DNS erreichbar.

## Voraussetzungen
1. **API-Token:** Cloudflare → My Profile → API Tokens → Create → Permissions:
   `Zone:DNS:Edit` (+ `Account:Cloudflare Tunnel:Read` falls du Access dazunimmst).
2. **Zone-ID:** Dashboard → timourhomelab.org → Overview (rechte Spalte).

## Apply
```bash
cd tofu/cloudflare
export TF_VAR_cloudflare_api_token="xxx"
cp terraform.tfvars.example terraform.tfvars   # zone_id eintragen
tofu init
tofu plan      # erst ansehen!
tofu apply
```

## ⚠️ Reconciliation — bestehende DNS-Records
Wenn schon ein **Wildcard `*.timourhomelab.org`** in Cloudflare existiert (manuell):
1. `tofu apply` legt die 4 **spezifischen** Records an
2. **Wildcard im Dashboard löschen** → dann resolven nur noch die 4 public Hosts
   (sonst resolved der Wildcard weiter alles zum Tunnel)
Bestehende einzelne Records ggf. `tofu import cloudflare_dns_record.public["drova"] <zone>/<record-id>`.

## Zusammenspiel mit dem Rest
```
Cloudflare-tofu (DNS)  →  4 public Hosts resolven public
cloudflared ConfigMap  →  Tunnel-Allowlist (serviert nur die 4, 404 sonst)   [GitOps, Phase 1]
NetBird Split-DNS      →  Infra-Hosts → interner Gateway (nur VPN-Clients)    [tofu/netbird]
```
Drei Layer, jeder sein Tool — sauberes ZTNA.
