# WireGuard Tunnel Setup - DSGVO-konform mit Hetzner + Gateway API

**Ziel:** Services über verschlüsselten WireGuard Tunnel ohne offene Ports im Homelab exponieren.

## Architektur

```
Internet User
  ↓
Hetzner VPS (Public IP) 🇩🇪
  ├─ nginx (Port 80/443) - HTTPS Entry Point
  ├─ Let's Encrypt SSL
  └─ WireGuard Server (Port 51820/udp)
      ↓ Encrypted Tunnel (10.0.0.1 ↔ 10.0.0.2)
      ↓
Homelab Kubernetes Cluster
  ├─ WireGuard Client (ONLY outbound connection!)
  ├─ Gateway API (Envoy Gateway)
  │   ├─ HTTPRoute: n8n.timourhomelab.org → n8n Service
  │   ├─ HTTPRoute: grafana.timourhomelab.org → Grafana Service
  │   └─ HTTPRoute: *.timourhomelab.org → Services
  └─ Services (n8n, Grafana, ArgoCD, etc.)
```

## Security Benefits

✅ **KEINE offenen Ports im Homelab** (außer WireGuard ausgehend)
✅ **Verschlüsselter Tunnel** (ChaCha20-Poly1305)
✅ **DSGVO-konform** (Hetzner = Deutschland)
✅ **Gateway API** funktioniert unverändert
✅ **DDoS Protection** durch Hetzner

---

## Phase 1: Hetzner VPS Setup

### 1.1 Hetzner Cloud VPS erstellen

```bash
# Hetzner Cloud Console: https://console.hetzner.cloud
# Server erstellen:
# - Type: CX22 (4 vCPU, 8GB RAM) - €5.83/Monat
# - Image: Ubuntu 24.04
# - Datacenter: Falkenstein (Deutschland)
# - SSH Key hinzufügen
```

### 1.2 SSH Verbinden

```bash
# Public IP vom VPS kopieren
export HETZNER_IP="<HETZNER_PUBLIC_IP>"

# SSH verbinden
ssh root@$HETZNER_IP
```

### 1.3 System Update

```bash
apt update && apt upgrade -y
apt install wireguard nginx certbot python3-certbot-nginx ufw -y
```

---

## Phase 2: WireGuard Server auf Hetzner

### 2.1 WireGuard Keys generieren

```bash
cd /etc/wireguard

# Server Keys
wg genkey | tee server_private.key | wg pubkey > server_public.key

# Client Keys (für Homelab)
wg genkey | tee homelab_private.key | wg pubkey > homelab_public.key

# Permissions
chmod 600 server_private.key homelab_private.key
```

### 2.2 WireGuard Server Config

```bash
# /etc/wireguard/wg0.conf erstellen
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat server_private.key)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Homelab Peer
[Peer]
PublicKey = $(cat homelab_public.key)
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
EOF
```

### 2.3 IP Forwarding aktivieren

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### 2.4 WireGuard starten

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Status prüfen
systemctl status wg-quick@wg0
wg show
```

### 2.5 Firewall konfigurieren

```bash
# UFW aktivieren
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 51820/udp # WireGuard
ufw enable

# Status
ufw status
```

---

## Phase 3: nginx Reverse Proxy

### 3.1 nginx Konfiguration

```bash
cat > /etc/nginx/sites-available/homelab <<'EOF'
upstream homelab_gateway {
    server 10.0.0.2:80;  # Gateway API über WireGuard Tunnel
    keepalive 32;
}

