# Cloudflare Setup Runbook — timourhomelab.org

Cloudflare Free-tier hat **keine** Terraform-managed WAF / Bot-Settings.
Diese Doku ist der **Source-of-Truth** für alle CF-Settings damit ein
Account-Restore/Re-Setup deterministisch ist.

## Anti-Pattern Liste (NIEMALS tun)

```
❌ "Under Attack Mode" PERMANENT aktivieren
   → blockt JEDE non-browser-API (kubectl, renovate, curl, ngrok)
   → 5s "Just a moment..." auch für legit User
   → Battle-tested 2026-05-14: kubectl OIDC DEAD nach UAM-on

   UAM ist ein NOTFALL-setting für DDoS aktiv. Nach DDoS sofort wieder aus.

❌ Bot-Fight-Mode ohne Skip-Rule für iam.*
   → CF ML flagged kubelogin → CF challenge → kubelogin kann's nicht
   → Battle-tested 2026-05-08+: passiert ALLE 2 Wochen bei Traffic-Spikes

❌ Security Level = "High" oder "Under Attack" als default
   → CLI-clients haben keine Chance
   → Empfohlen: "Medium" für public-domains, "Essentially Off" für iam.*
```

## Pflicht-Setup (1× nach Account-create)

### 1) Domain-Settings

```
Cloudflare Dashboard → timourhomelab.org

SSL/TLS:
  Encryption mode: Full (Strict)
  Always Use HTTPS: ON
  Minimum TLS Version: 1.2
  Automatic HTTPS Rewrites: ON
  HSTS: Enable, max-age 6mo (only after testing)

Network:
  HTTP/2: ON
  HTTP/3 (QUIC): ON
  IPv6 Compatibility: ON
  WebSockets: ON
  Onion Routing: OFF
```

### 2) Security — Bot Fight Mode + Skip Rule (PFLICHT)

```
Security → Bots → "Configure Bot Fight Mode"

Bot Fight Mode: ON
  (lightweight ML, schadet weniger als UAM)

CRITICAL: Skip Rule für CLI-clients hinzufügen:
  → "Skip" tab → Add rule
     Name:       skip-bots-iam
     When:       Hostname equals "iam.timourhomelab.org"
     Action:     Skip (no challenge)
  → Deploy
```

### 3) Security — WAF Custom Rules (Block-Liste)

```
Security → WAF → Custom Rules → Create rule

Rule 1: block-attack-patterns
  When:   URI Path matches regex
          (?i)(sql|union|select|drop|<script>|\\.\\./etc/|/passwd|wp-admin|phpmyadmin)
  Then:   Block

Rule 2: block-scanners
  When:   User-Agent contains any:
          sqlmap | nikto | nmap | masscan | zgrab | python-requests | curl/7.0
  Then:   Block

Rule 3: block-empty-useragent
  When:   User-Agent is empty
          AND Hostname is NOT "iam.timourhomelab.org"
  Then:   Block
  (skip iam.* weil kubelogin manchmal leere UA hat)

Rule 4: block-invalid-methods
  When:   Request Method NOT IN (GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD)
  Then:   Block

Rule 5: skip-managed-challenge-iam
  When:   Hostname equals "iam.timourhomelab.org"
          AND (URI Path contains "/.well-known/"
                OR URI Path contains "/protocol/openid-connect/"
                OR URI Path contains "/realms/")
  Then:   Skip
          → All remaining custom rules
          → All managed rules
          → Bot Fight Mode
          → Super Bot Fight Mode
  (CRITICAL: ohne diese Rule blockt CF jedes OIDC discovery)
```

### 4) Security — Rate Limiting (Auth-Endpoints)

```
Security → WAF → Rate Limiting Rules → Create

Rule: rate-limit-auth
  When:   URI Path matches regex
          .*/(login|register|auth|token).*
          AND Hostname matches *.timourhomelab.org
  Action: Block 10s
  Rate:   3 requests per 10s per IP
```

### 5) Configuration Rules — Security Level per Hostname

```
Rules → Configuration Rules → Create rule

Rule 1: iam-low-security
  When:   Hostname equals "iam.timourhomelab.org"
  Then:   Security Level = "Essentially Off"
          Browser Integrity Check = OFF
  Reason: OIDC discovery + kubelogin auth flows brauchen CLI-friendly access

Rule 2: drova-medium
  When:   Hostname equals "drova.timourhomelab.org"
  Then:   Security Level = "Medium"
          Cache Level = "Standard"
  Reason: Customer-facing, kein UAM nötig, normaler protection

Rule 3: internal-tools-high
  When:   Hostname IN (grafana.*, argo.*, jaeger.*, prometheus.*, hubble.*)
  Then:   Security Level = "High"
  Reason: Internal-only, aggressive bot-blocking OK
```

