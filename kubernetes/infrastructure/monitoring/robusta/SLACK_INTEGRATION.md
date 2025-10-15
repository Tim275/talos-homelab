# Robusta Slack Integration

## Current Status: Console-Only (GitHub Push Protection Blocker)

Robusta is currently configured with **console-only output** (`file_sink`) due to GitHub Push Protection blocking the Slack Bot token.

## The Challenge

Robusta Helm chart requires the Slack Bot API token directly in `values.yaml`:

```yaml
sinksConfig:
  - slack_sink:
      api_key: "xoxb-..." # ← Helm chart expects plain string
```

**NOT supported by Helm chart:**
- ❌ `secretKeyRef: {name: ..., key: ...}`
- ❌ Environment variable substitution `${SLACK_TOKEN}`
- ❌ External secrets injection

**Problem:** GitHub Push Protection blocks commits with `xoxb-*` tokens, even in private repos.

## Solutions (Ranked by Production Quality)

### Option 1: Use GitHub Bypass URL (Recommended for IaC)

GitHub provides a bypass mechanism for legitimate IaC secrets:

1. Copy bypass URL from GitHub Push Protection error:
   ```
   https://github.com/Tim275/talos-homelab/security/secret-scanning/unblock-secret/XXXXX
   ```

2. Click URL to allowlist this specific token

3. Re-push commit

**Pros:**
- ✅ Production Infrastructure as Code pattern
- ✅ Works with GitOps (ArgoCD auto-sync)
- ✅ Token stays encrypted at rest in Git
- ✅ Explicit security approval trail

**Cons:**
- ⚠️ Token visible in Git history (but repo is private)
- ⚠️ Requires manual GitHub bypass for each token rotation

### Option 2: Manual kubectl Patch (Quick Test)

Test Slack integration without Git commit:

```bash
# Get decrypted token
SLACK_TOKEN=$(kubectl get secret robusta-slack-bot-token -n monitoring -o jsonpath='{.data.token}' | base64 -d)

# Patch the Helm-generated config Secret directly
kubectl patch secret robusta-playbooks-config-secret -n monitoring -p "$(cat <<EOF
{
  "stringData": {
    "active_playbooks.yaml": "$(kubectl get secret robusta-playbooks-config-secret -n monitoring -o jsonpath='{.data.active_playbooks\.yaml}' | base64 -d | yq eval '.sinksConfig += [{"slack_sink": {"name": "robusta-slack-alerts", "slack_channel": "alerts", "api_key": "'$SLACK_TOKEN'"}}]' - | sed 's/$/\\n/' | tr -d '\n')"
  }
}
EOF
)"

# Restart robusta-runner to pick up new config
kubectl rollout restart deployment/robusta-runner -n monitoring
```

**Pros:**
- ✅ Immediate testing without Git
- ✅ No GitHub Push Protection

**Cons:**
- ❌ NOT GitOps - ArgoCD will revert changes
- ❌ Manual process, not repeatable

### Option 3: Helm Post-Renderer (Advanced)

Use Kustomize as Helm post-renderer to inject token AFTER Helm rendering:

```yaml
# kustomization.yaml
helmCharts:
  - name: robusta
    repo: https://robusta-charts.storage.googleapis.com
    version: 0.28.1
    valuesFile: values.yaml
    postRenderer: ./inject-slack-token.sh

# inject-slack-token.sh
#!/bin/bash
SLACK_TOKEN=$(kubectl get secret robusta-slack-bot-token -n monitoring -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "PLACEHOLDER")
yq eval "(.data.\"active_playbooks.yaml\" | @base64d | fromyaml | .sinksConfig[] | select(.slack_sink) | .slack_sink.api_key) = \"$SLACK_TOKEN\"" | base64
```

**Pros:**
- ✅ GitOps-friendly (script in Git, not token)
- ✅ Automatic injection at deploy time

**Cons:**
- ❌ Complex setup
- ❌ Requires sealed secret to exist BEFORE Helm render
- ❌ ArgoCD doesn't support post-renderers natively

### Option 4: Disable Slack, Use Console Only (Current)

Keep `file_sink` only, view AI alerts in logs:

```bash
kubectl logs -n monitoring deployment/robusta-runner -f | grep "HolmesGPT"
```

**Pros:**
- ✅ Works immediately
- ✅ No secrets in Git
- ✅ GitOps-compliant

**Cons:**
- ❌ No Slack notifications
- ❌ Must manually check logs

## Recommendation

For a homelab production environment:

1. **Short-term:** Use **Option 1 (GitHub Bypass)** to enable Slack integration properly
2. **Token Security:**
   - Restrict Slack Bot permissions to `#alerts` channel only
   - Enable Slack Bot token rotation policy
   - Add token to password manager
3. **Long-term:** When Robusta adds native secret ref support, migrate to sealed secrets

## Current Slack Bot Token

**Location:** `robusta-slack-bot-token` sealed secret (monitoring namespace)
**Value:** Encrypted via kubeseal, decrypts to `xoxb-9682664117863-9690484618519-...`

**To rotate:**
1. Create new Slack Bot token in Slack workspace
2. Seal with `kubeseal`: `echo -n "xoxb-new-token" | kubectl create secret generic robusta-slack-bot-token --dry-run=client --from-file=token=/dev/stdin -o yaml | kubeseal -o yaml`
3. Update `slack-bot-token-sealed-secret.yaml`
4. Commit & push (triggers ArgoCD sync)