# HTTP → HTTPS Redirect
server {
    listen 80;
    server_name *.timourhomelab.org timourhomelab.org;

    location / {
        return 301 https://$host$request_uri;
    }

    # Let's Encrypt ACME Challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name *.timourhomelab.org timourhomelab.org;

    # SSL Zertifikate (werden von Certbot automatisch hinzugefügt)
    # ssl_certificate /etc/letsencrypt/live/timourhomelab.org/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/timourhomelab.org/privkey.pem;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Proxy zu Homelab Gateway API
    location / {
        proxy_pass http://homelab_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket Support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# nginx Config aktivieren
ln -s /etc/nginx/sites-available/homelab /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Config testen
nginx -t

# nginx neu laden
systemctl reload nginx
```

### 3.2 SSL Zertifikat mit Let's Encrypt

```bash
# Wildcard Zertifikat (DNS Challenge - Cloudflare)
# ODER einzelne Zertifikate:

# Für Wildcard (empfohlen):
# Cloudflare API Token benötigt: https://dash.cloudflare.com/profile/api-tokens

# Für einzelne Domains:
certbot --nginx -d timourhomelab.org -d n8n.timourhomelab.org -d grafana.timourhomelab.org

# Auto-Renewal testen
certbot renew --dry-run
```

---

## Phase 4: Homelab WireGuard Client

### 4.1 WireGuard auf Kubernetes Node installieren

**Option A: Talos Linux (dein Setup)**

```bash
# WireGuard Extension ist bereits in Talos enthalten!
# Config via Talos Config:

# machineconfig-patch.yaml
machine:
  network:
    wireguard:
      - name: wg0
        privateKey: <HOMELAB_PRIVATE_KEY>
        listenPort: 51820
        peers:
          - publicKey: <HETZNER_SERVER_PUBLIC_KEY>
            endpoint: <HETZNER_IP>:51820
            allowedIPs:
              - 10.0.0.0/24
            persistentKeepaliveInterval: 25s
        addresses:
          - 10.0.0.2/24

# Anwenden:
talosctl -n <NODE_IP> patch machineconfig --patch @machineconfig-patch.yaml
```

**Option B: Kubernetes DaemonSet (Alternative)**

```yaml
# wireguard-client-daemonset.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wireguard

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: wireguard-config
  namespace: wireguard
data:
  wg0.conf: |
    [Interface]
    Address = 10.0.0.2/24
    PrivateKey = <HOMELAB_PRIVATE_KEY>

    [Peer]
    PublicKey = <HETZNER_SERVER_PUBLIC_KEY>
    Endpoint = <HETZNER_IP>:51820
    AllowedIPs = 10.0.0.0/24
    PersistentKeepalive = 25

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: wireguard-client
  namespace: wireguard
spec:
  selector:
    matchLabels:
      app: wireguard
  template:
    metadata:
      labels:
        app: wireguard
    spec:
      hostNetwork: true
      containers:
      - name: wireguard
        image: linuxserver/wireguard:latest
        securityContext:
          capabilities:
            add:
              - NET_ADMIN
              - SYS_MODULE
          privileged: true
        volumeMounts:
        - name: config
          mountPath: /config/wg0.conf
          subPath: wg0.conf
        - name: lib-modules
          mountPath: /lib/modules
      volumes:
      - name: config
        configMap:
          name: wireguard-config
      - name: lib-modules
        hostPath:
          path: /lib/modules
```

```bash
kubectl apply -f wireguard-client-daemonset.yaml
```

### 4.2 Verbindung testen

```bash
# Von Hetzner VPS:
ping 10.0.0.2

# Von Homelab Node:
ping 10.0.0.1

# Beide sollten erfolgreich sein!
```

---

## Phase 5: Gateway API Konfiguration

### 5.1 Gateway für WireGuard Tunnel

**Gateway Service auf 10.0.0.2:80 lauschen lassen:**

```yaml
# gateway-tunnel-config.yaml
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway-tunnel
  namespace: envoy-gateway-system
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.2  # MetalLB IP im WireGuard Netzwerk
  ports:
  - port: 80
    targetPort: 8080
    name: http
  selector:
    gateway.envoyproxy.io/owning-gateway-name: homelab-gateway
```

**ODER: Cilium L2 Announcement:**

```yaml
# cilium-l2-wireguard.yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: wireguard-pool
spec:
  blocks:
    - start: 10.0.0.2
      stop: 10.0.0.2
```

### 5.2 HTTPRoute Beispiele

```yaml
# n8n-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: n8n-route
  namespace: n8n-prod
spec:
  parentRefs:
    - name: homelab-gateway
      namespace: envoy-gateway-system
  hostnames:
    - "n8n.timourhomelab.org"
  rules:
    - backendRefs:
        - name: n8n
          port: 80

---
# grafana-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: grafana
spec:
  parentRefs:
    - name: homelab-gateway
      namespace: envoy-gateway-system
  hostnames:
    - "grafana.timourhomelab.org"
  rules:
    - backendRefs:
        - name: grafana
          port: 3000
```

```bash
kubectl apply -f n8n-route.yaml
kubectl apply -f grafana-route.yaml
```

---

## Phase 6: DNS Konfiguration

### 6.1 DNS Records auf Hetzner VPS IP zeigen

```
# Cloudflare DNS (oder dein Provider):
Type    Name                    Content
A       timourhomelab.org       <HETZNER_IP>
CNAME   *.timourhomelab.org     timourhomelab.org

# WICHTIG: DNS Proxy OFF (Cloudflare = grau, nicht orange!)
```

---

## Phase 7: Testing

### 7.1 WireGuard Tunnel Test

```bash
# Auf Hetzner VPS:
wg show
# Sollte "latest handshake" zeigen

ping 10.0.0.2
# Sollte funktionieren
```

### 7.2 nginx → Gateway API Test

```bash
# Auf Hetzner VPS:
curl -H "Host: n8n.timourhomelab.org" http://10.0.0.2

# Sollte n8n Response zurückgeben
```

### 7.3 End-to-End Test

```bash
# Von extern (dein Laptop, anderes Netzwerk):
curl https://n8n.timourhomelab.org

# Sollte n8n Login Page zeigen!
```

### 7.4 Alle Services testen

```bash
# Browser:
https://n8n.timourhomelab.org
https://grafana.timourhomelab.org
https://argocd.timourhomelab.org
```

---

## Troubleshooting

### Problem: WireGuard Tunnel nicht verbunden

```bash
# Hetzner VPS:
systemctl status wg-quick@wg0
journalctl -u wg-quick@wg0 -f

# Homelab:
kubectl logs -n wireguard -l app=wireguard
```

### Problem: nginx kann Gateway nicht erreichen

```bash
# Auf Hetzner VPS:
ping 10.0.0.2
curl http://10.0.0.2

# Gateway IP prüfen:
kubectl get svc -n envoy-gateway-system
```

### Problem: SSL Zertifikat Fehler

```bash
# Certbot Logs:
certbot certificates
journalctl -u certbot
```

### Problem: HTTPRoute funktioniert nicht

```bash
# HTTPRoute Status:
kubectl get httproute -A
kubectl describe httproute n8n-route -n n8n-prod

# Gateway Status:
kubectl get gateway -A
```

---

## Monitoring

### WireGuard Metrics

```bash
# Hetzner VPS:
wg show wg0 dump

# Prometheus Metrics (optional):
# https://github.com/MindFlavor/prometheus_wireguard_exporter
```

### nginx Logs

```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

---

## Kosten

| Service | Anbieter | Kosten/Monat |
|---------|----------|--------------|
| Hetzner CX22 VPS | Hetzner 🇩🇪 | €5.83 |
| WireGuard | Open Source | €0.00 |
| nginx | Open Source | €0.00 |
| Let's Encrypt | Kostenlos | €0.00 |
| **TOTAL** | | **€5.83** |

---

## Security Checklist

- [ ] WireGuard Keys sicher gespeichert
- [ ] UFW Firewall aktiviert (nur 22, 80, 443, 51820)
- [ ] SSH Key-based auth (kein Password!)
- [ ] SSL/TLS Zertifikate aktiv
- [ ] Nur WireGuard Port 51820 im Homelab (ausgehend!)
- [ ] nginx security headers aktiviert
- [ ] Fail2ban installiert (optional)
- [ ] Regelmäßige Updates (apt update && apt upgrade)

---

## Next Steps (Optional)

### 1. Monitoring hinzufügen
- Prometheus WireGuard Exporter
- nginx Prometheus Exporter
- Grafana Dashboard

### 2. High Availability
- Zweiter Hetzner VPS
- WireGuard Multi-Peer Setup
- nginx Load Balancing

### 3. Backup
- WireGuard Configs sichern
- nginx Configs in Git
- Automatisches Backup Script

---

## Referenzen

- WireGuard Official: https://www.wireguard.com/
- Hetzner Docs: https://docs.hetzner.com/
- Gateway API: https://gateway-api.sigs.k8s.io/
- nginx Docs: https://nginx.org/en/docs/
- Let's Encrypt: https://letsencrypt.org/

---

**Status:** 📝 Draft - Ready for Implementation Tomorrow!
**DSGVO-konform:** ✅ 100% EU (Hetzner Deutschland)
**Kosten:** €5.83/Monat
