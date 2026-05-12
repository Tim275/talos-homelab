# Self-hosted Renovate — Setup-Procedure

Replaces Renovate-Cloud GitHub-App with K8s-CronJob. ~30 minutes total setup.

## Phase 1 — GitHub PAT generieren (5min)

GitHub fine-grained Personal Access Token erstellen:

```
https://github.com/settings/tokens?type=beta

Token name:        Renovate Self-Hosted Bot
Expiration:        90 days (Reminder im Kalender für Renewal!)
Resource owner:    Tim275
Repository access: Only select repositories
  - Tim275/talos-homelab
  - Tim275/drova-gitops
  
Repository permissions:
  - Contents:          Read and write
  - Pull requests:     Read and write
  - Issues:            Read and write
  - Metadata:          Read-only
  - Workflows:         Read and write    (für github-actions Updates)
  - Actions:           Read-only
```

→ Token kopieren (wird nur einmal angezeigt!)
→ Sofort in 1Password speichern als "GitHub PAT — Renovate Self-Hosted"

## Phase 2 — PAT als SealedSecret committen (5min)

```bash
cd /Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch

CERT=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt
TOKEN="github_pat_..."                  # einfügen, NICHT committen plain!

kubectl create secret generic renovate-secrets \
  --namespace=renovate \
  --from-literal=RENOVATE_TOKEN="$TOKEN" \
  --from-literal=RENOVATE_GITHUB_COM_TOKEN="$TOKEN" \
  --dry-run=client -o yaml | \
kubeseal --cert "$CERT" --format yaml --scope strict \
  > kubernetes/platform/developer-platform/renovate/base/github-token-sealed.yaml

# Verify (sollte verschlüsselt sein, KEIN Plaintext!)
head -20 kubernetes/platform/developer-platform/renovate/base/github-token-sealed.yaml

git add kubernetes/platform/developer-platform/renovate/base/github-token-sealed.yaml
git commit -m "renovate self-host PAT"
git push
```

→ ArgoCD synct → SealedSecrets-Controller dekrypted → renovate-secrets im Cluster

## Phase 3 — ArgoCD App aktivieren (1min)

Application ist bereits in `kubernetes/platform/kustomization.yaml` referenziert.
ArgoCD synct beim nächsten Refresh automatisch. Force:

```bash
kubectl annotate application platform -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Verify
kubectl get app renovate -n argocd
kubectl get cronjob -n renovate
```

## Phase 4 — Erster Run (15min beobachten)

Empfohlen: ERSTEN run mit `RENOVATE_DRY_RUN=full` machen, dann auf "false" stellen.

```bash
# Empfohlen: Helper-Script (kubernetes/scripts/renovate/trigger-now.sh)
./kubernetes/scripts/renovate/trigger-now.sh             # spawn + tail logs
./kubernetes/scripts/renovate/trigger-now.sh --dry-run   # erst dry-run
./kubernetes/scripts/renovate/trigger-now.sh --no-follow # spawn-only

# Alias-Tipp für ~/.zshrc:
#   alias renovate-now='$REPO/kubernetes/scripts/renovate/trigger-now.sh'

# Manual fallback:
kubectl create job --from=cronjob/renovate -n renovate manual-$(date +%s)

# Logs verfolgen
kubectl logs -n renovate -l job-name=<job> -f

# Erwartet im Output:
#   "Repository started"        ← gut
#   "Repository finished"        ← gut
#   "Created PR..."              ← schlecht wenn dryRun=full
#   "DRY-RUN: would create PR"   ← gut bei dryRun=full
```

Wenn alles OK aussieht → dryRun in values.yaml auf "false" setzen, commit, push.

## Phase 5 — Renovate-Cloud (GitHub-App) deinstallieren (2min)

WICHTIG: NICHT vor Phase 4! Sonst hast du 0 Renovate-Setup für die Übergangszeit.

```
1. https://github.com/settings/installations
2. Renovate (Mend.io) → Configure
3. Repository access → "Selected repositories"
   → Remove: Tim275/talos-homelab + Tim275/drova-gitops
4. ODER: komplett Uninstall

Verify:
  → Nächster Run kommt nur noch vom Self-Host
  → PR-Author ist "renovate-bot[self-hosted]"
  → Mend.io sieht deine Repos nicht mehr
```

## Häufige Fehler

### Pod CrashLoopBackOff: "FATAL: Token required"
→ SealedSecret hat noch Placeholder `REPLACE_ME...`
→ Phase 2 wiederholen mit echtem PAT

### "Permission denied" beim git push
→ PAT-Scope hat "Contents: Read-only" statt "Read+Write"
→ Phase 1 wiederholen, neuen PAT mit korrekten Permissions

### "rate limit exceeded"
→ PAT von Free-Tier GitHub hat 5000 req/h Limit
→ Reduce RENOVATE_PR_HOURLY_LIMIT auf "5"
→ Oder Schedule auf "0 */4 * * *" (alle 4h statt 2h)

### Renovate findet alle Updates aber PRs werden nicht erstellt
→ Renovate-Config (renovate.json im Target-Repo) hat
   `dependencyDashboardApproval: true` ODER `internalChecksFilter: strict`
→ Beide entfernen (siehe CLAUDE.md "Renovate Setup-Guide")

## Token-Rotation (alle 90 Tage)

Kalender-Reminder:
1. Neuen PAT generieren (Phase 1)
2. Alten PAT noch NICHT löschen
3. SealedSecret rotieren (Phase 2 mit neuem Token)
4. ArgoCD synct neue Secret
5. Manueller Test-Run (Phase 4)
6. ALTEN PAT auf GitHub deaktivieren
