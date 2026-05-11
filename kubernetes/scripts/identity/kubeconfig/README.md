# OIDC-kubeconfig für Mitarbeiter

Diese kubeconfig ist **für ALLE Mitarbeiter gleich**. User-Identity kommt
zur Laufzeit über KC-Login mit individuellem Pass + 2FA.

## Setup für neuen Mitarbeiter (3 Schritte, ~2min)

### 1. kubelogin installieren (1× one-time)

```bash
# macOS
brew install int128/kubelogin/kubelogin

# Linux
KUBELOGIN_VERSION=v1.34.0
curl -OL "https://github.com/int128/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin_linux_amd64.zip"
unzip kubelogin_linux_amd64.zip
sudo install -m 755 kubelogin /usr/local/bin/kubectl-oidc_login
```

### 2. kubeconfig-File platzieren

```bash
cp scripts/identity/kubeconfig/kubeconfig-oidc.yaml ~/.kube/config-oidc
chmod 600 ~/.kube/config-oidc
```

### 3. VPN-Verbindung herstellen

Ohne VPN: kein Cluster-Zugriff (kube-apiserver nicht public exposed).

```bash
# Option A: Tailscale (empfohlen für DevOps-Engineers)
tailscale up

# Option B: NetBird (wenn intern self-hosted gewünscht)
netbird up --management-url https://netbird.timourhomelab.org
```

## Verwendung

```bash
# Default-Context auf OIDC setzen (eine Session)
export KUBECONFIG=~/.kube/config-oidc

# Erste kubectl-Action triggert Login
kubectl get pods -n drova
# → Browser öffnet sich
# → KC-Login: dein-username + dein-pass + 2FA
# → Token cached in ~/.kube/cache/oidc-login/
# → kubectl zeigt was DEINE Group erlaubt

# Folge-Calls (innerhalb 1h Token-Gültigkeit) ohne Browser:
kubectl logs <pod> -n drova
kubectl exec -it <pod> -n drova -- bash

# Wer bin ich:
kubectl auth whoami
# Username: oidc:anna
# Groups: [oidc-grp:drova-admins, oidc-grp:argocd-admins, system:authenticated]

# Was darf ich:
kubectl auth can-i get pods -n drova    # → yes
kubectl auth can-i get pods -n n8n      # → no
kubectl auth can-i get nodes            # → no
```

## Permissions je Group

| LLDAP-Group | kubectl-Permissions |
|---|---|
| `cluster-admins` | alles, alle namespaces |
| `drova-admins` | alles in drova-NS |
| `drova-developers` | read+sync drova-apps via ArgoCD (kein direct kubectl) |
| `viewers` | nur read über ArgoCD/Grafana, kein kubectl |
| `developers` | ArgoCD Apps, kein direct kubectl |

## Troubleshooting

### "Forbidden: User can't get pods in namespace X"
→ Du bist in falscher Group. Check: `kubectl auth whoami` zeigt deine Groups.
→ Admin muss dich in LLDAP zur richtigen Group adden.

### "Browser öffnet sich nicht / kein Token"
→ kubelogin nicht installiert: `which kubelogin`
→ Browser-Default-Browser lassen (kein Cmd+K)

### "TLS Cert validation failed"
→ kubeconfig hat `insecure-skip-tls-verify: true` (Solo-Homelab Pattern)
→ Production: stattdessen `certificate-authority-data: <CA-base64>`

### "connect: connection refused" zu API-Server
→ VPN nicht aktiv. Tailscale/NetBird-Connect prüfen.
→ Test: `ping 192.168.0.100` muss gehen
