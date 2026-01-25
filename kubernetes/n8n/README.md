# n8n GitHub Renovate Auto-Updater

AI-powered workflow that automatically analyzes and merges Renovate PRs.

Based on [Mischa van den Burg's](https://github.com/mischavandenburg) workflow.

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Schedule   │     │   GitHub    │     │   Claude    │     │  Telegram   │
│  (weekly)   │────►│  API PRs    │────►│  AI Analyze │────►│  Notify     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │ Auto-Merge  │
                                        │ (if safe)   │
                                        └─────────────┘
```

## Enterprise Renovate Integration

### Risk-Based Labels (von Renovate gesetzt)

| Label | Risk Level | n8n Aktion |
|-------|------------|------------|
| `patch` + `low-risk` | LOW | Auto-Merge erlaubt |
| `minor` + `medium-risk` | MEDIUM | AI prüft genauer |
| `major` + `high-risk` | HIGH | Manuelles Review |
| `critical-infrastructure` | CRITICAL | Nie auto-merge |
| `database` | HIGH | Extra vorsichtig |
| `security` + `priority-high` | URGENT | Sofort benachrichtigen |

### Package Grouping

Renovate gruppiert zusammengehörige Updates:

- **Cilium CNI** - Alle Cilium-Komponenten
- **ArgoCD Ecosystem** - ArgoCD, Argo Rollouts
- **Monitoring Stack** - Prometheus, Grafana, Loki, Tempo
- **Security Tools** - Cert-Manager, Sealed-Secrets, Kyverno
- **Storage Stack** - Rook, Ceph, Velero, Longhorn
- **Messaging Stack** - Kafka, Strimzi, RabbitMQ

## Was der Workflow macht

1. **Jeden Montag** checkt er GitHub auf offene PRs
2. **Filtert** nur Renovate Bot PRs
3. **AI Analyse** mit Claude:
   - Liest Labels (patch/minor/major, risk-level)
   - Prüft auf Breaking Changes
   - Bewertet Update-Typ
4. **Entscheidung:**
   - `APPROVED` → Auto-Merge + Telegram Notification
   - `NEEDS_REVIEW` → Telegram Notification (manuell reviewen)
   - `REJECTED` → Telegram Notification (nicht mergen)

## Risk Level Regeln

| Risk | Wann | Aktion |
|------|------|--------|
| LOW | Patch Updates, Bug Fixes | Auto-Merge |
| MEDIUM | Minor Updates, neue Features | Needs Review |
| HIGH | Major Updates, Breaking Changes | Rejected |

### Immer HIGH Risk (nie auto-merge):
- PostgreSQL / CloudNativePG Updates
- Cilium / CNI Updates
- Cert-Manager Updates
- Elasticsearch / Databases
- Core Infrastructure

---

## Setup Anleitung

### Voraussetzungen

- n8n läuft auf: `https://n8n.timourhomelab.org`
- GitHub Repo: `Tim275/talos-homelab`

---

### Schritt 1: Telegram Bot erstellen

1. Telegram öffnen → `@BotFather` suchen
2. `/newbot` senden
3. Name eingeben: `Homelab Renovate Bot`
4. Username eingeben: `homelab_renovate_n8n_bot`
5. **Token speichern** (NICHT in Git committen!)

### Schritt 2: Telegram Chat ID holen

1. Telegram → Bot suchen und `/start` schreiben
2. Browser öffnen: `https://api.telegram.org/bot<DEIN_TOKEN>/getUpdates`
3. In der Antwort `"chat":{"id":123456789}` finden

---

### Schritt 3: GitHub Token erstellen

1. Öffne: https://github.com/settings/personal-access-tokens/new
2. **Token name:** `n8n-homelab`
3. **Expiration:** 90 days
4. **Repository access:** Only select repositories → `Tim275/talos-homelab`
5. **Permissions:**
   - `Contents`: Read and Write
   - `Pull requests`: Read and Write
   - `Issues`: Read and Write
6. **Generate token** → Token kopieren

---

### Schritt 4: Anthropic API Key erstellen

1. Öffne: https://console.anthropic.com/settings/keys
2. **Create Key**
3. Name: `n8n-homelab`
4. **Copy** → Key speichern

**Kosten:** ~$0.01-0.05 pro PR-Analyse (Claude Sonnet)

---

### Schritt 5: n8n Credentials erstellen

Öffne n8n: `https://n8n.timourhomelab.org`

#### 5.1 GitHub API Credential

1. Settings → Credentials → Add Credential
2. Suche: **GitHub API**
3. Eingeben:
   - **User:** `Tim275`
   - **Access Token:** `github_pat_xxxx` (dein Token)
4. **Save**

#### 5.2 Telegram Credential

1. Settings → Credentials → Add Credential
2. Suche: **Telegram**
3. Eingeben:
   - **Access Token:** Dein Bot Token von BotFather
4. **Save**

#### 5.3 Anthropic Credential

1. Settings → Credentials → Add Credential
2. Suche: **Anthropic**
3. Eingeben:
   - **API Key:** `sk-ant-xxxx` (dein Key)
4. **Save**

---

### Schritt 6: Workflow importieren

1. n8n → Workflows → **Import from File**
2. Datei auswählen: `kubernetes/n8n/workflow.json`
3. **Import**

---

### Schritt 7: Credentials zuweisen

Nach dem Import Credentials zuweisen für:

| Node | Credential Type |
|------|-----------------|
| Get Open PRs | GitHub API |
| Get PR Comments | GitHub API |
| Add PR Comment | GitHub API |
| Merge PR | GitHub API |
| Anthropic Claude | Anthropic |
| Notify Approved | Telegram |
| Notify Needs Review | Telegram |
| Notify Rejected | Telegram |

---

### Schritt 8: Workflow aktivieren

1. Workflow öffnen
2. Toggle oben rechts: **Active** (grün)
3. Fertig!

---

## Telegram Notifications

### Auto-Merged
```
✅ Auto-merged Renovate PR

Component: grafana
Update: 11.4.0 -> 11.5.0
Type: MINOR
Risk: LOW
Labels: patch, low-risk

Simple minor update with new features, no breaking changes.

View PR: https://github.com/Tim275/talos-homelab/pull/42
```

### Needs Review
```
⚠️ Renovate PR Needs Review

Component: cilium
Update: 1.16.0 -> 1.17.0
Type: MINOR
Risk: MEDIUM
Labels: minor, medium-risk, critical-infrastructure

Reason: CNI update requires careful testing
Recommendation: Test in staging first

Review PR: https://github.com/Tim275/talos-homelab/pull/43
```

### Rejected
```
❌ Renovate PR Rejected for Auto-Merge

Component: cloudnative-pg
Update: 1.24.0 -> 2.0.0
Type: MAJOR
Risk: HIGH
Labels: major, high-risk, database, breaking-change

Breaking Changes: New API version, migration required

Review PR: https://github.com/Tim275/talos-homelab/pull/44
```

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| Keine PRs gefunden | GitHub Token Permissions prüfen |
| AI Analyse failed | Anthropic API Key + Credits prüfen |
| Telegram nicht gesendet | Chat ID prüfen, Bot muss gestartet sein |
| Merge failed | Branch Protection Rules prüfen |
| 401 Unauthorized | Token abgelaufen, neu erstellen |

---

## Kosten

| Service | Kosten |
|---------|--------|
| GitHub API | Kostenlos |
| Telegram API | Kostenlos |
| Anthropic Claude | ~$0.01-0.05 pro PR |

Mit wöchentlichem Schedule: **< $1/Monat**

---

## Dateien

```
kubernetes/n8n/
├── README.md      # Diese Anleitung
└── workflow.json  # n8n Workflow (importieren)
```

**WICHTIG:** Keine Secrets in diesen Dateien! Credentials werden nur in n8n gespeichert.

---

## Renovate Config (renovate.json)

Die Enterprise-Config ist im Root des Repos:

```json
{
  "extends": ["config:best-practices"],
  "automerge": false,  // n8n entscheidet!
  "packageRules": [
    // Risk-based labels
    // Smart grouping
    // Critical infrastructure protection
  ]
}
```

Siehe `renovate.json` für die vollständige Konfiguration.
