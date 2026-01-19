# Renovate - Automatische Dependency Updates

## Das Problem

```
Ohne Automation:
- Montag: "Grafana hat Security Patch" → Manuell ändern, PR, mergen
- Dienstag: "ArgoCD neue Version" → Manuell ändern, PR, mergen
- Mittwoch: "Cilium Update" → Vergessen, bleibt auf alter Version mit CVE

Ergebnis:
- Stunden pro Woche für manuelle Updates
- Vergessene Updates = Security-Risiko
- Keine Übersicht was outdated ist
```

## Die Lösung

```
┌──────────┐      prüft       ┌──────────┐      erstellt     ┌──────────┐
│ Renovate │ ───────────────► │  GitHub  │ ───────────────►  │   PRs    │
│   Bot    │   Helm Charts,   │   Repo   │   automatisch     │ mit Diff │
└──────────┘   Docker Images  └──────────┘                   └──────────┘

Ergebnis:
- Automatische PRs für alle Updates
- Gruppierte Updates (Monitoring Stack, ArgoCD, etc.)
- Auto-Merge für Patches (Security Fixes)
- Nichts wird vergessen
```

---

## Option 1: GitHub App (empfohlen)

### Schritt 1: App installieren

1. Gehe zu: https://github.com/apps/renovate
2. Klick "Install"
3. Wähle Repository: `Tim275/talos-homelab`
4. Fertig

### Schritt 2: Config ist bereits vorhanden

Die `renovate.json` im Repo Root ist bereits konfiguriert:

```
Was Renovate scannt:
- Helm Charts (values.yaml)
- Docker Images (in YAML Dateien)
- Terraform Provider (.tf, .tofu)
- GitHub Actions (.github/workflows)
- Kustomize (kustomization.yaml)
- Talos Versions (tfvars)
```

### Schritt 3: Erster Run

Nach Installation erstellt Renovate:
1. **Onboarding PR** - Zeigt was gefunden wurde
2. **Dependency Dashboard** - Issue mit Übersicht aller Updates

### Was passiert automatisch

| Update-Typ | Aktion | Labels |
|------------|--------|--------|
| Patch (z.B. 1.2.3 → 1.2.4) | Auto-Merge | `auto-merge`, `patch` |
| Minor trusted (Grafana, Prometheus) | Auto-Merge | `auto-merge`, `minor` |
| Minor andere | PR erstellen | `dependencies` |
| Major | PR + Review nötig | `major-update`, `needs-review` |
| Security | PR + Priority | `security`, `vulnerability` |

### Gruppierung

Updates werden gruppiert um PR-Spam zu vermeiden:

- **Talos System** - Talos Versionen
- **Kubernetes Core** - K8s, Gateway API
- **Monitoring Stack** - Grafana, Prometheus, Loki, Tempo
- **ArgoCD Ecosystem** - ArgoCD, Argo Rollouts
- **Security Tools** - Cert-Manager, Sealed Secrets, Kyverno
- **Database & Platform** - PostgreSQL, MongoDB, Kafka, n8n

---

## Option 2: Self-Hosted in Kubernetes (für GitLab)

### Warum Self-Hosted?

- GitLab hat keine Renovate App
- Volle Kontrolle über Scheduling
- Funktioniert mit Private Registries
- Kann mehrere Repos auf einmal scannen

### Architektur

```
Kubernetes Cluster                           GitLab/GitHub
───────────────────                          ─────────────

┌─────────────────┐         ┌─────────────────┐
│ CronJob         │         │ Secret          │
│ renovate        │ ──────► │ renovate-token  │
│ (alle 2h)       │         │ (PAT)           │
└────────┬────────┘         └─────────────────┘
         │
         │ scannt
         ▼
┌─────────────────────────────────────────────────────────┐
│ GitLab / GitHub                                          │
│ - Liest Repos                                            │
│ - Erstellt MRs/PRs                                       │
└─────────────────────────────────────────────────────────┘
```

