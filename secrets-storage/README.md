# 🔐 Secrets Storage

Dieser Ordner sammelt alle unverschlüsselten Secrets an einem zentralen Ort.

**⚠️ WICHTIG: Dieser Ordner wird ins Git committed! Alle Dateien hier sind sichtbar!**

## Zweck

- **Zentrale Sammlung** aller Secrets für einfache Verwaltung
- **Dokumentation** was welches Secret enthält
- **Templates** für neue Secrets
- **Backup** der wichtigen Credentials

## Struktur

```
secrets-storage/
├── cloudflared-credentials.json       # Cloudflare Tunnel Credentials
├── proxmox-api-config.yaml           # Proxmox API Zugang
├── grafana-admin-password.txt        # Grafana Admin Password
├── minio-credentials.yaml             # S3 Credentials (zukünftig)
└── README.md                          # Diese Dokumentation
```

## Verwendung

### 1. Secret hier speichern
```bash
# Beispiel: Cloudflared Tunnel Credentials
cp ~/.cloudflared/b5f4258e-8cd9-4454-b46e-6f4f34219bb4.json secrets-storage/cloudflared-credentials.json
```

### 2. Mit kubeseal verschlüsseln
```bash
# Verwende das Helper-Script
./seal-secret.sh cloudflared-credentials cloudflared secrets-storage/cloudflared-credentials.json
```

### 3. SealedSecret ins Repository
Das verschlüsselte Secret wird in `kubernetes/infra/*/sealed-*.yaml` gespeichert.

## Sicherheit

✅ **Sicher:**
- Alle Secrets werden mit SealedSecrets verschlüsselt bevor sie deployed werden
- Nur dein Cluster kann die SealedSecrets entschlüsseln
- Repository ist privat

⚠️ **Beachten:**
- Secrets hier sind im Klartext sichtbar für jeden mit Repository-Zugang
- Bei Public Repositories diesen Ordner NIEMALS committen!