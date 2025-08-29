# Renovate Configuration Guide 🤖

## Wie man eine perfekte `renovate.json` für Kubernetes Homelab erstellt

### 🎯 Ziel: Alle Dependencies als Pull Requests tracken

---

## 📋 Grundkonfiguration

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":rebaseStalePrs",
    ":dependencyDashboard", 
    ":semanticCommits"
  ],
  "dependencyDashboard": true,
  "dependencyDashboardTitle": "Renovate Dashboard 🤖"
}
```

### ❌ Was NICHT hinzufügen:
- `"automerge": true` → Erstellt nur Branches, keine PRs
- `":automergeDigest"` → Auto-merges Docker digests
- `"prCreation": "immediate"` → Unnötig bei Standard-Config

### ✅ Warum das funktioniert:
- `config:recommended` = **Standard Pull Requests**
- **Ohne** auto-merge Presets = **Alle Updates werden PRs**

---

## 🔍 File Matchers

```json
"terraform": {
  "fileMatch": [
    "\\.tf$",
    "\\.tofu$"  
  ]
},
"kubernetes": {
  "fileMatch": [
    "kubernetes/.+\\.yaml$",
    "kubernetes/.+\\.yml$"
  ]
},
"kustomize": {
  "fileMatch": [
    "(^|/)kustomization\\.ya?ml(\\.j2)?$"
  ]
}
```

---

## 🛠️ Custom Managers für spezielle Dependencies

### 1. Talos Linux Versionen
```json
{
  "customType": "regex",
  "description": "Update Talos versions in .tofu files",
  "fileMatch": [
    "\\.tofu$",
    "\\.tftpl$"
  ],
  "matchStrings": [
    "version\\s*=\\s*\"v?(?<currentValue>[0-9]+\\.[0-9]+\\.[0-9]+)\"[^\\n]*#.*talos"
  ],
  "datasourceTemplate": "github-releases",
  "depNameTemplate": "siderolabs/talos",
  "versioningTemplate": "semver"
}
```

### 2. Kubernetes Versionen
```json
{
  "customType": "regex", 
  "description": "Update Kubernetes versions in .tofu files",
  "fileMatch": [
    "\\.tofu$",
    "\\.tftpl$"
  ],
  "matchStrings": [
    "kubernetes_version\\s*=\\s*\"v?(?<currentValue>[0-9]+\\.[0-9]+\\.[0-9]+)\""
  ],
  "datasourceTemplate": "github-releases",
  "depNameTemplate": "kubernetes/kubernetes",
  "versioningTemplate": "semver"
}
```

### 3. Container Images
```json
{
  "customType": "regex",
  "description": "Update container images in Talos machine configs", 
  "fileMatch": [
    "\\.tftpl$",
    "\\.yaml$"
  ],
  "matchStrings": [
    "image:\\s*(?<depName>[^\\s:]+):(?<currentValue>[^\\s]+)"
  ],
  "datasourceTemplate": "docker"
}
```

### 4. Helm Charts mit Renovate Comments
```json
{
  "customType": "regex",
  "description": "Update Helm chart versions with renovate comments",
  "fileMatch": [
    "kustomization\\.ya?ml$"
  ],
  "matchStrings": [
    "version:\\s*(?<currentValue>[0-9]+\\.[0-9]+\\.[0-9]+)[^\\n]*#\\s*renovate:\\s*github-releases=(?<depName>[^\\s]+)"
  ],
  "datasourceTemplate": "github-releases", 
  "versioningTemplate": "semver"
}
```

**In kustomization.yaml dann:**
```yaml
helmCharts:
  - name: cilium
    repo: https://helm.cilium.io
    version: 1.17.6 # renovate: github-releases=cilium/cilium
```

---

## 📦 Package Rules - Dependency Grouping

### Logische Gruppierungen erstellen:

```json
"packageRules": [
  {
    "groupName": "Talos System",
    "matchPackageNames": [
      "siderolabs/talos",
      "siderolabs/**"
    ]
  },
  {
    "groupName": "Monitoring Stack",
    "matchPackageNames": [
      "prometheus-community/**",
      "grafana/**", 
      "**/loki**",
      "**/promtail**",
      "**/jaeger**",
      "**/opentelemetry**"
    ]
  },
  {
    "groupName": "Storage & Backup", 
    "matchPackageNames": [
      "**/longhorn**",
      "**/rook**",
      "**/ceph**",
      "**/velero**",
      "**/minio**"
    ]
  }
]
```

---

## 🚨 Häufige Fehler vermeiden

### ❌ Problem: Nur Branches, keine PRs
```json
// FALSCH:
"automerge": true,
"automergeType": "branch"
```

### ✅ Lösung: Standard PR-Verhalten
```json
// RICHTIG: 
// Einfach weglassen - Standard ist PR-Erstellung
```

---

### ❌ Problem: Manche Dependencies werden nicht gefunden
```json
// FALSCH - zu spezifisch:
"matchPackageNames": ["/cilium/"]
```

### ✅ Lösung: Flexible Pattern nutzen
```json
// RICHTIG:
"matchPackageNames": [
  "cilium/**",
  "**/cilium**"
]
```

---

## 🔧 GitHub Repository Settings

1. **Repository Settings** → **Code security and analysis**
2. **Dependency graph**: ✅ Enable
3. **Renovate**: **Automated PRs** (nicht Silent mode!)

---

## 📊 Dependency Dashboard nutzen

Das Dashboard zeigt:
- ✅ **Open PRs**: Aktive Updates
- ⏳ **Pending**: Wartende Updates  
- ❌ **Error**: Fehlgeschlagene Updates
- 📋 **Dependencies**: Alle erkannten Dependencies

---

## ✨ Best Practices

### 1. Startpunkt: Minimale Config
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json", 
  "extends": ["config:recommended", ":dependencyDashboard"]
}
```

### 2. Schrittweise erweitern
- Erst Standard-Dependencies testen
- Dann Custom Managers hinzufügen
- Package Rules für Gruppierung

### 3. Testing
- Renovate Dashboard checken
- Logs in GitHub Actions ansehen
- Bei Fehlern: Config anpassen

### 4. File Structure beachten
```
your-repo/
├── renovate.json          # Hauptkonfiguration
├── tofu/                  # .tofu files → Terraform manager
├── kubernetes/            # .yaml files → Kubernetes manager  
│   └── kustomization.yaml # → Kustomize manager
└── .github/workflows/     # → GitHub Actions manager
```

---

## 🎯 Ergebnis

Mit dieser Konfiguration bekommst du **Pull Requests für**:
- ✅ Talos Linux Updates
- ✅ Kubernetes Updates
- ✅ Alle Container Images
- ✅ Helm Charts
- ✅ Terraform/OpenTofu Provider
- ✅ GitHub Actions
- ✅ Alle anderen Standard-Dependencies

**Keine Branches ohne PRs mehr!** 🎉