### Dateien erstellen

**kubernetes/infrastructure/automation/renovate/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: renovate

resources:
  - namespace.yaml
  - secret.yaml
  - configmap.yaml
  - cronjob.yaml
```

**namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: renovate
  labels:
    app.kubernetes.io/name: renovate
```

**secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: renovate-token
type: Opaque
stringData:
  # GitHub: Personal Access Token mit repo Scope
  # GitLab: Personal Access Token mit api Scope
  token: "ghp_xxxx"  # ERSETZEN!
```

**configmap.yaml (GitHub):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: renovate-config
data:
  config.json: |
    {
      "$schema": "https://docs.renovatebot.com/renovate-schema.json",
      "platform": "github",
      "repositories": [
        "Tim275/talos-homelab"
      ],
      "extends": [
        "config:recommended"
      ],
      "timezone": "Europe/Berlin",
      "schedule": ["before 6am every weekday"],
      "packageRules": [
        {
          "matchUpdateTypes": ["patch"],
          "automerge": true
        }
      ]
    }
```

**configmap.yaml (GitLab):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: renovate-config
data:
  config.json: |
    {
      "$schema": "https://docs.renovatebot.com/renovate-schema.json",
      "platform": "gitlab",
      "endpoint": "https://gitlab.example.com/api/v4",
      "repositories": [
        "group/repo1",
        "group/repo2"
      ],
      "gitAuthor": "Renovate Bot <renovate@example.com>",
      "extends": [
        "config:recommended"
      ],
      "timezone": "Europe/Berlin"
    }
```

**cronjob.yaml:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: renovate
spec:
  schedule: "0 */2 * * *"  # Alle 2 Stunden
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: renovate
              image: renovate/renovate:39
              args:
                - --config
                - /opt/renovate/config.json
              env:
                - name: RENOVATE_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: renovate-token
                      key: token
                - name: LOG_LEVEL
                  value: "info"
              volumeMounts:
                - name: config
                  mountPath: /opt/renovate/
              resources:
                requests:
                  cpu: 100m
                  memory: 512Mi
                limits:
                  cpu: 1000m
                  memory: 2Gi
          volumes:
            - name: config
              configMap:
                name: renovate-config
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
```

### Deployen

```bash
# Kustomize anwenden
kubectl apply -k kubernetes/infrastructure/automation/renovate/

# Status prüfen
kubectl get cronjob -n renovate
kubectl get pods -n renovate
```

### Manuell triggern

```bash
# Job aus CronJob erstellen
kubectl create job renovate-manual --from=cronjob/renovate -n renovate

# Logs anschauen
kubectl logs -f job/renovate-manual -n renovate

# Job löschen
kubectl delete job renovate-manual -n renovate
```

---

## n8n Integration (Telegram Notifications)

### Architektur

```
GitHub                    n8n                      Telegram
──────                    ───                      ────────

┌────────────┐           ┌─────────────┐          ┌────────────┐
│ Renovate   │  Webhook  │ Webhook     │  API     │ Bot:       │
│ erstellt   │ ────────► │ empfängt    │ ───────► │ homelab_   │
│ PR         │           │ filtert     │          │ renovate   │
└────────────┘           │ formatiert  │          └────────────┘
                         └─────────────┘
```

### Schritt 1: Telegram Bot einrichten

1. Öffne Telegram, suche `@BotFather`
2. Sende `/newbot`
3. Name: `Homelab Renovate`
4. Username: `homelab_renovate_n8n_bot` (muss auf _bot enden)
5. Speichere den Token

**Aktueller Bot:** `@homelab_renovate_n8n_bot`

### Schritt 2: Chat ID holen

