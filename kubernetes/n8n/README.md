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

## Was der Workflow macht

1. **Jeden Montag** checkt er GitHub auf offene PRs
2. **Filtert** nur Renovate Bot PRs
3. **AI Analyse** mit Claude:
   - Risk Level (LOW/MEDIUM/HIGH)
   - Update Type (PATCH/MINOR/MAJOR)
   - Breaking Changes Detection
4. **Entscheidung:**
   - `APPROVED` → Auto-Merge + Telegram Notification
   - `NEEDS_REVIEW` → Telegram Notification (manuell reviewen)
   - `REJECTED` → Telegram Notification (nicht mergen)

## Risk Level Regeln

| Risk | Wann | Aktion |
|------|------|--------|
| LOW | Patch Updates, Bug Fixes | Auto-Merge |
| MEDIUM | Minor Updates, neue Features | Needs Review |
| HIGH | Major Updates, Breaking Changes, Databases | Rejected |

### Immer HIGH Risk:
- PostgreSQL / CloudNativePG Updates
- Cilium / CNI Updates
- Cert-Manager Updates
- Core Infrastructure

---

## Setup Anleitung (Step-by-Step)

### Voraussetzungen

- n8n läuft auf: `n8n.timourhomelab.org`
- GitHub Repo: `Tim275/talos-homelab`

---

### Schritt 1: Telegram Bot erstellen

1. Telegram öffnen → `@BotFather` suchen
2. `/newbot` senden
3. Name eingeben: `Homelab Renovate Bot`
4. Username eingeben: `homelab_renovate_n8n_bot`
5. **Token speichern** (z.B. `8162802258:AAHxxxxx`)

### Schritt 2: Telegram Chat ID holen

1. Telegram → Bot suchen: `@homelab_renovate_n8n_bot`
2. `/start` schreiben
3. Browser öffnen: `https://api.telegram.org/bot<DEIN_TOKEN>/getUpdates`
4. In der Antwort `"chat":{"id":123456789}` finden → Das ist deine Chat ID

**Aktuelle Werte:**
- Bot: `@homelab_renovate_n8n_bot`
- Token: `8162802258:AAHIHRFEbMu5tWyqSyyuNLbXshgW2Jf9fg4`
- Chat ID: `8449184586`

---

### Schritt 3: GitHub Token erstellen

1. Öffne: https://github.com/settings/personal-access-tokens/new
2. **Token name:** `n8n-homelab`
3. **Expiration:** 90 days (oder länger)
4. **Repository access:** Only select repositories → `Tim275/talos-homelab`
5. **Permissions:**
   - `Contents`: Read and Write
   - `Pull requests`: Read and Write
   - `Issues`: Read and Write
6. **Generate token** → Token kopieren (beginnt mit `github_pat_`)

---

### Schritt 4: Anthropic API Key erstellen

1. Öffne: https://console.anthropic.com/settings/keys
2. **Create Key**
3. Name: `n8n-homelab`
4. **Copy** → Key speichern (beginnt mit `sk-ant-`)

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
4. **Save** → "Connection tested successfully"

#### 5.2 Telegram Credential

1. Settings → Credentials → Add Credential
2. Suche: **Telegram**
3. Eingeben:
   - **Access Token:** `8162802258:AAHIHRFEbMu5tWyqSyyuNLbXshgW2Jf9fg4`
4. **Save** → "Connection tested successfully"

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

Nach dem Import sind die Credentials rot markiert. Für jeden Node:

1. Node doppelklicken
2. **Credential** auswählen (das richtige aus der Liste)
3. Schließen

**Nodes die Credentials brauchen:**

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

## Testen

### Manuell triggern

1. Workflow öffnen
2. **Execute Workflow** klicken
3. Output prüfen

### Telegram Test

```bash
curl -s -X POST "https://api.telegram.org/bot8162802258:AAHIHRFEbMu5tWyqSyyuNLbXshgW2Jf9fg4/sendMessage" \
  -d "chat_id=8449184586" \
  -d "text=Test Notification"
```

---

## Schedule

Der Workflow läuft **jeden Montag** automatisch.

Um Kosten zu sparen (Anthropic API), nicht stündlich sondern wöchentlich.

Manuell triggern jederzeit möglich.

---

## Telegram Notifications

### Auto-Merged
```
Auto-merged Renovate PR

Component: grafana
Update: 11.4.0 -> 11.5.0
Type: MINOR
Risk: LOW

Simple minor update with new features, no breaking changes.

View PR: https://github.com/Tim275/talos-homelab/pull/42
```

### Needs Review
```
Renovate PR Needs Review

Component: cilium
Update: 1.16.0 -> 1.17.0
Type: MINOR
Risk: MEDIUM

Reason: CNI update requires careful testing
Recommendation: Test in staging first

Review PR: https://github.com/Tim275/talos-homelab/pull/43
```

### Rejected
```
Renovate PR Rejected for Auto-Merge

Component: cloudnative-pg
Update: 1.24.0 -> 2.0.0
Type: MAJOR
Risk: HIGH

Breaking Changes: New API version, migration required

Reason: Major database operator update with breaking changes

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

**Wichtig:** Keine Secrets in diesen Dateien! Credentials werden nur in n8n gespeichert.
