# Keep + Slack Integration Setup

## Overview
Keep AIOps platform is now integrated with AlertManager and Ollama AI (phi3:mini) for intelligent alert correlation and enrichment.

## Current Status
- ✅ Keep deployed with MySQL database
- ✅ Ollama AI backend configured (phi3:mini model)
- ✅ AlertManager webhook connected to Keep
- ✅ Keep UI available at: https://keep.timourhomelab.org
- ⏳ Slack provider configuration (requires UI setup)

## Architecture
```
Prometheus → AlertManager → Keep Backend (AI Enrichment) → Slack #alerts
                              ↓
                          Ollama phi3:mini
                          (AI Analysis)
```

## Slack Provider Configuration

### Prerequisites
- Slack Bot Token: `xoxb-XXXX-XXXX-XXXXXXXXXXXXXXXXXXXX` (stored in sealed-secrets)
- Target Channels: `#alerts`, `#argocd-deployments`

### Setup Steps (via Keep UI)

1. **Access Keep UI**:
   ```bash
   # Port-forward (if not using public HTTPRoute)
   kubectl port-forward -n monitoring svc/keep-frontend 3000:3000
   # Open: http://localhost:3000
   ```

2. **Configure Slack Provider**:
   - Navigate to: **Settings** → **Providers** → **Add Provider**
   - Select: **Slack**
   - Provider ID: `slack-homelab`
   - Authentication:
     - Method: **OAuth 2.0 (Bot Token)**
     - Access Token: `xoxb-XXXX-XXXX-XXXXXXXXXXXXXXXXXXXX` (use sealed-secret value)
   - Click: **Save**

3. **Test Slack Connection**:
   - Keep will verify the token and show connected channels
   - Ensure `#alerts` and `#argocd-deployments` are visible

## Workflow Configuration

Keep will automatically create workflows for:
- **Alert Correlation**: Group similar alerts using AI
- **Alert Enrichment**: Add context from Ollama AI analysis
- **Slack Notifications**: Send correlated alerts to #alerts

### Example Workflow (Automatic)
Once Slack provider is configured, Keep automatically:
1. Receives alerts from AlertManager webhook
2. Correlates similar alerts (reduces noise by ~97%)
3. Enriches alerts with Ollama AI analysis
4. Sends consolidated alerts to Slack

## Monitoring

### Check Keep Backend Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=keep-backend --tail=50 -f
```

### Check AlertManager Webhook Status
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=50 | grep keep
```

### Verify Ollama Integration
```bash
# Check Ollama is reachable from Keep backend
kubectl exec -n monitoring deploy/keep-backend -- \
  curl -s http://ollama.ai-inference.svc.cluster.local:11434/api/tags
```

## Troubleshooting

### Issue: Alerts not reaching Keep
**Check**: AlertManager configuration
```bash
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d | grep keep-webhook
```

**Expected**: `url: 'http://keep-backend.monitoring.svc.cluster.local:8080/alerts/event/prometheus'`

### Issue: Keep not enriching with AI
**Check**: Ollama environment variables in Keep backend
```bash
kubectl get pod -n monitoring -l app.kubernetes.io/name=keep-backend \
  -o jsonpath='{.items[0].spec.containers[0].env}' | jq
```

**Expected**:
```json
{
  "name": "AI_ENABLED",
  "value": "true"
},
{
  "name": "OLLAMA_HOST",
  "value": "http://ollama.ai-inference.svc.cluster.local:11434"
}
```

### Issue: Slack messages not sending
**Check**: Slack provider configuration in Keep UI
- Ensure provider is **Connected** (green status)
- Test with: **Settings** → **Providers** → **slack-homelab** → **Test Connection**

## Next Steps
1. Configure Slack provider via Keep UI (manual step)
2. Trigger test alert to verify end-to-end flow
3. Monitor alert correlation in Keep UI
4. Fine-tune AI enrichment prompts if needed

## References
- Keep Docs: https://docs.keephq.dev
- Slack Provider: https://docs.keephq.dev/providers/documentation/slack-provider
- Prometheus Provider: https://docs.keephq.dev/providers/documentation/prometheus-provider