1. Schreibe dem Bot eine Nachricht (`/start`)
2. Öffne: `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Suche `"chat":{"id":123456789}` - das ist die Chat ID

### Schritt 3: n8n Workflow importieren

Gehe zu n8n.timourhomelab.org → Workflows → Import from File:

```json
{
  "name": "GitHub Renovate → Telegram",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "github-renovate",
        "responseMode": "onReceived",
        "responseData": "allEntries"
      },
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.action }}",
              "operation": "equals",
              "value2": "opened"
            },
            {
              "value1": "={{ $json.pull_request.user.login }}",
              "operation": "contains",
              "value2": "renovate"
            }
          ]
        }
      },
      "name": "IF Renovate PR",
      "type": "n8n-nodes-base.if",
      "typeVersion": 1,
      "position": [450, 300]
    },
    {
      "parameters": {
        "chatId": "DEINE_CHAT_ID",
        "text": "=🔄 **Renovate Update**\n\n📦 {{ $json.pull_request.title }}\n🔗 {{ $json.pull_request.html_url }}\n📁 Repo: {{ $json.repository.full_name }}",
        "additionalFields": {
          "parse_mode": "Markdown"
        }
      },
      "name": "Telegram",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1,
      "position": [650, 300],
      "credentials": {
        "telegramApi": {
          "name": "Telegram Renovate Bot"
        }
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [[{"node": "IF Renovate PR", "type": "main", "index": 0}]]
    },
    "IF Renovate PR": {
      "main": [[{"node": "Telegram", "type": "main", "index": 0}]]
    }
  }
}
```

### Schritt 4: n8n Telegram Credentials

1. Settings → Credentials → Add Credential
2. Type: `Telegram`
3. Name: `Telegram Renovate Bot`
4. Access Token: `8162802258:AAG1tEs18PfiCOWSxoQAcJT6qlxyOPI4K8w`
5. Save

### Schritt 5: GitHub Webhook

1. Gehe zu: https://github.com/Tim275/talos-homelab/settings/hooks
2. Add webhook:
   - **Payload URL:** `https://n8n.timourhomelab.org/webhook/github-renovate`
   - **Content type:** `application/json`
   - **Secret:** (leer lassen)
   - **Events:** → Let me select → ☑️ Pull requests
3. Add webhook

### Schritt 6: Testen

```bash
# Test-Nachricht an Bot senden
curl -X POST "https://api.telegram.org/bot8162802258:AAG1tEs18PfiCOWSxoQAcJT6qlxyOPI4K8w/sendMessage" \
  -d "chat_id=DEINE_CHAT_ID" \
  -d "text=🧪 Test Notification"
```

### Was du bekommst

Bei jedem neuen Renovate PR:
```
🔄 Renovate Update

📦 Update grafana/grafana Docker tag to v11.5.0
🔗 https://github.com/Tim275/talos-homelab/pull/42
📁 Repo: Tim275/talos-homelab
```

---

## Befehle

```bash
# Renovate lokal testen (dry-run)
npx renovate --dry-run --token=ghp_xxx Tim275/talos-homelab

# CronJob manuell triggern
kubectl create job renovate-now --from=cronjob/renovate -n renovate

# Logs anschauen
kubectl logs -f -l app=renovate -n renovate

# Letzte Jobs anzeigen
kubectl get jobs -n renovate --sort-by=.metadata.creationTimestamp
```

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| "No PRs created" | Prüfe ob Repos in config.json korrekt |
| "Authentication failed" | Token Scope prüfen (repo für GitHub, api für GitLab) |
| "Rate limited" | prHourlyLimit/prConcurrentLimit reduzieren |
| "Timeout" | Resources für Container erhöhen |

---

## Zusammenfassung

| Setup | Aufwand | Für wen |
|-------|---------|---------|
| GitHub App | 5 Min | GitHub User (empfohlen) |
| Self-Hosted CronJob | 30 Min | GitLab, Enterprise, Private Repos |

**Was Renovate updated:**
- Helm Chart Versions
- Docker Image Tags
- Terraform Provider
- GitHub Actions
- Kustomize Components
- Talos/Kubernetes Versions