### 6) Tunnels (cloudflared)

```
Zero Trust → Networks → Tunnels

Tunnel: talos-homelab (existing)
  Public Hostnames:
    *.timourhomelab.org → https://envoy-gateway-envoy-gateway-XXX.gateway.svc:443
    status.timourhomelab.org → http://uptime-kuma-service.uptime-kuma.svc:3001
    (Wildcard CNAME catch-all)
  
  TLS Settings:
    Origin Server Name: <wildcard-cert-cn>
    HTTP2 Connection: Enable
    No-TLS-Verify: OFF (Envoy hat valid cert)
```

### 7) Page Rules / Speed (optional)

```
Speed → Optimization:
  Auto Minify (JS/CSS/HTML): ON  (außer iam.* — KC braucht non-minified JS)
  Brotli: ON
  Early Hints: ON
  Rocket Loader: OFF  (bricht oft React-Apps)

Caching:
  Browser Cache TTL: 4 hours (für static)
  Crawler Hints: ON
```

## Test-Procedure nach Setup

```bash
# 1. OIDC discovery erreichbar (kubelogin tut das)
curl -sk https://iam.timourhomelab.org/realms/kubernetes/.well-known/openid-configuration \
  | jq -r '.issuer'
# Expected: https://iam.timourhomelab.org/realms/kubernetes (NICHT "Just a moment...")

# 2. Drova-App erreichbar
curl -sk -o /dev/null -w "Status: %{http_code} | Time: %{time_total}s\n" \
  https://drova.timourhomelab.org/
# Expected: 200/302, time <0.5s

# 3. kubectl OIDC funktional
rm -rf ~/.kube/cache/oidc-login
KUBECONFIG=~/.kube/config-oidc kubectl get nodes
# Expected: Browser-Popup → KC-Login → nodes-list

# 4. Repeat-Test (CF Bot-Fight darf nicht plötzlich blocken)
for i in {1..30}; do
  curl -sk -o /dev/null -w "%{http_code}" \
    https://iam.timourhomelab.org/realms/kubernetes/.well-known/openid-configuration
  echo " #$i"
done
# Expected: 30× "200", kein 403/503
```

## DR — Account-Loss Recovery

```
Wenn Cloudflare-Account gehackt/gelöscht/locked-out:

1. Neuen CF-Account erstellen
2. Domain timourhomelab.org transferieren (registrar → neuen CF account)
3. DNS-records aus Hetzner / lokal-Backup importieren:
   - apex A-record
   - MX records (für Resend SMTP)
   - DKIM TXT (für SMTP)
4. Diese Doku Schritt 1-7 abarbeiten (~30min)
5. Tunnel-Token neu generieren in Zero Trust → Tunnels → Create
6. SealedSecret in Cluster updaten:
     CERT=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt
     kubectl create secret generic cloudflared-token \
       --namespace=cloudflared \
       --from-literal=token="<new-token>" \
       --dry-run=client -o yaml | \
     kubeseal --cert "$CERT" --format yaml --scope strict \
       > kubernetes/infrastructure/network/cloudflared/base/sealed-credentials.yaml
   git push → ArgoCD synct → Tunnel live

RTO total: ~45min wenn Tunnels noch im Cluster definiert sind.
```

## Quartal-Review

```
Q1 2026 Q2: 2026-05-14 (initial setup nach UAM-incident) — Tim
Q2 2026 Q3: schedule 2026-08-15 — verify alle Rules deployed, security-level review
Q3 2026 Q4: schedule 2026-11-15 — block-attack-patterns regex update
Q4 2027 Q1: schedule 2027-02-15 — Renewal CF-API-token wenn benutzt
```

## Was IaC-bar wäre (für später)

```
Cloudflare-Terraform-Provider könnte alle obigen Rules als code definieren.
Aufwand: ~3h Setup + CF-Pro ($20/mo) für vollen API-access.

Solo-Homelab: nicht zwingend, dieses Runbook + manual setup ist OK.
Wenn 2+ Engineers / Compliance-Pflicht: IaC machen.
```
