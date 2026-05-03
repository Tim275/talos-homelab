# Runbook: Drova SLO Burn-Rate Alert

**Severity:** Critical (P1) für `DrovaSLOPageFastBurn` / `DrovaSLOPageSlowBurn`
**Severity:** Warning (P2) für `DrovaSLOTicketSlowBurn`

## Was ist passiert

Eine oder mehrere Drova-Services überschreiten die SLO-Error-Budget-Burn-Rate.

```
Target SLO: 99.5% availability (30 days rolling)
Error Budget: 0.5% × 30d × 24h = 3.6 hours/Monat
```

Burn-Rate Bedeutung:
- **14.4×** → 30-Tage-Budget in 2 Tagen weg → **P1 sofort**
- **6×**    → Budget in 5 Tagen weg → **P1 sofort**
- **3×**    → Budget in 10 Tagen weg → **P2 nächster Werktag**

## Sofort-Diagnose

### 1. Welcher Service brennt?

Aus der Alert-Annotation: `service_name` Label zeigt welcher Service betroffen ist.
Click auf `dashboard_url` → Drova SLO Dashboard mit aktuellem Burn-Status.

### 2. Aktuelle Error-Rate prüfen

```promql
# 5min error rate
sum by (service_name) (rate(http_server_request_duration_seconds_count{
  service_name="<SERVICE>",
  http_response_status_code=~"5.."
}[5m]))
```

### 3. Pod-Status check

```bash
kubectl get pods -n drova -l app=<service-name>
kubectl logs -n drova -l app=<service-name> --tail=200 | grep -iE "error|panic|fatal"
```

## Häufige Root-Causes (in absteigender Wahrscheinlichkeit)

### A) Recent Deploy hat regression eingeführt
```bash
# Letzte ArgoCD-Syncs
kubectl get application -n argocd drova-prod -o jsonpath='{.status.history}' | python3 -m json.tool | tail -50

# Roll back wenn fresh deploy:
argocd app rollback drova-prod <previous-revision>
```

### B) Database (CNPG drova-postgres) hat Probleme
```bash
kubectl exec -n drova drova-postgres-1 -- pg_isready
kubectl logs -n drova drova-postgres-1 -c postgres --tail=100 | grep -iE "error|fatal|deadlock"

# Verify replication lag
kubectl exec -n drova drova-postgres-1 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### C) Kafka brokers down / lag spike
```bash
kubectl get pods -n drova -l strimzi.io/cluster=drova-kafka
# Consumer lag (kafka-exporter):
# Grafana → Drova Dependencies dashboard → "Consumer Lag" panel
```

### D) Redis cache exhausted / connections maxed
```bash
kubectl exec -n drova redis-drova-master-0 -c redis-drova -- redis-cli INFO stats | head -30
kubectl exec -n drova redis-drova-master-0 -c redis-drova -- redis-cli CLIENT LIST | wc -l
```

### E) External dependency (Stripe, OpenAI) outage
```bash
# Check egress error rate per FQDN (Cilium Hubble)
kubectl exec -n kube-system ds/cilium -c cilium-agent -- \
  hubble observe --verdict DROPPED --since 30m -n drova
```

## Mitigation

| Situation | Action |
|---|---|
| Recent deploy + spike | Rollback via ArgoCD |
| Pod CrashLoopBackOff | Check logs, fix env/secret/config issue, restart |
| DB connection pool exhausted | Increase `max_connections` in CNPG cluster spec |
| Kafka broker down | Check `kubectl describe pod drova-kafka-...` for OOM/scheduling |
| Cilium NetworkPolicy denied | `hubble observe --verdict DROPPED` shows blocked flows |
| External dep outage | Open status-page check, notify customers |

## Eskalation

- **15min ohne Improvement:** Notify @platform-oncall in Slack #drova-prod
- **30min ohne Improvement:** Page on-call engineer
- **1h ohne Improvement:** Engage incident response team

## Post-Mortem Pflicht

Wenn der Alert >30min gefired hat, muss eine Post-Mortem erstellt werden:
- Root cause analysis
- Timeline (detection → mitigation → resolution)
- Action items (preventive measures, alert improvements)
- Was hätte schneller helfen können?

## Verwandte Dashboards

- [Drova SLO + Error Budget](https://grafana.timourhomelab.org/d/drova-slo)
- [Drova Service Detail](https://grafana.timourhomelab.org/d/drova-service-detail)
- [Drova Dependencies (PG/Redis/Kafka)](https://grafana.timourhomelab.org/d/drova-dependencies)
